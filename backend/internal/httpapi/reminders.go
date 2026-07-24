package httpapi

import (
	"net/http"
	"time"

	"github.com/google/uuid"
)

type Reminder struct {
	ID       uuid.UUID `json:"id"`
	Title    string    `json:"title"`
	RemindAt time.Time `json:"remindAt"`
	Done     bool      `json:"done"`
}

type reminderInput struct {
	Title    string    `json:"title"`
	RemindAt time.Time `json:"remindAt"`
}

func (a *API) listReminders(w http.ResponseWriter, r *http.Request) {
	q := `SELECT id, title, remind_at, done FROM reminders WHERE user_id = $1`
	if r.URL.Query().Get("includeDone") != "true" {
		q += ` AND done = FALSE`
	}
	q += ` ORDER BY done, remind_at`

	rows, err := a.db.Query(r.Context(), q, userID(r))
	if err != nil {
		internalErr(w, err)
		return
	}
	defer rows.Close()

	out := []Reminder{}
	for rows.Next() {
		var rem Reminder
		if err := rows.Scan(&rem.ID, &rem.Title, &rem.RemindAt, &rem.Done); err != nil {
			internalErr(w, err)
			return
		}
		out = append(out, rem)
	}
	writeJSON(w, http.StatusOK, out)
}

func (a *API) createReminder(w http.ResponseWriter, r *http.Request) {
	var in reminderInput
	if err := decodeJSON(r, &in); err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	if in.Title == "" || in.RemindAt.IsZero() {
		writeErr(w, http.StatusBadRequest, "Podaj treść i termin przypomnienia")
		return
	}
	var rem Reminder
	rem.Title, rem.RemindAt = in.Title, in.RemindAt
	err := a.db.QueryRow(r.Context(),
		`INSERT INTO reminders (user_id, title, remind_at) VALUES ($1, $2, $3) RETURNING id`,
		userID(r), in.Title, in.RemindAt).Scan(&rem.ID)
	if err != nil {
		internalErr(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, rem)
}

func (a *API) updateReminder(w http.ResponseWriter, r *http.Request) {
	id, err := pathUUID(r, "id")
	if err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	var in reminderInput
	if err := decodeJSON(r, &in); err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	// notified_at wraca na NULL - po zmianie terminu przypomnienie ma
	// zadzwonić ponownie o nowej porze
	tag, err := a.db.Exec(r.Context(),
		`UPDATE reminders SET title = $1, remind_at = $2, notified_at = NULL
		 WHERE id = $3 AND user_id = $4`,
		in.Title, in.RemindAt, id, userID(r))
	if err != nil {
		internalErr(w, err)
		return
	}
	if tag.RowsAffected() == 0 {
		writeErr(w, http.StatusNotFound, "Nie znaleziono przypomnienia")
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (a *API) toggleReminder(w http.ResponseWriter, r *http.Request) {
	id, err := pathUUID(r, "id")
	if err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	tag, err := a.db.Exec(r.Context(),
		`UPDATE reminders SET done = NOT done WHERE id = $1 AND user_id = $2`, id, userID(r))
	if err != nil {
		internalErr(w, err)
		return
	}
	if tag.RowsAffected() == 0 {
		writeErr(w, http.StatusNotFound, "Nie znaleziono przypomnienia")
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (a *API) deleteReminder(w http.ResponseWriter, r *http.Request) {
	id, err := pathUUID(r, "id")
	if err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	if _, err := a.db.Exec(r.Context(),
		`DELETE FROM reminders WHERE id = $1 AND user_id = $2`, id, userID(r)); err != nil {
		internalErr(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
