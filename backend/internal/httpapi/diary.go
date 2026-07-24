package httpapi

import (
	"net/http"
	"time"

	"github.com/google/uuid"
)

type DiaryEntry struct {
	ID          uuid.UUID `json:"id"`
	Date        string    `json:"date"` // YYYY-MM-DD
	MealType    string    `json:"mealType"`
	Description string    `json:"description"`
	Calories    *int      `json:"calories"`
}

type diaryInput struct {
	Date        string `json:"date"`
	MealType    string `json:"mealType"`
	Description string `json:"description"`
	Calories    *int   `json:"calories"`
}

func (in *diaryInput) validate() (time.Time, error) {
	d, err := parseDate(in.Date)
	if err != nil {
		return time.Time{}, errBadDate
	}
	if !validMealTypes[in.MealType] {
		return time.Time{}, errBadMeal
	}
	if in.Description == "" {
		return time.Time{}, errBadDesc
	}
	return d, nil
}

var (
	errBadDate = &validationError{"Nieprawidłowa data"}
	errBadMeal = &validationError{"Nieprawidłowy typ posiłku"}
	errBadDesc = &validationError{"Napisz, co zjadłaś"}
)

type validationError struct{ msg string }

func (e *validationError) Error() string { return e.msg }

// listDiary obsługuje ?from=YYYY-MM-DD&to=YYYY-MM-DD (domyślnie: dzisiaj).
func (a *API) listDiary(w http.ResponseWriter, r *http.Request) {
	from, err1 := parseDate(r.URL.Query().Get("from"))
	to, err2 := parseDate(r.URL.Query().Get("to"))
	if err1 != nil || err2 != nil {
		now := time.Now()
		from = time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC)
		to = from
	}

	rows, err := a.db.Query(r.Context(),
		`SELECT id, entry_date, meal_type, description, calories
		 FROM diary_entries
		 WHERE user_id = $1 AND entry_date >= $2 AND entry_date <= $3
		 ORDER BY entry_date, created_at`, userID(r), from, to)
	if err != nil {
		internalErr(w, err)
		return
	}
	defer rows.Close()

	out := []DiaryEntry{}
	for rows.Next() {
		var e DiaryEntry
		var d time.Time
		if err := rows.Scan(&e.ID, &d, &e.MealType, &e.Description, &e.Calories); err != nil {
			internalErr(w, err)
			return
		}
		e.Date = fmtDate(d)
		out = append(out, e)
	}
	writeJSON(w, http.StatusOK, out)
}

func (a *API) createDiary(w http.ResponseWriter, r *http.Request) {
	var in diaryInput
	if err := decodeJSON(r, &in); err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	d, err := in.validate()
	if err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	e := DiaryEntry{Date: in.Date, MealType: in.MealType, Description: in.Description, Calories: in.Calories}
	err = a.db.QueryRow(r.Context(),
		`INSERT INTO diary_entries (user_id, entry_date, meal_type, description, calories)
		 VALUES ($1, $2, $3, $4, $5) RETURNING id`,
		userID(r), d, in.MealType, in.Description, in.Calories).Scan(&e.ID)
	if err != nil {
		internalErr(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, e)
}

func (a *API) updateDiary(w http.ResponseWriter, r *http.Request) {
	id, err := pathUUID(r, "id")
	if err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	var in diaryInput
	if err := decodeJSON(r, &in); err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	d, err := in.validate()
	if err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	tag, err := a.db.Exec(r.Context(),
		`UPDATE diary_entries SET entry_date = $1, meal_type = $2, description = $3, calories = $4
		 WHERE id = $5 AND user_id = $6`,
		d, in.MealType, in.Description, in.Calories, id, userID(r))
	if err != nil {
		internalErr(w, err)
		return
	}
	if tag.RowsAffected() == 0 {
		writeErr(w, http.StatusNotFound, "Nie znaleziono wpisu")
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (a *API) deleteDiary(w http.ResponseWriter, r *http.Request) {
	id, err := pathUUID(r, "id")
	if err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	if _, err := a.db.Exec(r.Context(),
		`DELETE FROM diary_entries WHERE id = $1 AND user_id = $2`, id, userID(r)); err != nil {
		internalErr(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
