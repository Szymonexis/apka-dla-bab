package httpapi

import (
	"errors"
	"net/http"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

type Recipe struct {
	ID          uuid.UUID  `json:"id"`
	Title       string     `json:"title"`
	Description string     `json:"description"`
	Ingredients string     `json:"ingredients"`
	Steps       string     `json:"steps"`
	Tags        []string   `json:"tags"`
	TimeMinutes *int       `json:"timeMinutes"`
	Servings    *int       `json:"servings"`
	Favorite    bool       `json:"favorite"`
	ImageFileID *uuid.UUID `json:"imageFileId"`
}

type recipeInput struct {
	Title       string     `json:"title"`
	Description string     `json:"description"`
	Ingredients string     `json:"ingredients"`
	Steps       string     `json:"steps"`
	Tags        []string   `json:"tags"`
	TimeMinutes *int       `json:"timeMinutes"`
	Servings    *int       `json:"servings"`
	Favorite    bool       `json:"favorite"`
	ImageFileID *uuid.UUID `json:"imageFileId"`
}

const recipeCols = `id, title, description, ingredients, steps, tags, time_minutes, servings, favorite, image_file_id`

func scanRecipe(row pgx.Row) (Recipe, error) {
	var rec Recipe
	err := row.Scan(&rec.ID, &rec.Title, &rec.Description, &rec.Ingredients, &rec.Steps,
		&rec.Tags, &rec.TimeMinutes, &rec.Servings, &rec.Favorite, &rec.ImageFileID)
	return rec, err
}

func (a *API) listRecipes(w http.ResponseWriter, r *http.Request) {
	rows, err := a.db.Query(r.Context(),
		`SELECT `+recipeCols+` FROM recipes WHERE user_id = $1
		 ORDER BY favorite DESC, updated_at DESC`, userID(r))
	if err != nil {
		internalErr(w, err)
		return
	}
	defer rows.Close()

	out := []Recipe{}
	for rows.Next() {
		rec, err := scanRecipe(rows)
		if err != nil {
			internalErr(w, err)
			return
		}
		out = append(out, rec)
	}
	writeJSON(w, http.StatusOK, out)
}

func (a *API) getRecipe(w http.ResponseWriter, r *http.Request) {
	id, err := pathUUID(r, "id")
	if err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	rec, err := scanRecipe(a.db.QueryRow(r.Context(),
		`SELECT `+recipeCols+` FROM recipes WHERE id = $1 AND user_id = $2`, id, userID(r)))
	if errors.Is(err, pgx.ErrNoRows) {
		writeErr(w, http.StatusNotFound, "Nie znaleziono przepisu")
		return
	}
	if err != nil {
		internalErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, rec)
}

// randomRecipe losuje przepis - "co dziś na obiad?". Opcjonalnie ?tag=obiad.
func (a *API) randomRecipe(w http.ResponseWriter, r *http.Request) {
	tag := r.URL.Query().Get("tag")
	rec, err := scanRecipe(a.db.QueryRow(r.Context(),
		`SELECT `+recipeCols+` FROM recipes
		 WHERE user_id = $1 AND ($2 = '' OR $2 = ANY(tags))
		 ORDER BY random() LIMIT 1`, userID(r), tag))
	if errors.Is(err, pgx.ErrNoRows) {
		writeErr(w, http.StatusNotFound, "Dodaj najpierw jakiś przepis, to coś wylosuję 🙂")
		return
	}
	if err != nil {
		internalErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, rec)
}

func normalizeTags(tags []string) []string {
	if tags == nil {
		return []string{}
	}
	return tags
}

func (a *API) createRecipe(w http.ResponseWriter, r *http.Request) {
	var in recipeInput
	if err := decodeJSON(r, &in); err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	if in.Title == "" {
		writeErr(w, http.StatusBadRequest, "Przepis musi mieć nazwę")
		return
	}
	in.Tags = normalizeTags(in.Tags)

	var id uuid.UUID
	err := a.db.QueryRow(r.Context(),
		`INSERT INTO recipes (user_id, title, description, ingredients, steps, tags, time_minutes, servings, favorite, image_file_id)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10) RETURNING id`,
		userID(r), in.Title, in.Description, in.Ingredients, in.Steps, in.Tags,
		in.TimeMinutes, in.Servings, in.Favorite, in.ImageFileID).Scan(&id)
	if err != nil {
		internalErr(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, Recipe{
		ID: id, Title: in.Title, Description: in.Description, Ingredients: in.Ingredients,
		Steps: in.Steps, Tags: in.Tags, TimeMinutes: in.TimeMinutes, Servings: in.Servings,
		Favorite: in.Favorite, ImageFileID: in.ImageFileID,
	})
}

func (a *API) updateRecipe(w http.ResponseWriter, r *http.Request) {
	id, err := pathUUID(r, "id")
	if err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	var in recipeInput
	if err := decodeJSON(r, &in); err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	if in.Title == "" {
		writeErr(w, http.StatusBadRequest, "Przepis musi mieć nazwę")
		return
	}
	in.Tags = normalizeTags(in.Tags)

	tag, err := a.db.Exec(r.Context(),
		`UPDATE recipes SET title = $1, description = $2, ingredients = $3, steps = $4,
		 tags = $5, time_minutes = $6, servings = $7, favorite = $8, image_file_id = $9, updated_at = now()
		 WHERE id = $10 AND user_id = $11`,
		in.Title, in.Description, in.Ingredients, in.Steps, in.Tags,
		in.TimeMinutes, in.Servings, in.Favorite, in.ImageFileID, id, userID(r))
	if err != nil {
		internalErr(w, err)
		return
	}
	if tag.RowsAffected() == 0 {
		writeErr(w, http.StatusNotFound, "Nie znaleziono przepisu")
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (a *API) deleteRecipe(w http.ResponseWriter, r *http.Request) {
	id, err := pathUUID(r, "id")
	if err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	if _, err := a.db.Exec(r.Context(),
		`DELETE FROM recipes WHERE id = $1 AND user_id = $2`, id, userID(r)); err != nil {
		internalErr(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
