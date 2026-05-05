package main

import (
	"net/http"
	"time"

	"golang.org/x/crypto/bcrypt"
)

const (
	sessionCookieName = "wearorder_admin_session"
	sessionTTL        = 7 * 24 * time.Hour
)

func HashPassword(plain string) (string, error) {
	b, err := bcrypt.GenerateFromPassword([]byte(plain), bcrypt.DefaultCost)
	if err != nil {
		return "", err
	}
	return string(b), nil
}

func CheckPassword(plain, hash string) bool {
	return bcrypt.CompareHashAndPassword([]byte(hash), []byte(plain)) == nil
}

// requireAdmin is a tiny middleware that ensures a valid session
// cookie is present. Unauthenticated requests get bounced to /admin/login.
func (a *App) requireAdmin(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		c, err := r.Cookie(sessionCookieName)
		if err != nil {
			http.Redirect(w, r, "/admin/login", http.StatusFound)
			return
		}
		sess, err := a.Store.FindSession(c.Value)
		if err != nil || sess == nil {
			http.Redirect(w, r, "/admin/login", http.StatusFound)
			return
		}
		next(w, r)
	}
}

// loadAdmin returns the AdminAccount associated with the current
// request's session, or nil if no valid session is present. Used by
// handlers that need the admin row (e.g. password change).
func (a *App) loadAdmin(r *http.Request) (*AdminAccount, error) {
	c, err := r.Cookie(sessionCookieName)
	if err != nil {
		return nil, nil
	}
	sess, err := a.Store.FindSession(c.Value)
	if err != nil || sess == nil {
		return nil, err
	}
	return a.Store.GetAdminByID(sess.AdminID)
}

func setSessionCookie(w http.ResponseWriter, r *http.Request, token string, expiresAt int64) {
	http.SetCookie(w, &http.Cookie{
		Name:     sessionCookieName,
		Value:    token,
		Path:     "/admin",
		HttpOnly: true,
		// Auto-detect: only flag Secure when the request itself came
		// in via HTTPS (direct TLS or behind a reverse proxy that
		// forwards X-Forwarded-Proto). Hardcoding `true` breaks
		// HTTP-only internal deployments — browsers silently drop
		// Secure cookies over plain HTTP and the user gets stuck in
		// a login loop.
		Secure:   isSecureRequest(r),
		SameSite: http.SameSiteLaxMode,
		Expires:  time.Unix(expiresAt, 0),
	})
}

func clearSessionCookie(w http.ResponseWriter, r *http.Request) {
	http.SetCookie(w, &http.Cookie{
		Name:     sessionCookieName,
		Value:    "",
		Path:     "/admin",
		HttpOnly: true,
		Secure:   isSecureRequest(r),
		SameSite: http.SameSiteLaxMode,
		MaxAge:   -1,
	})
}

// isSecureRequest tells whether the request came in over HTTPS, either
// directly (r.TLS set) or through a reverse proxy that set
// X-Forwarded-Proto. Used to flip the Secure cookie attribute on or
// off — so internal HTTP testing works AND production HTTPS deploys
// stay safe without any config flag.
func isSecureRequest(r *http.Request) bool {
	if r.TLS != nil {
		return true
	}
	if proto := r.Header.Get("X-Forwarded-Proto"); proto == "https" {
		return true
	}
	return false
}
