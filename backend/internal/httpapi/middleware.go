package httpapi

import (
	"context"
	"fmt"
	"net/http"
	"strings"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

type ctxKey int

const ctxUserID ctxKey = 1

// requireAuth sprawdza nagłówek "Authorization: Bearer <jwt>" i wkłada ID
// użytkownika do kontekstu żądania.
func (a *API) requireAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		header := r.Header.Get("Authorization")
		tokenStr, ok := strings.CutPrefix(header, "Bearer ")
		if !ok || tokenStr == "" {
			writeErr(w, http.StatusUnauthorized, "Musisz się zalogować")
			return
		}

		token, err := jwt.Parse(tokenStr, func(t *jwt.Token) (any, error) {
			if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, fmt.Errorf("nieoczekiwany algorytm podpisu: %v", t.Header["alg"])
			}
			return []byte(a.cfg.JWTSecret), nil
		})
		if err != nil || !token.Valid {
			writeErr(w, http.StatusUnauthorized, "Sesja wygasła, zaloguj się ponownie")
			return
		}

		sub, err := token.Claims.GetSubject()
		if err != nil {
			writeErr(w, http.StatusUnauthorized, "Sesja wygasła, zaloguj się ponownie")
			return
		}
		uid, err := uuid.Parse(sub)
		if err != nil {
			writeErr(w, http.StatusUnauthorized, "Sesja wygasła, zaloguj się ponownie")
			return
		}

		next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), ctxUserID, uid)))
	})
}

// userID zwraca ID zalogowanego użytkownika (middleware gwarantuje obecność).
func userID(r *http.Request) uuid.UUID {
	return r.Context().Value(ctxUserID).(uuid.UUID)
}
