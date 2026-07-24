package httpapi

import (
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
)

type apiError struct {
	Error string `json:"error"`
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	if v != nil {
		_ = json.NewEncoder(w).Encode(v)
	}
}

func writeErr(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, apiError{Error: msg})
}

// internalErr loguje szczegóły, a użytkownikowi zwraca ogólny komunikat.
func internalErr(w http.ResponseWriter, err error) {
	log.Printf("BŁĄD: %v", err)
	writeErr(w, http.StatusInternalServerError, "Coś poszło nie tak, spróbuj ponownie")
}

func decodeJSON(r *http.Request, dst any) error {
	dec := json.NewDecoder(http.MaxBytesReader(nil, r.Body, 1<<20))
	if err := dec.Decode(dst); err != nil {
		return errors.New("nieprawidłowe dane w żądaniu")
	}
	return nil
}

func pathUUID(r *http.Request, name string) (uuid.UUID, error) {
	id, err := uuid.Parse(chi.URLParam(r, name))
	if err != nil {
		return uuid.Nil, errors.New("nieprawidłowy identyfikator")
	}
	return id, nil
}

const dateLayout = "2006-01-02"

func parseDate(s string) (time.Time, error) {
	return time.Parse(dateLayout, s)
}

func fmtDate(t time.Time) string {
	return t.Format(dateLayout)
}

func fmtDatePtr(t *time.Time) *string {
	if t == nil {
		return nil
	}
	s := t.Format(dateLayout)
	return &s
}

// parseMonth zamienia "2026-07" na pierwszy dzień miesiąca (UTC).
func parseMonth(s string) (time.Time, error) {
	return time.Parse("2006-01", s)
}
