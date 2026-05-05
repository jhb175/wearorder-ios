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

func setSessionCookie(w http.ResponseWriter, token string, expiresAt int64) {
	http.SetCookie(w, &http.Cookie{
		Name:     sessionCookieName,
		Value:    token,
		Path:     "/admin",
		HttpOnly: true,
		Secure:   true, // production: served over HTTPS via Nginx
		SameSite: http.SameSiteLaxMode,
		Expires:  time.Unix(expiresAt, 0),
	})
}

func clearSessionCookie(w http.ResponseWriter) {
	http.SetCookie(w, &http.Cookie{
		Name:     sessionCookieName,
		Value:    "",
		Path:     "/admin",
		HttpOnly: true,
		Secure:   true,
		SameSite: http.SameSiteLaxMode,
		MaxAge:   -1,
	})
}
