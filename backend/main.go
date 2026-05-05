package main

import (
	"context"
	"errors"
	"flag"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

func main() {
	configPath := flag.String("config", "config.yaml", "Path to config file (optional, env vars override)")
	flag.Parse()

	cfg, err := LoadConfig(*configPath)
	if err != nil {
		log.Fatalf("config: %v", err)
	}

	store, err := OpenDB(cfg.DataPath)
	if err != nil {
		log.Fatalf("db: %v", err)
	}
	defer store.Close()

	if err := store.Migrate(); err != nil {
		log.Fatalf("db migrate: %v", err)
	}

	// Bootstrap the admin account on first launch.
	if err := store.EnsureAdmin(cfg.AdminUsername, cfg.AdminInitialPassword); err != nil {
		log.Fatalf("admin bootstrap: %v", err)
	}

	mgr := NewProviderManager(store)
	if err := mgr.Reload(context.Background()); err != nil {
		log.Printf("provider reload: %v (continuing — admin can configure later)", err)
	}

	rl := NewRateLimiter(store, cfg.RateLimitPerDay)
	burst := NewBurstLimiter(cfg.BurstLimitPerMinute, time.Minute)

	app := &App{
		Config:     cfg,
		Store:      store,
		Providers:  mgr,
		RateLimit:  rl,
		BurstLimit: burst,
	}

	mux := http.NewServeMux()
	app.RegisterRoutes(mux)

	srv := &http.Server{
		Addr:              cfg.ListenAddr,
		Handler:           withRecover(withRequestLog(mux)),
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      120 * time.Second, // LLM calls can be slow
		IdleTimeout:       60 * time.Second,
	}

	go func() {
		log.Printf("wearorder-api listening on %s", cfg.ListenAddr)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("listen: %v", err)
		}
	}()

	// Graceful shutdown.
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)
	<-stop
	log.Printf("shutting down…")

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Printf("shutdown: %v", err)
	}
}

// App bundles the dependencies passed to every handler. Plain struct,
// not an interface, because the handler boundary is internal-only.
type App struct {
	Config     *Config
	Store      *Store
	Providers  *ProviderManager
	RateLimit  *RateLimiter
	BurstLimit *BurstLimiter
}

func (a *App) RegisterRoutes(mux *http.ServeMux) {
	// Health check — used by Nginx + uptime monitors.
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("ok"))
	})

	// Public API surface (consumed by the iOS app).
	mux.HandleFunc("POST /v1/ai/generate-outfit", a.handleGenerateOutfit)

	// Admin panel (HTML).
	mux.HandleFunc("GET /admin/login", a.handleAdminLoginGet)
	mux.HandleFunc("POST /admin/login", a.handleAdminLoginPost)
	mux.HandleFunc("POST /admin/logout", a.handleAdminLogout)
	mux.HandleFunc("GET /admin/", a.requireAdmin(a.handleAdminHome))
	mux.HandleFunc("GET /admin/providers", a.requireAdmin(a.handleAdminProviders))
	mux.HandleFunc("POST /admin/providers", a.requireAdmin(a.handleAdminProviderCreate))
	mux.HandleFunc("POST /admin/providers/{id}/toggle", a.requireAdmin(a.handleAdminProviderToggle))
	mux.HandleFunc("POST /admin/providers/{id}/delete", a.requireAdmin(a.handleAdminProviderDelete))
	mux.HandleFunc("GET /admin/logs", a.requireAdmin(a.handleAdminLogs))
	mux.HandleFunc("POST /admin/password", a.requireAdmin(a.handleAdminChangePassword))
	mux.HandleFunc("GET /admin/test", a.requireAdmin(a.handleAdminTestGet))
	mux.HandleFunc("POST /admin/test", a.requireAdmin(a.handleAdminTestPost))

	// Static admin assets (CSS).
	mux.HandleFunc("GET /admin/assets/style.css", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/css; charset=utf-8")
		w.Write(adminCSS)
	})
}

// withRecover catches panics so a single broken handler doesn't kill
// the whole process.
func withRecover(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if rec := recover(); rec != nil {
				log.Printf("panic %s %s: %v", r.Method, r.URL.Path, rec)
				http.Error(w, "internal server error", http.StatusInternalServerError)
			}
		}()
		next.ServeHTTP(w, r)
	})
}

// withRequestLog gives us minimal access logs (status + latency) so we
// can spot abuse without standing up a full APM stack.
func withRequestLog(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		ww := &statusRecorder{ResponseWriter: w, status: 200}
		next.ServeHTTP(ww, r)
		log.Printf("%s %s -> %d (%dms)", r.Method, r.URL.Path, ww.status, time.Since(start).Milliseconds())
	})
}

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (s *statusRecorder) WriteHeader(code int) {
	s.status = code
	s.ResponseWriter.WriteHeader(code)
}
