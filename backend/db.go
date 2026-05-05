package main

import (
	"database/sql"
	"errors"
	"fmt"
	"sync"
	"time"

	_ "modernc.org/sqlite"
)

// Store wraps the SQLite handle. SQLite is single-writer, so a sync.Mutex
// is enough for serialization on writes; reads can stay concurrent.
type Store struct {
	db *sql.DB
	mu sync.Mutex
}

func OpenDB(path string) (*Store, error) {
	db, err := sql.Open("sqlite", path+"?_pragma=journal_mode(WAL)&_pragma=foreign_keys(1)&_pragma=busy_timeout(5000)")
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(1) // SQLite + WAL: a single conn is fine and avoids busy errors on writes.
	if err := db.Ping(); err != nil {
		return nil, err
	}
	return &Store{db: db}, nil
}

func (s *Store) Close() error {
	return s.db.Close()
}

const schema = `
CREATE TABLE IF NOT EXISTS admin (
    id INTEGER PRIMARY KEY,
    username TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS providers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    base_url TEXT NOT NULL,
    api_key TEXT NOT NULL,
    model TEXT NOT NULL,
    enabled INTEGER NOT NULL DEFAULT 1,
    priority INTEGER NOT NULL DEFAULT 100,
    notes TEXT NOT NULL DEFAULT '',
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS call_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id TEXT NOT NULL,
    provider_id INTEGER,
    provider_name TEXT NOT NULL,
    status TEXT NOT NULL,                -- ok | provider_error | invalid_output | rate_limited | bad_request
    latency_ms INTEGER NOT NULL,
    prompt_tokens INTEGER NOT NULL DEFAULT 0,
    completion_tokens INTEGER NOT NULL DEFAULT 0,
    user_prompt TEXT NOT NULL DEFAULT '',
    error_message TEXT NOT NULL DEFAULT '',
    created_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_call_logs_created_at ON call_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_call_logs_device_id ON call_logs(device_id);

CREATE TABLE IF NOT EXISTS rate_buckets (
    device_id TEXT NOT NULL,
    day TEXT NOT NULL,                   -- YYYY-MM-DD in UTC
    count INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (device_id, day)
);

CREATE INDEX IF NOT EXISTS idx_rate_buckets_day ON rate_buckets(day);

CREATE TABLE IF NOT EXISTS sessions (
    token TEXT PRIMARY KEY,
    admin_id INTEGER NOT NULL REFERENCES admin(id) ON DELETE CASCADE,
    expires_at INTEGER NOT NULL,
    created_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_sessions_expires_at ON sessions(expires_at);
`

func (s *Store) Migrate() error {
	_, err := s.db.Exec(schema)
	return err
}

// ===== Admin =====

type AdminAccount struct {
	ID           int64
	Username     string
	PasswordHash string
}

func (s *Store) FindAdminByUsername(username string) (*AdminAccount, error) {
	var a AdminAccount
	err := s.db.QueryRow(
		`SELECT id, username, password_hash FROM admin WHERE username = ?`,
		username,
	).Scan(&a.ID, &a.Username, &a.PasswordHash)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &a, nil
}

func (s *Store) GetAdminByID(id int64) (*AdminAccount, error) {
	var a AdminAccount
	err := s.db.QueryRow(
		`SELECT id, username, password_hash FROM admin WHERE id = ?`,
		id,
	).Scan(&a.ID, &a.Username, &a.PasswordHash)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	return &a, err
}

func (s *Store) UpdateAdminPassword(id int64, passwordHash string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	_, err := s.db.Exec(
		`UPDATE admin SET password_hash = ?, updated_at = ? WHERE id = ?`,
		passwordHash, time.Now().Unix(), id,
	)
	return err
}

// EnsureAdmin creates the admin row on first launch. If the row exists
// we leave the password alone; rotating is done via the admin UI.
func (s *Store) EnsureAdmin(username, initialPassword string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	var count int
	if err := s.db.QueryRow(`SELECT COUNT(*) FROM admin`).Scan(&count); err != nil {
		return err
	}
	if count > 0 {
		return nil
	}

	hash, err := HashPassword(initialPassword)
	if err != nil {
		return fmt.Errorf("hash initial password: %w", err)
	}
	now := time.Now().Unix()
	_, err = s.db.Exec(
		`INSERT INTO admin(username, password_hash, created_at, updated_at) VALUES(?, ?, ?, ?)`,
		username, hash, now, now,
	)
	return err
}

