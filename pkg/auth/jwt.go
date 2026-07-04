package auth

import (
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/jackc/pgx/v5/pgtype"
)

type TokenManager interface {
	GenerateToken(clientID pgtype.UUID, ttl time.Duration) (string, error)
	ParseToken(tokenString string) (pgtype.UUID, error)
}

type JWTManager struct {
	secretKey string
}

func NewJWTManager(secretKey string) *JWTManager {
	return &JWTManager{secretKey: secretKey}
}

type userClaims struct {
	jwt.RegisteredClaims
	ClientID string `json:"client_id"`
}

func (m *JWTManager) GenerateToken(clientID pgtype.UUID, ttl time.Duration) (string, error) {
	// Convert pgtype.UUID bytes to string for storage in JWT
	uid := uuidBytesToString(clientID.Bytes)
	claims := userClaims{
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(ttl)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
		ClientID: uid,
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(m.secretKey))
}

func (m *JWTManager) ParseToken(tokenString string) (pgtype.UUID, error) {
	token, err := jwt.ParseWithClaims(tokenString, &userClaims{}, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("invalid signing method")
		}
		return []byte(m.secretKey), nil
	})

	if err != nil {
		return pgtype.UUID{}, err
	}

	claims, ok := token.Claims.(*userClaims)
	if !ok || !token.Valid {
		return pgtype.UUID{}, errors.New("invalid token claims")
	}

	parsed, err := ParseUUIDString(claims.ClientID)
	if err != nil {
		return pgtype.UUID{}, err
	}
	return parsed, nil
}

// uuidBytesToString converts a [16]byte UUID to the standard string format.
func uuidBytesToString(b [16]byte) string {
	const hextable = "0123456789abcdef"
	buf := make([]byte, 36)
	idx := 0
	for i := 0; i < 16; i++ {
		if i == 4 || i == 6 || i == 8 || i == 10 {
			buf[idx] = '-'
			idx++
		}
		buf[idx] = hextable[b[i]>>4]
		buf[idx+1] = hextable[b[i]&0x0f]
		idx += 2
	}
	return string(buf)
}

// ParseUUIDString parses a UUID string into pgtype.UUID.
func ParseUUIDString(s string) (pgtype.UUID, error) {
	if len(s) != 36 {
		return pgtype.UUID{}, errors.New("invalid UUID length")
	}
	hex := make([]byte, 0, 32)
	for _, c := range s {
		if c == '-' {
			continue
		}
		hex = append(hex, byte(c))
	}
	if len(hex) != 32 {
		return pgtype.UUID{}, errors.New("invalid UUID format")
	}
	var b [16]byte
	for i := 0; i < 16; i++ {
		hi := hexVal(hex[i*2])
		lo := hexVal(hex[i*2+1])
		if hi == 255 || lo == 255 {
			return pgtype.UUID{}, errors.New("invalid hex in UUID")
		}
		b[i] = hi<<4 | lo
	}
	return pgtype.UUID{Bytes: b, Valid: true}, nil
}

func hexVal(c byte) byte {
	switch {
	case c >= '0' && c <= '9':
		return c - '0'
	case c >= 'a' && c <= 'f':
		return c - 'a' + 10
	case c >= 'A' && c <= 'F':
		return c - 'A' + 10
	default:
		return 255
	}
}
