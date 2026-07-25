package config

import (
	"log"
	"os"
	"strconv"
)

// Config przechowuje całą konfigurację backendu, czytaną ze zmiennych środowiskowych.
type Config struct {
	Port           string
	DatabaseURL    string
	JWTSecret      string
	MinioEndpoint  string
	MinioAccessKey string
	MinioSecretKey string
	MinioBucket    string
	MinioUseSSL    bool

	// Push (self-hosted ntfy). Puste NTFY_URL = push wyłączony,
	// apka nadal dzwoni lokalnymi alarmami.
	NtfyURL          string // adres ntfy widziany z backendu, np. http://ntfy:80
	NtfyPublicURL    string // adres ntfy widziany z telefonu, np. http://192.168.1.20:8090
	Timezone         string // strefa dla porannych podsumowań
	DispatchInterval int    // co ile sekund dyspozytor sprawdza przypomnienia
}

func Load() Config {
	cfg := Config{
		Port:           env("PORT", "8080"),
		DatabaseURL:    env("DATABASE_URL", "postgres://baba:baba@localhost:5432/apka?sslmode=disable"),
		JWTSecret:      env("JWT_SECRET", "dev-secret-zmien-mnie"),
		MinioEndpoint:  env("MINIO_ENDPOINT", "localhost:9000"),
		MinioAccessKey: env("MINIO_ACCESS_KEY", "minioadmin"),
		MinioSecretKey: env("MINIO_SECRET_KEY", "minioadmin"),
		MinioBucket:    env("MINIO_BUCKET", "apka-files"),
		MinioUseSSL:    env("MINIO_USE_SSL", "false") == "true",

		NtfyURL:          env("NTFY_URL", ""),
		NtfyPublicURL:    env("NTFY_PUBLIC_URL", ""),
		Timezone:         env("TIMEZONE", "Europe/Warsaw"),
		DispatchInterval: envInt("DISPATCH_INTERVAL_SECONDS", 30),
	}
	if cfg.JWTSecret == "dev-secret-zmien-mnie" {
		log.Println("UWAGA: używasz domyślnego JWT_SECRET - ustaw własny na produkcji!")
	}
	return cfg
}

func env(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func envInt(key string, def int) int {
	if v := os.Getenv(key); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
		log.Printf("UWAGA: %s=%q nie jest liczbą, używam %d", key, v, def)
	}
	return def
}
