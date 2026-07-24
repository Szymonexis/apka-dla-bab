package httpapi

import (
	"errors"
	"net/http"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/szymonexis/apka-dla-bab/backend/internal/notify"
)

type pushSettingsResponse struct {
	Enabled    bool   `json:"enabled"`   // czy backend ma skonfigurowany serwer ntfy
	ServerURL  string `json:"serverUrl"` // adres ntfy, który wpisuje się w aplikacji ntfy
	Topic      string `json:"topic"`     // prywatny temat użytkownika (traktuj jak hasło)
	DigestHour int    `json:"digestHour"`
}

// ensurePushSettings zwraca (tworząc przy pierwszym użyciu) ustawienia push.
// Przy tworzeniu oznacza zaległe przypomnienia jako obsłużone, żeby świeżo
// włączony push nie wysłał lawiny starych powiadomień.
func (a *API) ensurePushSettings(r *http.Request, uid uuid.UUID) (topic string, digestHour int, err error) {
	err = a.db.QueryRow(r.Context(),
		`SELECT ntfy_topic, daily_digest_hour FROM push_settings WHERE user_id = $1`, uid).
		Scan(&topic, &digestHour)
	if err == nil {
		return topic, digestHour, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return "", 0, err
	}

	topic = notify.RandomTopic()
	digestHour = 8
	if _, err := a.db.Exec(r.Context(),
		`INSERT INTO push_settings (user_id, ntfy_topic) VALUES ($1, $2)
		 ON CONFLICT (user_id) DO NOTHING`, uid, topic); err != nil {
		return "", 0, err
	}
	if _, err := a.db.Exec(r.Context(),
		`UPDATE reminders SET notified_at = now()
		 WHERE user_id = $1 AND notified_at IS NULL AND remind_at <= now()`, uid); err != nil {
		return "", 0, err
	}
	// przy wyścigu dwóch żądań wygrywa pierwszy INSERT - doczytujemy stan z bazy
	err = a.db.QueryRow(r.Context(),
		`SELECT ntfy_topic, daily_digest_hour FROM push_settings WHERE user_id = $1`, uid).
		Scan(&topic, &digestHour)
	return topic, digestHour, err
}

func (a *API) pushSettingsResponse(topic string, digestHour int) pushSettingsResponse {
	serverURL := a.cfg.NtfyPublicURL
	if serverURL == "" {
		serverURL = a.cfg.NtfyURL
	}
	return pushSettingsResponse{
		Enabled:    a.notifier.Enabled(),
		ServerURL:  serverURL,
		Topic:      topic,
		DigestHour: digestHour,
	}
}

func (a *API) getPushSettings(w http.ResponseWriter, r *http.Request) {
	topic, digestHour, err := a.ensurePushSettings(r, userID(r))
	if err != nil {
		internalErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, a.pushSettingsResponse(topic, digestHour))
}

type pushSettingsInput struct {
	DigestHour int `json:"digestHour"`
}

func (a *API) updatePushSettings(w http.ResponseWriter, r *http.Request) {
	uid := userID(r)
	var in pushSettingsInput
	if err := decodeJSON(r, &in); err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	if in.DigestHour < -1 || in.DigestHour > 23 {
		writeErr(w, http.StatusBadRequest, "Godzina podsumowania musi być z zakresu 0-23 (lub -1, by wyłączyć)")
		return
	}
	topic, _, err := a.ensurePushSettings(r, uid)
	if err != nil {
		internalErr(w, err)
		return
	}
	if _, err := a.db.Exec(r.Context(),
		`UPDATE push_settings SET daily_digest_hour = $1, digest_last_sent = NULL WHERE user_id = $2`,
		in.DigestHour, uid); err != nil {
		internalErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, a.pushSettingsResponse(topic, in.DigestHour))
}

// regeneratePushTopic wymienia sekretny temat na nowy (np. gdy stary wyciekł).
func (a *API) regeneratePushTopic(w http.ResponseWriter, r *http.Request) {
	uid := userID(r)
	if _, _, err := a.ensurePushSettings(r, uid); err != nil {
		internalErr(w, err)
		return
	}
	topic := notify.RandomTopic()
	var digestHour int
	if err := a.db.QueryRow(r.Context(),
		`UPDATE push_settings SET ntfy_topic = $1 WHERE user_id = $2 RETURNING daily_digest_hour`,
		topic, uid).Scan(&digestHour); err != nil {
		internalErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, a.pushSettingsResponse(topic, digestHour))
}

func (a *API) testPush(w http.ResponseWriter, r *http.Request) {
	if !a.notifier.Enabled() {
		writeErr(w, http.StatusBadRequest, "Serwer push (ntfy) nie jest skonfigurowany na backendzie")
		return
	}
	topic, _, err := a.ensurePushSettings(r, userID(r))
	if err != nil {
		internalErr(w, err)
		return
	}
	if err := a.notifier.Publish(r.Context(), topic,
		"Ogarniaczka 💗", "Powiadomienia push działają! 🎉", []string{"tada"}, 3); err != nil {
		writeErr(w, http.StatusBadGateway, "Nie udało się wysłać powiadomienia - sprawdź serwer ntfy")
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}
