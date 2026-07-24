-- Schemat bazy: domowy organizer ("Ogarniaczka")
-- Wszystkie kwoty pieniężne trzymamy w groszach (BIGINT), daty kalendarzowe jako DATE,
-- momenty w czasie jako TIMESTAMPTZ.

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    display_name TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Pliki (zdjęcia paragonów, zdjęcia przepisów) - fizycznie leżą w MinIO,
-- tu trzymamy tylko metadane i klucz obiektu.
CREATE TABLE files (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    object_key TEXT NOT NULL,
    content_type TEXT NOT NULL DEFAULT 'application/octet-stream',
    size_bytes BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX files_user_idx ON files (user_id);

-- Notatki
CREATE TABLE notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL DEFAULT '',
    content TEXT NOT NULL DEFAULT '',
    pinned BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX notes_user_idx ON notes (user_id, pinned DESC, updated_at DESC);

-- Przypomnienia
CREATE TABLE reminders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    remind_at TIMESTAMPTZ NOT NULL,
    done BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX reminders_user_idx ON reminders (user_id, done, remind_at);

-- Wydarzenia w kalendarzu
CREATE TABLE events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    starts_at TIMESTAMPTZ NOT NULL,
    ends_at TIMESTAMPTZ,
    all_day BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX events_user_idx ON events (user_id, starts_at);

-- Obowiązki / zadania domowe (z możliwością odhaczenia i powtarzania)
CREATE TABLE tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    notes TEXT NOT NULL DEFAULT '',
    due_date DATE,
    repeat TEXT NOT NULL DEFAULT 'none' CHECK (repeat IN ('none', 'daily', 'weekly', 'monthly')),
    done BOOLEAN NOT NULL DEFAULT FALSE,
    done_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX tasks_user_idx ON tasks (user_id, done, due_date);

-- Przepisy
CREATE TABLE recipes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    ingredients TEXT NOT NULL DEFAULT '',
    steps TEXT NOT NULL DEFAULT '',
    tags TEXT[] NOT NULL DEFAULT '{}',
    time_minutes INT,
    servings INT,
    favorite BOOLEAN NOT NULL DEFAULT FALSE,
    image_file_id UUID REFERENCES files(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX recipes_user_idx ON recipes (user_id, favorite DESC, updated_at DESC);

-- Jadłospis: co jemy danego dnia na dany posiłek (przepis z bazy albo dowolny wpis tekstowy)
CREATE TABLE meal_plan (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    plan_date DATE NOT NULL,
    meal_type TEXT NOT NULL CHECK (meal_type IN ('sniadanie', 'drugie_sniadanie', 'obiad', 'podwieczorek', 'kolacja', 'przekaska')),
    recipe_id UUID REFERENCES recipes(id) ON DELETE SET NULL,
    note TEXT NOT NULL DEFAULT '',
    UNIQUE (user_id, plan_date, meal_type)
);
CREATE INDEX meal_plan_user_idx ON meal_plan (user_id, plan_date);

-- Dzienniczek żywieniowy: co faktycznie zjadłam
CREATE TABLE diary_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    entry_date DATE NOT NULL,
    meal_type TEXT NOT NULL CHECK (meal_type IN ('sniadanie', 'drugie_sniadanie', 'obiad', 'podwieczorek', 'kolacja', 'przekaska')),
    description TEXT NOT NULL,
    calories INT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX diary_user_idx ON diary_entries (user_id, entry_date);

-- Limity budżetowe: miesięczny limit na kategorię
CREATE TABLE budgets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    month DATE NOT NULL, -- zawsze pierwszy dzień miesiąca
    category TEXT NOT NULL,
    limit_grosze BIGINT NOT NULL,
    UNIQUE (user_id, month, category)
);

-- Transakcje: wydatki i przychody, opcjonalnie ze zdjęciem paragonu
CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    occurred_on DATE NOT NULL,
    kind TEXT NOT NULL CHECK (kind IN ('expense', 'income')),
    amount_grosze BIGINT NOT NULL CHECK (amount_grosze >= 0),
    category TEXT NOT NULL DEFAULT 'inne',
    description TEXT NOT NULL DEFAULT '',
    receipt_file_id UUID REFERENCES files(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX transactions_user_idx ON transactions (user_id, occurred_on DESC);
