package httpapi

import (
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"golang.org/x/crypto/bcrypt"

	"github.com/szymonexis/apka-dla-bab/backend/internal/notify"
)

type userResponse struct {
	ID          uuid.UUID `json:"id"`
	Email       string    `json:"email"`
	DisplayName string    `json:"displayName"`
}

type authResponse struct {
	Token string       `json:"token"`
	User  userResponse `json:"user"`
}

type registerInput struct {
	Email       string `json:"email"`
	Password    string `json:"password"`
	DisplayName string `json:"displayName"`
}

func (a *API) makeToken(uid uuid.UUID) (string, error) {
	claims := jwt.MapClaims{
		"sub": uid.String(),
		"iat": time.Now().Unix(),
		"exp": time.Now().Add(30 * 24 * time.Hour).Unix(),
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString([]byte(a.cfg.JWTSecret))
}

func (a *API) register(w http.ResponseWriter, r *http.Request) {
	var in registerInput
	if err := decodeJSON(r, &in); err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	in.Email = strings.ToLower(strings.TrimSpace(in.Email))
	in.DisplayName = strings.TrimSpace(in.DisplayName)

	if !strings.Contains(in.Email, "@") {
		writeErr(w, http.StatusBadRequest, "Podaj prawidłowy adres e-mail")
		return
	}
	if len(in.Password) < 6 {
		writeErr(w, http.StatusBadRequest, "Hasło musi mieć co najmniej 6 znaków")
		return
	}
	if in.DisplayName == "" {
		in.DisplayName = strings.Split(in.Email, "@")[0]
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(in.Password), bcrypt.DefaultCost)
	if err != nil {
		internalErr(w, err)
		return
	}

	var id uuid.UUID
	err = a.db.QueryRow(r.Context(),
		`INSERT INTO users (email, password_hash, display_name) VALUES ($1, $2, $3) RETURNING id`,
		in.Email, string(hash), in.DisplayName).Scan(&id)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			writeErr(w, http.StatusConflict, "Ten adres e-mail jest już zarejestrowany")
			return
		}
		internalErr(w, err)
		return
	}

	// od razu zakładamy ustawienia push z sekretnym tematem ntfy
	if _, err := a.db.Exec(r.Context(),
		`INSERT INTO push_settings (user_id, ntfy_topic) VALUES ($1, $2)
		 ON CONFLICT (user_id) DO NOTHING`, id, notify.RandomTopic()); err != nil {
		internalErr(w, err)
		return
	}

	token, err := a.makeToken(id)
	if err != nil {
		internalErr(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, authResponse{
		Token: token,
		User:  userResponse{ID: id, Email: in.Email, DisplayName: in.DisplayName},
	})
}

type loginInput struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

func (a *API) login(w http.ResponseWriter, r *http.Request) {
	var in loginInput
	if err := decodeJSON(r, &in); err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	in.Email = strings.ToLower(strings.TrimSpace(in.Email))

	var (
		id   uuid.UUID
		hash string
		name string
	)
	err := a.db.QueryRow(r.Context(),
		`SELECT id, password_hash, display_name FROM users WHERE email = $1`, in.Email).
		Scan(&id, &hash, &name)
	if errors.Is(err, pgx.ErrNoRows) {
		writeErr(w, http.StatusUnauthorized, "Nieprawidłowy e-mail lub hasło")
		return
	}
	if err != nil {
		internalErr(w, err)
		return
	}
	if bcrypt.CompareHashAndPassword([]byte(hash), []byte(in.Password)) != nil {
		writeErr(w, http.StatusUnauthorized, "Nieprawidłowy e-mail lub hasło")
		return
	}

	token, err := a.makeToken(id)
	if err != nil {
		internalErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, authResponse{
		Token: token,
		User:  userResponse{ID: id, Email: in.Email, DisplayName: name},
	})
}

func (a *API) me(w http.ResponseWriter, r *http.Request) {
	uid := userID(r)
	var out userResponse
	out.ID = uid
	err := a.db.QueryRow(r.Context(),
		`SELECT email, display_name FROM users WHERE id = $1`, uid).
		Scan(&out.Email, &out.DisplayName)
	if err != nil {
		internalErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, out)
}
