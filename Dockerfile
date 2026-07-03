# ---- Build stage ----
FROM golang:1.26-alpine AS builder

RUN apk add --no-cache git ca-certificates

WORKDIR /app

# Cache dependencies
COPY go.mod go.sum ./
RUN go mod download

# Copy source and build
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /bin/volna-api ./cmd/api

# ---- Run stage ----
FROM alpine:3.21

RUN apk add --no-cache ca-certificates tzdata

WORKDIR /app

COPY --from=builder /bin/volna-api /app/volna-api
COPY db_init.sql /app/db_init.sql

EXPOSE 8080

ENV ENV=production
ENV PORT=8080

ENTRYPOINT ["/app/volna-api"]
