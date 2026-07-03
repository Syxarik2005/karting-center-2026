.PHONY: build run test clean docker-build docker-run docker-up docker-down lint sqlc fmt help

# ──────────────── Variables ────────────────
APP_NAME   := volna-api
GO         := go
PORT       := 8080
DB_URL     := postgres://postgres:postgres@localhost:5432/volna?sslmode=disable

# ──────────────── Development ────────────────

## build: Compile the API binary
build:
	$(GO) build -o bin/$(APP_NAME) ./cmd/api

## run: Build and run the API server locally
run: build
	DATABASE_URL=$(DB_URL) PORT=$(PORT) ./bin/$(APP_NAME)

## test: Run all tests
test:
	$(GO) test ./... -v -count=1

## fmt: Format Go source files
fmt:
	$(GO) fmt ./...
	goimports -w .

## lint: Run golangci-lint
lint:
	golangci-lint run ./...

## clean: Remove build artifacts
clean:
	rm -rf bin/

# ──────────────── Code Generation ────────────────

## sqlc: Regenerate repository code from SQL queries
sqlc:
	$(GO) run github.com/sqlc-dev/sqlc/cmd/sqlc@latest generate

# ──────────────── Database ────────────────

## db-init: Apply the database schema to PostgreSQL
db-init:
	psql "$(DB_URL)" -f db_init.sql

## db-reset: Drop and recreate the database, then apply schema
db-reset:
	psql "postgres://postgres:postgres@localhost:5432/postgres?sslmode=disable" \
		-c "DROP DATABASE IF EXISTS volna;" \
		-c "CREATE DATABASE volna;"
	$(MAKE) db-init

# ──────────────── Docker ────────────────

## docker-build: Build the Docker image
docker-build:
	docker build -t $(APP_NAME) .

## docker-run: Run the API container (expects a running Postgres)
docker-run:
	docker run --rm -p $(PORT):$(PORT) \
		-e DATABASE_URL=$(DB_URL) \
		-e PORT=$(PORT) \
		--network host \
		$(APP_NAME)

## docker-up: Start API + PostgreSQL via docker-compose
docker-up:
	docker compose up -d

## docker-down: Stop docker-compose services
docker-down:
	docker compose down

# ──────────────── Help ────────────────

## help: Show this help message
help:
	@echo "Volna API — available targets:"
	@echo ""
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## /  /' | column -t -s ':'
