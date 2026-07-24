// Package notify wysyła powiadomienia push przez self-hostowany serwer ntfy
// (https://ntfy.sh - open source, w naszym docker-compose). Backend publikuje
// wiadomości na prywatny temat użytkownika; telefon subskrybuje go aplikacją
// ntfy i dostaje push nawet, gdy Ogarniaczka jest zamknięta.
package notify

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/base32"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// ErrDisabled: backend działa bez skonfigurowanego ntfy (NTFY_URL puste).
var ErrDisabled = errors.New("serwer ntfy nie jest skonfigurowany")

type Notifier struct {
	db       *pgxpool.Pool
	ntfyURL  string
	client   *http.Client
	loc      *time.Location
	interval time.Duration
}

func New(db *pgxpool.Pool, ntfyURL, timezone string, intervalSeconds int) *Notifier {
	loc, err := time.LoadLocation(timezone)
	if err != nil {
		log.Printf("nieznana strefa czasowa %q, używam UTC", timezone)
		loc = time.UTC
	}
	if intervalSeconds < 1 {
		intervalSeconds = 30
	}
	return &Notifier{
		db:       db,
		ntfyURL:  strings.TrimRight(ntfyURL, "/"),
		client:   &http.Client{Timeout: 10 * time.Second},
		loc:      loc,
		interval: time.Duration(intervalSeconds) * time.Second,
	}
}

func (n *Notifier) Enabled() bool { return n.ntfyURL != "" }

// RandomTopic generuje sekretny temat ntfy, np. "og-x7k2m9...".
func RandomTopic() string {
	buf := make([]byte, 20)
	if _, err := rand.Read(buf); err != nil {
		// awaryjnie: UUID też jest losowy
		return "og-" + strings.ReplaceAll(uuid.NewString(), "-", "")
	}
	enc := base32.StdEncoding.WithPadding(base32.NoPadding)
	return "og-" + strings.ToLower(enc.EncodeToString(buf))
}

type ntfyMessage struct {
	Topic    string   `json:"topic"`
	Title    string   `json:"title"`
	Message  string   `json:"message"`
	Tags     []string `json:"tags,omitempty"`
	Priority int      `json:"priority,omitempty"`
}

// Publish wysyła wiadomość na temat (ntfy przyjmuje publikację jako JSON na "/",
// dzięki czemu polskie znaki w tytule nie przechodzą przez nagłówki HTTP).
func (n *Notifier) Publish(ctx context.Context, topic, title, message string, tags []string, priority int) error {
	if !n.Enabled() {
		return ErrDisabled
	}
	body, err := json.Marshal(ntfyMessage{Topic: topic, Title: title, Message: message, Tags: tags, Priority: priority})
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, n.ntfyURL+"/", bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	res, err := n.client.Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()
	if res.StatusCode >= 300 {
		return fmt.Errorf("ntfy odpowiedziało statusem %d", res.StatusCode)
	}
	return nil
}

// Run uruchamia pętlę dyspozytora - do wywołania w osobnej goroutine.
func (n *Notifier) Run(ctx context.Context) {
	log.Printf("dyspozytor powiadomień: start (ntfy: %v, interwał %s)", n.Enabled(), n.interval)
	ticker := time.NewTicker(n.interval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			n.tick(ctx)
		}
	}
}

func (n *Notifier) tick(ctx context.Context) {
	n.dispatchReminders(ctx)
	n.dispatchDigests(ctx)
}

