package main

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"os"
	"strconv"
	"strings"
)

// Config is loaded from env vars (and optionally a key=value file). Env
// vars always win, so a systemd unit can override anything without
// editing the file on disk.
type Config struct {
	ListenAddr           string
	DataPath             string
	AdminUsername        string
	AdminInitialPassword string
	SessionSecret        string
	RateLimitPerDay      int
	RequestTimeoutSec    int
}

func LoadConfig(path string) (*Config, error) {
	// Best-effort load from file; missing file is fine.
	if path != "" {
		_ = loadEnvFile(path)
	}

	c := &Config{
		ListenAddr:           getenv("LISTEN_ADDR", "127.0.0.1:8080"),
		DataPath:             getenv("DATA_PATH", "./wearorder.db"),
		AdminUsername:        getenv("ADMIN_USERNAME", "admin"),
		AdminInitialPassword: os.Getenv("ADMIN_INITIAL_PASSWORD"),
		SessionSecret:        os.Getenv("SESSION_SECRET"),
		RateLimitPerDay:      getenvInt("RATE_LIMIT_PER_DAY", 30),
		RequestTimeoutSec:    getenvInt("REQUEST_TIMEOUT_SEC", 60),
	}

	// Auto-generate a session secret on first launch if one wasn't set;
	// printed to stdout so the operator can copy it into systemd. We
	// require ≥32 bytes of entropy.
	if c.SessionSecret == "" {
		secret, err := randHex(32)
		if err != nil {
			return nil, fmt.Errorf("generate session secret: %w", err)
		}
		c.SessionSecret = secret
		fmt.Fprintf(os.Stderr, "WARNING: SESSION_SECRET not set, generated ephemeral one. Sessions will reset on restart.\n")
		fmt.Fprintf(os.Stderr, "  → set in systemd: SESSION_SECRET=%s\n", secret)
	}

	if c.AdminInitialPassword == "" {
		// First launch with no preset password: generate one and force
		// the operator to look at the logs. Better than baking a
		// default password into the binary.
		pw, err := randHex(8)
		if err != nil {
			return nil, fmt.Errorf("generate admin password: %w", err)
		}
		c.AdminInitialPassword = pw
		fmt.Fprintf(os.Stderr, "==============================================================\n")
		fmt.Fprintf(os.Stderr, "  Admin bootstrap password (CHANGE IT AFTER FIRST LOGIN):\n")
		fmt.Fprintf(os.Stderr, "    user: %s\n", c.AdminUsername)
		fmt.Fprintf(os.Stderr, "    pass: %s\n", pw)
		fmt.Fprintf(os.Stderr, "==============================================================\n")
	}

	if c.RateLimitPerDay < 1 {
		return nil, errors.New("RATE_LIMIT_PER_DAY must be >= 1")
	}

	return c, nil
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func getenvInt(key string, fallback int) int {
	if v := os.Getenv(key); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return fallback
}

func randHex(n int) (string, error) {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}

// loadEnvFile parses a simple KEY=VALUE file into the process env.
// Lines starting with `#` are ignored. No quoting / escaping support —
// keep values simple, this is not a dotenv replacement.
func loadEnvFile(path string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		k, v, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		k = strings.TrimSpace(k)
		v = strings.TrimSpace(v)
		// Don't override already-set env (env > file).
		if _, exists := os.LookupEnv(k); !exists {
			os.Setenv(k, v)
		}
	}
	return nil
}
