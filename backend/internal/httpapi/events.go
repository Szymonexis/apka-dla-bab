package httpapi

import (
	"fmt"
	"net/http"
	"time"

	"github.com/google/uuid"
)

type Event struct {
	ID          uuid.UUID  `json:"id"`
	Title       string     `json:"title"`
	Description string     `json:"description"`
	StartsAt    time.Time  `json:"startsAt"`
	EndsAt      *time.Time `json:"endsAt"`
	AllDay      bool       `json:"allDay"`
}

type eventInput struct {
	Title       string     `json:"title"`
	Description string     `json:"description"`
	StartsAt    time.Time  `json:"startsAt"`
	EndsAt      *time.Time `json:"endsAt"`
	AllDay      bool       `json:"allDay"`
}

// listEvents obsługuje ?from=RFC3339&to=RFC3339 (oba opcjonalne).
func (a *API) listEvents(w http.ResponseWriter, r *http.Request) {
	q := `SELECT id, title, description, starts_at, ends_at, all_day FROM events WHERE user_id = $1`
	args := []any{userID(r)}

	if s := r.URL.Query().Get("from"); s != "" {
		if t, err := time.Parse(time.RFC3339, s); err == nil {
			args = append(args, t)
			q += fmt.Sprintf(" AND starts_at >= $%d", len(args))
		}
	}
	if s := r.URL.Query().Get("to"); s != "" {
		if t, err := time.Parse(time.RFC3339, s); err == nil {
			args = append(args, t)
			q += fmt.Sprintf(" AND starts_at < $%d", len(args))
		}
	}
	q += ` ORDER BY starts_at`

	rows, err := a.db.Query(r.Context(), q, args...)
	if err != nil {
		internalErr(w, err)
		return
	}
	defer rows.Close()

	out := []Event{}
	for rows.Next() {
		var e Event
		if err := rows.Scan(&e.ID, &e.Title, &e.Description, &e.StartsAt, &e.EndsAt, &e.AllDay); err != nil {
			internalErr(w, err)
			return
		}
		out = append(out, e)
	}
	writeJSON(w, http.StatusOK, out)
}

func (a *API) createEvent(w http.ResponseWriter, r *http.Request) {
	var in eventInput
	if err := decodeJSON(r, &in); err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	if in.Title == "" || in.StartsAt.IsZero() {
		writeErr(w, http.StatusBadRequest, "Podaj tytuł i termin wydarzenia")
		return
	}
	e := Event{Title: in.Title, Description: in.Description, StartsAt: in.StartsAt, EndsAt: in.EndsAt, AllDay: in.AllDay}
	err := a.db.QueryRow(r.Context(),
		`INSERT INTO events (user_id, title, description, starts_at, ends_at, all_day)
		 VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`,
		userID(r), in.Title, in.Description, in.StartsAt, in.EndsAt, in.AllDay).Scan(&e.ID)
	if err != nil {
		internalErr(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, e)
}

func (a *API) updateEvent(w http.ResponseWriter, r *http.Request) {
	id, err := pathUUID(r, "id")
	if err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	var in eventInput
	if err := decodeJSON(r, &in); err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	tag, err := a.db.Exec(r.Context(),
		`UPDATE events SET title = $1, description = $2, starts_at = $3, ends_at = $4, all_day = $5
		 WHERE id = $6 AND user_id = $7`,
		in.Title, in.Description, in.StartsAt, in.EndsAt, in.AllDay, id, userID(r))
	if err != nil {
		internalErr(w, err)
		return
	}
	if tag.RowsAffected() == 0 {
		writeErr(w, http.StatusNotFound, "Nie znaleziono wydarzenia")
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (a *API) deleteEvent(w http.ResponseWriter, r *http.Request) {
	id, err := pathUUID(r, "id")
	if err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	if _, err := a.db.Exec(r.Context(),
		`DELETE FROM events WHERE id = $1 AND user_id = $2`, id, userID(r)); err != nil {
		internalErr(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
