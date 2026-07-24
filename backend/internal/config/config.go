package config

import (
	"log"
	"os"
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
