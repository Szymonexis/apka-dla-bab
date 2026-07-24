package httpapi

import (
	"net/http"
	"time"

	"github.com/google/uuid"
)

var validMealTypes = map[string]bool{
	"sniadanie":        true,
	"drugie_sniadanie": true,
	"obiad":            true,
	"podwieczorek":     true,
	"kolacja":          true,
	"przekaska":        true,
}

type MealPlanEntry struct {
	ID          uuid.UUID  `json:"id"`
	Date        string     `json:"date"` // YYYY-MM-DD
	MealType    string     `json:"mealType"`
	RecipeID    *uuid.UUID `json:"recipeId"`
	RecipeTitle *string    `json:"recipeTitle"`
	Note        string     `json:"note"`
}

// listMealPlan obsługuje ?from=YYYY-MM-DD&to=YYYY-MM-DD (domyślnie: bieżący tydzień od dziś).
func (a *API) listMealPlan(w http.ResponseWriter, r *http.Request) {
	from, err1 := parseDate(r.URL.Query().Get("from"))
	to, err2 := parseDate(r.URL.Query().Get("to"))
	if err1 != nil || err2 != nil {
		now := time.Now()
		from = now.AddDate(0, 0, -7)
		to = now.AddDate(0, 0, 14)
	}

	rows, err := a.db.Query(r.Context(),
		`SELECT m.id, m.plan_date, m.meal_type, m.recipe_id, r.title, m.note
		 FROM meal_plan m
		 LEFT JOIN recipes r ON r.id = m.recipe_id
		 WHERE m.user_id = $1 AND m.plan_date >= $2 AND m.plan_date <= $3
		 ORDER BY m.plan_date`, userID(r), from, to)
	if err != nil {
		internalErr(w, err)
		return
	}
	defer rows.Close()

	out := []MealPlanEntry{}
	for rows.Next() {
		var e MealPlanEntry
		var d time.Time
		if err := rows.Scan(&e.ID, &d, &e.MealType, &e.RecipeID, &e.RecipeTitle, &e.Note); err != nil {
			internalErr(w, err)
			return
		}
		e.Date = fmtDate(d)
		out = append(out, e)
	}
	writeJSON(w, http.StatusOK, out)
}

type mealPlanInput struct {
	Date     string     `json:"date"`
	MealType string     `json:"mealType"`
	RecipeID *uuid.UUID `json:"recipeId"`
	Note     string     `json:"note"`
}

// upsertMealPlan ustawia posiłek na dany dzień (jeden wpis na dzień+typ posiłku).
func (a *API) upsertMealPlan(w http.ResponseWriter, r *http.Request) {
	var in mealPlanInput
	if err := decodeJSON(r, &in); err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	d, err := parseDate(in.Date)
	if err != nil {
		writeErr(w, http.StatusBadRequest, "Nieprawidłowa data")
		return
	}
	if !validMealTypes[in.MealType] {
		writeErr(w, http.StatusBadRequest, "Nieprawidłowy typ posiłku")
		return
	}
	if in.RecipeID == nil && in.Note == "" {
		writeErr(w, http.StatusBadRequest, "Wybierz przepis albo wpisz, co jecie")
		return
	}

	var id uuid.UUID
	err = a.db.QueryRow(r.Context(),
		`INSERT INTO meal_plan (user_id, plan_date, meal_type, recipe_id, note)
		 VALUES ($1, $2, $3, $4, $5)
		 ON CONFLICT (user_id, plan_date, meal_type)
		 DO UPDATE SET recipe_id = EXCLUDED.recipe_id, note = EXCLUDED.note
		 RETURNING id`,
		userID(r), d, in.MealType, in.RecipeID, in.Note).Scan(&id)
	if err != nil {
		internalErr(w, err)
		return
	}

	e := MealPlanEntry{ID: id, Date: in.Date, MealType: in.MealType, RecipeID: in.RecipeID, Note: in.Note}
	if in.RecipeID != nil {
		var title string
		if err := a.db.QueryRow(r.Context(),
			`SELECT title FROM recipes WHERE id = $1 AND user_id = $2`, in.RecipeID, userID(r)).
			Scan(&title); err == nil {
			e.RecipeTitle = &title
		}
	}
	writeJSON(w, http.StatusOK, e)
}

func (a *API) deleteMealPlan(w http.ResponseWriter, r *http.Request) {
	id, err := pathUUID(r, "id")
	if err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	if _, err := a.db.Exec(r.Context(),
		`DELETE FROM meal_plan WHERE id = $1 AND user_id = $2`, id, userID(r)); err != nil {
		internalErr(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