// ===== Providers =====

type ProviderRecord struct {
	ID        int64
	Name      string
	BaseURL   string
	APIKey    string
	Model     string
	Enabled   bool
	Priority  int
	Notes     string
	CreatedAt int64
	UpdatedAt int64
}

func (s *Store) ListProviders() ([]*ProviderRecord, error) {
	rows, err := s.db.Query(`
		SELECT id, name, base_url, api_key, model, enabled, priority, notes, created_at, updated_at
		FROM providers
		ORDER BY priority ASC, id ASC
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []*ProviderRecord
	for rows.Next() {
		p := &ProviderRecord{}
		var enabled int
		if err := rows.Scan(
			&p.ID, &p.Name, &p.BaseURL, &p.APIKey, &p.Model,
			&enabled, &p.Priority, &p.Notes,
			&p.CreatedAt, &p.UpdatedAt,
		); err != nil {
			return nil, err
		}
		p.Enabled = enabled == 1
		out = append(out, p)
	}
	return out, rows.Err()
}

func (s *Store) ListEnabledProviders() ([]*ProviderRecord, error) {
	all, err := s.ListProviders()
	if err != nil {
		return nil, err
	}
	out := make([]*ProviderRecord, 0, len(all))
	for _, p := range all {
		if p.Enabled {
			out = append(out, p)
		}
	}
	return out, nil
}

func (s *Store) CreateProvider(p *ProviderRecord) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	now := time.Now().Unix()
	enabled := 0
	if p.Enabled {
		enabled = 1
	}
	res, err := s.db.Exec(`
		INSERT INTO providers(name, base_url, api_key, model, enabled, priority, notes, created_at, updated_at)
		VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?)
	`, p.Name, p.BaseURL, p.APIKey, p.Model, enabled, p.Priority, p.Notes, now, now)
	if err != nil {
		return err
	}
	id, err := res.LastInsertId()
	if err != nil {
		return err
	}
	p.ID = id
	return nil
}

func (s *Store) ToggleProvider(id int64) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	_, err := s.db.Exec(
		`UPDATE providers SET enabled = 1 - enabled, updated_at = ? WHERE id = ?`,
		time.Now().Unix(), id,
	)
	return err
}

func (s *Store) DeleteProvider(id int64) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	_, err := s.db.Exec(`DELETE FROM providers WHERE id = ?`, id)
	return err
}

// ===== Call logs =====

type CallLog struct {
	ID               int64
	DeviceID         string
	ProviderID       sql.NullInt64
	ProviderName     string
	Status           string
	LatencyMs        int
	PromptTokens     int
	CompletionTokens int
	UserPrompt       string
	ErrorMessage     string
	CreatedAt        int64
}

func (s *Store) RecordCall(log *CallLog) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	_, err := s.db.Exec(`
		INSERT INTO call_logs(device_id, provider_id, provider_name, status, latency_ms,
		                     prompt_tokens, completion_tokens, user_prompt, error_message, created_at)
		VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	`,
		log.DeviceID, log.ProviderID, log.ProviderName, log.Status, log.LatencyMs,
		log.PromptTokens, log.CompletionTokens, log.UserPrompt, log.ErrorMessage, time.Now().Unix(),
	)
	return err
}

// RecentCallLogs returns the latest N calls (default 200). Truncates
// user_prompt for the list view; full prompt is fetched on demand.
func (s *Store) RecentCallLogs(limit int) ([]*CallLog, error) {
	if limit <= 0 || limit > 1000 {
		limit = 200
	}
	rows, err := s.db.Query(`
		SELECT id, device_id, provider_id, provider_name, status, latency_ms,
		       prompt_tokens, completion_tokens, user_prompt, error_message, created_at
		FROM call_logs
		ORDER BY created_at DESC
		LIMIT ?
	`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []*CallLog
	for rows.Next() {
		l := &CallLog{}
		if err := rows.Scan(
			&l.ID, &l.DeviceID, &l.ProviderID, &l.ProviderName, &l.Status, &l.LatencyMs,
			&l.PromptTokens, &l.CompletionTokens, &l.UserPrompt, &l.ErrorMessage, &l.CreatedAt,
		); err != nil {
			return nil, err
		}
		out = append(out, l)
	}
	return out, rows.Err()
}

type CallStats struct {
	Last24hTotal  int
	Last24hOK     int
	Last24hFailed int
	UniqueDevices int
}

func (s *Store) RecentStats() (*CallStats, error) {
	cutoff := time.Now().Add(-24 * time.Hour).Unix()
	stats := &CallStats{}
	if err := s.db.QueryRow(
		`SELECT COUNT(*), COALESCE(SUM(CASE WHEN status='ok' THEN 1 ELSE 0 END), 0) FROM call_logs WHERE created_at >= ?`,
		cutoff,
	).Scan(&stats.Last24hTotal, &stats.Last24hOK); err != nil {
		return nil, err
	}
	stats.Last24hFailed = stats.Last24hTotal - stats.Last24hOK
	if err := s.db.QueryRow(
		`SELECT COUNT(DISTINCT device_id) FROM call_logs WHERE created_at >= ?`,
		cutoff,
	).Scan(&stats.UniqueDevices); err != nil {
		return nil, err
	}
	return stats, nil
}

// ===== Rate limiting =====

func (s *Store) IncrementRateBucket(deviceID, day string, limit int) (int, bool, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	var current int
	err := s.db.QueryRow(
		`SELECT count FROM rate_buckets WHERE device_id = ? AND day = ?`,
		deviceID, day,
	).Scan(&current)
	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		return 0, false, err
	}
	if current >= limit {
		return current, false, nil
	}

	if errors.Is(err, sql.ErrNoRows) {
		_, err = s.db.Exec(
			`INSERT INTO rate_buckets(device_id, day, count) VALUES(?, ?, 1)`,
			deviceID, day,
		)
		if err != nil {
			return 0, false, err
		}
		return 1, true, nil
	}

	_, err = s.db.Exec(
		`UPDATE rate_buckets SET count = count + 1 WHERE device_id = ? AND day = ?`,
		deviceID, day,
	)
	if err != nil {
		return 0, false, err
	}
	return current + 1, true, nil
}

// PruneOldBuckets is meant to be called periodically. We keep one
// week of history for debugging, then drop.
func (s *Store) PruneOldBuckets(retentionDays int) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	cutoff := time.Now().AddDate(0, 0, -retentionDays).Format("2006-01-02")
	_, err := s.db.Exec(`DELETE FROM rate_buckets WHERE day < ?`, cutoff)
	return err
}

// ===== Sessions =====

type Session struct {
	Token     string
	AdminID   int64
	ExpiresAt int64
}

func (s *Store) CreateSession(adminID int64, ttl time.Duration) (*Session, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	token, err := randHex(32)
	if err != nil {
		return nil, err
	}
	now := time.Now()
	expiresAt := now.Add(ttl).Unix()
	_, err = s.db.Exec(
		`INSERT INTO sessions(token, admin_id, expires_at, created_at) VALUES(?, ?, ?, ?)`,
		token, adminID, expiresAt, now.Unix(),
	)
	if err != nil {
		return nil, err
	}
	return &Session{Token: token, AdminID: adminID, ExpiresAt: expiresAt}, nil
}

func (s *Store) FindSession(token string) (*Session, error) {
	if token == "" {
		return nil, nil
	}
	var sess Session
	err := s.db.QueryRow(
		`SELECT token, admin_id, expires_at FROM sessions WHERE token = ?`,
		token,
	).Scan(&sess.Token, &sess.AdminID, &sess.ExpiresAt)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	if time.Now().Unix() > sess.ExpiresAt {
		// Best-effort cleanup; ignore error.
		_, _ = s.db.Exec(`DELETE FROM sessions WHERE token = ?`, token)
		return nil, nil
	}
	return &sess, nil
}

func (s *Store) DeleteSession(token string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	_, err := s.db.Exec(`DELETE FROM sessions WHERE token = ?`, token)
	return err
}
