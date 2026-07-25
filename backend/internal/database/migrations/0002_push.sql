-- Powiadomienia push (self-hosted ntfy) + dedup wysyłek przypomnień.

ALTER TABLE reminders ADD COLUMN notified_at TIMESTAMPTZ;

-- Ustawienia push per użytkownik. Temat ntfy jest losowy i pełni rolę sekretu -
-- kto zna temat, ten może czytać powiadomienia (standardowy model ntfy).
CREATE TABLE push_settings (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    ntfy_topic TEXT NOT NULL,
    -- godzina porannego podsumowania obowiązków; -1 = wyłączone
    daily_digest_hour INT NOT NULL DEFAULT 8 CHECK (daily_digest_hour BETWEEN -1 AND 23),
    digest_last_sent DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Częste zapytanie dyspozytora: niewysłane, niezrobione, wymagalne przypomnienia.
CREATE INDEX reminders_dispatch_idx ON reminders (remind_at)
    WHERE done = FALSE AND notified_at IS NULL;