// dispatchReminders wysyła push dla wymagalnych przypomnień i oznacza je jako
// obsłużone. Bez skonfigurowanego ntfy tylko oznacza (lokalny alarm w aplikacji
// i tak zadzwoni), żeby po późniejszym włączeniu ntfy nie zalać telefonu
// zaległościami.
func (n *Notifier) dispatchReminders(ctx context.Context) {
	rows, err := n.db.Query(ctx,
		`SELECT r.id, r.title, p.ntfy_topic
		 FROM reminders r
		 JOIN push_settings p ON p.user_id = r.user_id
		 WHERE r.done = FALSE AND r.notified_at IS NULL AND r.remind_at <= now()
		 LIMIT 100`)
	if err != nil {
		log.Printf("dyspozytor: zapytanie o przypomnienia: %v", err)
		return
	}
	type due struct {
		id    uuid.UUID
		title string
		topic string
	}
	var dues []due
	for rows.Next() {
		var d due
		if err := rows.Scan(&d.id, &d.title, &d.topic); err != nil {
			rows.Close()
			log.Printf("dyspozytor: scan: %v", err)
			return
		}
		dues = append(dues, d)
	}
	rows.Close()

	for _, d := range dues {
		if n.Enabled() {
			if err := n.Publish(ctx, d.topic, "Przypomnienie 🔔", d.title, []string{"bell"}, 4); err != nil {
				log.Printf("dyspozytor: publikacja przypomnienia %s: %v (spróbuję ponownie)", d.id, err)
				continue // notified_at zostaje NULL -> retry w następnym ticku
			}
		}
		if _, err := n.db.Exec(ctx,
			`UPDATE reminders SET notified_at = now() WHERE id = $1`, d.id); err != nil {
			log.Printf("dyspozytor: oznaczenie przypomnienia %s: %v", d.id, err)
		}
	}
}

// dispatchDigests wysyła raz dziennie (o godzinie wybranej przez użytkownika)
// podsumowanie obowiązków na dziś.
func (n *Notifier) dispatchDigests(ctx context.Context) {
	if !n.Enabled() {
		return
	}
	now := time.Now().In(n.loc)
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC)

	rows, err := n.db.Query(ctx,
		`SELECT p.user_id, p.ntfy_topic, p.daily_digest_hour
		 FROM push_settings p
		 WHERE p.daily_digest_hour >= 0
		   AND (p.digest_last_sent IS NULL OR p.digest_last_sent < $1)
		 LIMIT 200`, today)
	if err != nil {
		log.Printf("dyspozytor: zapytanie o podsumowania: %v", err)
		return
	}
	type digest struct {
		userID uuid.UUID
		topic  string
		hour   int
	}
	var digests []digest
	for rows.Next() {
		var d digest
		if err := rows.Scan(&d.userID, &d.topic, &d.hour); err != nil {
			rows.Close()
			log.Printf("dyspozytor: scan podsumowania: %v", err)
			return
		}
		digests = append(digests, d)
	}
	rows.Close()

	for _, d := range digests {
		if now.Hour() < d.hour {
			continue // jeszcze za wcześnie
		}
		var count int
		if err := n.db.QueryRow(ctx,
			`SELECT COUNT(*) FROM tasks WHERE user_id = $1 AND done = FALSE AND due_date <= $2`,
			d.userID, today).Scan(&count); err != nil {
			log.Printf("dyspozytor: liczenie obowiązków: %v", err)
			continue
		}
		if count > 0 {
			msg := fmt.Sprintf("Na dziś czeka %d obowiązków. Dasz radę! 💪", count)
			if count == 1 {
				msg = "Na dziś czeka 1 obowiązek. Dasz radę! 💪"
			}
			if err := n.Publish(ctx, d.topic, "Dzień dobry! ☀️", msg, []string{"sunny"}, 3); err != nil {
				log.Printf("dyspozytor: publikacja podsumowania: %v (spróbuję ponownie)", err)
				continue
			}
		}
		// oznaczamy dzień jako obsłużony także przy zerze obowiązków (bez spamu)
		if _, err := n.db.Exec(ctx,
			`UPDATE push_settings SET digest_last_sent = $1 WHERE user_id = $2`, today, d.userID); err != nil {
			log.Printf("dyspozytor: zapis digest_last_sent: %v", err)
		}
	}
}
