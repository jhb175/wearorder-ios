package main

import (
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
