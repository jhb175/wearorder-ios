package main

import (
	"sync"
	"time"
)

// RateLimiter is a small wrapper around the rate_buckets table. We
// don't need fancy token-bucket semantics — a fixed daily quota per
// device is enough to keep early-stage abuse off the LLM bill, and the
// admin can raise the cap once the user base grows.
type RateLimiter struct {
	store *Store
	limit int
}

func NewRateLimiter(store *Store, limit int) *RateLimiter {
	return &RateLimiter{store: store, limit: limit}
}

// Allow atomically increments the device's bucket. Returns:
//   - allowed: true if the call should proceed
//   - count:   the bucket count after this call (or just before, if denied)
func (r *RateLimiter) Allow(deviceID string) (allowed bool, count int, err error) {
	day := time.Now().UTC().Format("2006-01-02")
	count, allowed, err = r.store.IncrementRateBucket(deviceID, day, r.limit)
	return allowed, count, err
}

// BurstLimiter is an in-process per-minute cap. We deliberately keep
// it in memory (no SQLite hit) — a server restart resetting burst
// state is fine, the daily limit is the durable line of defense.
//
// Naive sliding-window over a slice; for our scale (≤ thousands of
// devices), the memory cost is trivial.
type BurstLimiter struct {
	mu     sync.Mutex
	limit  int
	window time.Duration
	hits   map[string][]time.Time
	lastGC time.Time
}

func NewBurstLimiter(limit int, window time.Duration) *BurstLimiter {
	return &BurstLimiter{
		limit:  limit,
		window: window,
		hits:   make(map[string][]time.Time),
		lastGC: time.Now(),
	}
}

// Allow returns true if this call is within the allowance, false if
// the device exceeded the burst cap. Always records the attempt so
// repeated denials still extend the cooldown.
func (b *BurstLimiter) Allow(deviceID string) bool {
	if b == nil || b.limit <= 0 {
		return true
	}
	now := time.Now()
	cutoff := now.Add(-b.window)

	b.mu.Lock()
	defer b.mu.Unlock()

	// Periodic garbage-collect of stale per-device slices. We piggy-back
	// on the lock we already hold.
	if now.Sub(b.lastGC) > 5*time.Minute {
		for id, ts := range b.hits {
			pruned := keepRecent(ts, cutoff)
			if len(pruned) == 0 {
				delete(b.hits, id)
			} else {
				b.hits[id] = pruned
			}
		}
		b.lastGC = now
	}

	recent := keepRecent(b.hits[deviceID], cutoff)
	if len(recent) >= b.limit {
		// Record the rejected attempt too — repeated probing should
		// still push the next allowed time further out.
		recent = append(recent, now)
		b.hits[deviceID] = recent
		return false
	}
	recent = append(recent, now)
	b.hits[deviceID] = recent
	return true
}

func keepRecent(ts []time.Time, cutoff time.Time) []time.Time {
	if len(ts) == 0 {
		return ts
	}
	// Find first index where ts[i] >= cutoff. Slice is append-ordered
	// so it's already sorted ascending.
	idx := 0
	for ; idx < len(ts); idx++ {
		if !ts[idx].Before(cutoff) {
			break
		}
	}
	if idx == 0 {
		return ts
	}
	out := make([]time.Time, len(ts)-idx)
	copy(out, ts[idx:])
	return out
}
