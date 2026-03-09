package config

import (
	"os"
)

type Config struct {
	Port           string
	DatabaseURL    string
	RedisURL       string
	MinioEndpoint  string
	MinioAccessKey string
	MinioSecretKey string
	MinioBucket    string
	JWTSecret      string
	APNsKeyFile    string
	APNsKeyID      string
	APNsTeamID     string
	// AI provider API keys
	DeepSeekAPIKey string
	GLMAPIKey      string
	KimiAPIKey     string
	DoubaoAPIKey   string
	QwenAPIKey     string
}

func Load() *Config {
	return &Config{
		Port:           getEnv("PORT", "8080"),
		DatabaseURL:    getEnv("DB_URL", "postgres://fh:pass@localhost:5432/familyhealth?sslmode=disable"),
		RedisURL:       getEnv("REDIS_URL", "redis://localhost:6379"),
		MinioEndpoint:  getEnv("MINIO_ENDPOINT", "localhost:9000"),
		MinioAccessKey: getEnv("MINIO_ACCESS_KEY", "minioadmin"),
		MinioSecretKey: getEnv("MINIO_SECRET_KEY", "minioadmin"),
		MinioBucket:    getEnv("MINIO_BUCKET", "familyhealth"),
		JWTSecret:      getEnv("JWT_SECRET", "change-me-in-production"),
		APNsKeyFile:    getEnv("APNS_KEY_FILE", ""),
		APNsKeyID:      getEnv("APNS_KEY_ID", ""),
		APNsTeamID:     getEnv("APNS_TEAM_ID", ""),
		DeepSeekAPIKey: getEnv("DEEPSEEK_API_KEY", ""),
		GLMAPIKey:      getEnv("GLM_API_KEY", ""),
		KimiAPIKey:     getEnv("KIMI_API_KEY", ""),
		DoubaoAPIKey:   getEnv("DOUBAO_API_KEY", ""),
		QwenAPIKey:     getEnv("QWEN_API_KEY", ""),
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
