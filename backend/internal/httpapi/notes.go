package httpapi

import (
	"net/http"
	"time"

	"github.com/google/uuid"
)

type Note struct {
	ID        uuid.UUID `json:"id"`
	Title     string    `json:"title"`
	Content   string    `json:"content"`
	Pinned    bool      `json:"pinned"`
	CreatedAt time.Time `json:"createdAt"`
	UpdatedAt time.Time `json:"updatedAt"`
}

type noteInput struct {
	Title   string `json:"title"`
	Content string `json:"content"`
	Pinned  bool   `json:"pinned"`
}

func (a *API) listNotes(w http.ResponseWriter, r *http.Request) {
	rows, err := a.db.Query(r.Context(),
		`SELECT id, title, content, pinned, created_at, updated_at
		 FROM notes WHERE user_id = $1
		 ORDER BY pinned DESC, updated_at DESC`, userID(r))
	if err != nil {
		internalErr(w, err)
		return
	}
	defer rows.Close()

	notes := []Note{}
	for rows.Next() {
		var n Note
		if err := rows.Scan(&n.ID, &n.Title, &n.Content, &n.Pinned, &n.CreatedAt, &n.UpdatedAt); err != nil {
			internalErr(w, err)
			return
		}
		notes = append(notes, n)
	}
	writeJSON(w, http.StatusOK, notes)
}

func (a *API) createNote(w http.ResponseWriter, r *http.Request) {
	var in noteInput
	if err := decodeJSON(r, &in); err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	if in.Title == "" && in.Content == "" {
		writeErr(w, http.StatusBadRequest, "Notatka nie może być pusta")
		return
	}
	var n Note
	n.Title, n.Content, n.Pinned = in.Title, in.Content, in.Pinned
	err := a.db.QueryRow(r.Context(),
		`INSERT INTO notes (user_id, title, content, pinned) VALUES ($1, $2, $3, $4)
		 RETURNING id, created_at, updated_at`,
		userID(r), in.Title, in.Content, in.Pinned).
		Scan(&n.ID, &n.CreatedAt, &n.UpdatedAt)
	if err != nil {
		internalErr(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, n)
}

func (a *API) updateNote(w http.ResponseWriter, r *http.Request) {
	id, err := pathUUID(r, "id")
	if err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	var in noteInput
	if err := decodeJSON(r, &in); err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	tag, err := a.db.Exec(r.Context(),
		`UPDATE notes SET title = $1, content = $2, pinned = $3, updated_at = now()
		 WHERE id = $4 AND user_id = $5`,
		in.Title, in.Content, in.Pinned, id, userID(r))
	if err != nil {
		internalErr(w, err)
		return
	}
	if tag.RowsAffected() == 0 {
		writeErr(w, http.StatusNotFound, "Nie znaleziono notatki")
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (a *API) deleteNote(w http.ResponseWriter, r *http.Request) {
	id, err := pathUUID(r, "id")
	if err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	if _, err := a.db.Exec(r.Context(),
		`DELETE FROM notes WHERE id = $1 AND user_id = $2`, id, userID(r)); err != nil {
		internalErr(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
