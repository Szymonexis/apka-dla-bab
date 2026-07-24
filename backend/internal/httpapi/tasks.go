package httpapi

import (
	"errors"
	"fmt"
	"net/http"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

type Task struct {
	ID     uuid.UUID `json:"id"`
	Title  string    `json:"title"`
	Notes  string    `json:"notes"`
	Due    *string   `json:"dueDate"` // YYYY-MM-DD
	Repeat string    `json:"repeat"`  // none | daily | weekly | monthly
	Done   bool      `json:"done"`
}

type taskInput struct {
	Title  string  `json:"title"`
	Notes  string  `json:"notes"`
	Due    *string `json:"dueDate"`
	Repeat string  `json:"repeat"`
}

func validRepeat(s string) bool {
	switch s {
	case "none", "daily", "weekly", "monthly":
		return true
	}
	return false
}

func (in *taskInput) validate() (dueDate *time.Time, err error) {
	if in.Title == "" {
		return nil, errors.New("Podaj treść obowiązku")
	}
	if in.Repeat == "" {
		in.Repeat = "none"
	}
	if !validRepeat(in.Repeat) {
		return nil, errors.New("Nieprawidłowe powtarzanie")
	}
	if in.Due != nil && *in.Due != "" {
		d, err := parseDate(*in.Due)
		if err != nil {
			return nil, errors.New("Nieprawidłowa data")
		}
		dueDate = &d
	}
	return dueDate, nil
}

// listTasks obsługuje ?dueFrom=YYYY-MM-DD&dueTo=YYYY-MM-DD&includeDone=true.
func (a *API) listTasks(w http.ResponseWriter, r *http.Request) {
	q := `SELECT id, title, notes, due_date, repeat, done FROM tasks WHERE user_id = $1`
	args := []any{userID(r)}

	if r.URL.Query().Get("includeDone") != "true" {
		q += ` AND done = FALSE`
	}
	if s := r.URL.Query().Get("dueFrom"); s != "" {
		if d, err := parseDate(s); err == nil {
			args = append(args, d)
			q += fmt.Sprintf(" AND due_date >= $%d", len(args))
		}
	}
	if s := r.URL.Query().Get("dueTo"); s != "" {
		if d, err := parseDate(s); err == nil {
			args = append(args, d)
			q += fmt.Sprintf(" AND due_date <= $%d", len(args))
		}
	}
	q += ` ORDER BY done, due_date NULLS LAST, created_at`

	rows, err := a.db.Query(r.Context(), q, args...)
	if err != nil {
		internalErr(w, err)
		return
	}
	defer rows.Close()

	out := []Task{}
	for rows.Next() {
		var t Task
		var due *time.Time
		if err := rows.Scan(&t.ID, &t.Title, &t.Notes, &due, &t.Repeat, &t.Done); err != nil {
			internalErr(w, err)
			return
		}
		t.Due = fmtDatePtr(due)
		out = append(out, t)
	}
	writeJSON(w, http.StatusOK, out)
}

func (a *API) createTask(w http.ResponseWriter, r *http.Request) {
	var in taskInput
	if err := decodeJSON(r, &in); err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	due, err := in.validate()
	if err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	t := Task{Title: in.Title, Notes: in.Notes, Due: fmtDatePtr(due), Repeat: in.Repeat}
	err = a.db.QueryRow(r.Context(),
		`INSERT INTO tasks (user_id, title, notes, due_date, repeat) VALUES ($1, $2, $3, $4, $5) RETURNING id`,
		userID(r), in.Title, in.Notes, due, in.Repeat).Scan(&t.ID)
	if err != nil {
		internalErr(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, t)
}

func (a *API) updateTask(w http.ResponseWriter, r *http.Request) {
	id, err := pathUUID(r, "id")
	if err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	var in taskInput
	if err := decodeJSON(r, &in); err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	due, err := in.validate()
	if err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	tag, err := a.db.Exec(r.Context(),
		`UPDATE tasks SET title = $1, notes = $2, due_date = $3, repeat = $4
		 WHERE id = $5 AND user_id = $6`,
		in.Title, in.Notes, due, in.Repeat, id, userID(r))
	if err != nil {
		internalErr(w, err)
		return
	}
	if tag.RowsAffected() == 0 {
		writeErr(w, http.StatusNotFound, "Nie znaleziono obowiązku")
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func nextDue(d time.Time, repeat string) time.Time {
	switch repeat {
	case "daily":
		return d.AddDate(0, 0, 1)
	case "weekly":
		return d.AddDate(0, 0, 7)
	case "monthly":
		return d.AddDate(0, 1, 0)
	}
	return d
}

// toggleTask odhacza/odznacza obowiązek. Jeśli obowiązek się powtarza i został
// odhaczony, automatycznie tworzymy kolejne wystąpienie z przesuniętym terminem.
func (a *API) toggleTask(w http.ResponseWriter, r *http.Request) {
	uid := userID(r)
	id, err := pathUUID(r, "id")
	if err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}

	tx, err := a.db.Begin(r.Context())
	if err != nil {
		internalErr(w, err)
		return
	}
	defer func() { _ = tx.Rollback(r.Context()) }()

	var (
		title, notes, repeat string
		due                  *time.Time
		done                 bool
	)
	err = tx.QueryRow(r.Context(),
		`SELECT title, notes, due_date, repeat, done FROM tasks WHERE id = $1 AND user_id = $2 FOR UPDATE`,
		id, uid).Scan(&title, &notes, &due, &repeat, &done)
	if errors.Is(err, pgx.ErrNoRows) {
		writeErr(w, http.StatusNotFound, "Nie znaleziono obowiązku")
		return
	}
	if err != nil {
		internalErr(w, err)
		return
	}

	if done {
		_, err = tx.Exec(r.Context(),
			`UPDATE tasks SET done = FALSE, done_at = NULL WHERE id = $1`, id)
	} else {
		_, err = tx.Exec(r.Context(),
			`UPDATE tasks SET done = TRUE, done_at = now() WHERE id = $1`, id)
		if err == nil && repeat != "none" && due != nil {
			next := nextDue(*due, repeat)
			_, err = tx.Exec(r.Context(),
				`INSERT INTO tasks (user_id, title, notes, due_date, repeat) VALUES ($1, $2, $3, $4, $5)`,
				uid, title, notes, next, repeat)
		}
	}
	if err != nil {
		internalErr(w, err)
		return
	}
	if err := tx.Commit(r.Context()); err != nil {
		internalErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (a *API) deleteTask(w http.ResponseWriter, r *http.Request) {
	id, err := pathUUID(r, "id")
	if err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	if _, err := a.db.Exec(r.Context(),
		`DELETE FROM tasks WHERE id = $1 AND user_id = $2`, id, userID(r)); err != nil {
		internalErr(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
