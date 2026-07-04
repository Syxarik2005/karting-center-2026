package config

import (
	"log"

	"github.com/ilyakaznacheev/cleanenv"
)

type Config struct {
	Env      string `env:"ENV" env-default:"local"`
	Server   ServerConfig
	Database DatabaseConfig
	Auth     AuthConfig
}

type ServerConfig struct {
	Port string `env:"PORT" env-default:"8080"`
}

type DatabaseConfig struct {
	URL string `env:"DATABASE_URL" env-default:"postgres://postgres:postgres@localhost:5432/apex?sslmode=disable"`
}

type AuthConfig struct {
	JWTSecret string `env:"JWT_SECRET" env-default:"super-secret-key-for-local-dev"`
}

func LoadConfig() *Config {
	var cfg Config
	if err := cleanenv.ReadEnv(&cfg); err != nil {
		log.Fatalf("Failed to read env config: %s", err)
	}
	return &cfg
}
