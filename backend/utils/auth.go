// utils/auth.go
package utils

import (
	"backend/config"
	"context"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
)

// Secret key - matching the one used in account_handlers.go
var SECRET_KEY = []byte("gosecretkey")

// GetUserIDFromToken extracts the user ID from the JWT token in the request
func GetUserIDFromToken(r *http.Request) (string, error) {
	// Get the Authorization header
	authHeader := r.Header.Get("Authorization")
	if authHeader == "" {
		return "", errors.New("authorization header is required")
	}

	// Check if the header has the Bearer prefix
	if !strings.HasPrefix(authHeader, "Bearer ") {
		return "", errors.New("invalid authorization header format")
	}

	// Extract the token
	tokenString := strings.TrimPrefix(authHeader, "Bearer ")

	// Parse and validate the token
	token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
		// Validate the algorithm
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("unexpected signing method")
		}
		return SECRET_KEY, nil
	})

	if err != nil {
		return "", err
	}

	if !token.Valid {
		return "", errors.New("invalid token")
	}

	// Extract user ID from claims
	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return "", errors.New("invalid claims")
	}

	// Get the user ID from claims
	// Note: Based on your account_handlers.go, you might need to adjust this
	// to match how you're storing the user ID in the JWT
	userID, ok := claims["user_id"].(string)
	if !ok {
		// If it's not stored as "user_id", you might need to extract it differently
		// This is a fallback for a standard JWT with "sub" claim
		userID, ok = claims["sub"].(string)
		if !ok {
			return "", errors.New("user ID not found in token")
		}
	}

	return userID, nil
}

// ParseObjectID converts a string ID to MongoDB ObjectID
func ParseObjectID(id string) (primitive.ObjectID, error) {
	return primitive.ObjectIDFromHex(id)
}

func ValidateToken(tokenString string) (bool, error) {
	collection := config.GetBlacklistCollection()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	count, err := collection.CountDocuments(ctx, bson.M{"token": tokenString})
	if err != nil {
		return false, err
	}

	if count > 0 {
		return false, fmt.Errorf("token is blacklisted")
	}

	token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
		return SECRET_KEY, nil
	})

	if err != nil {
		return false, err
	}

	return token.Valid, nil
}

// ExtractUserIDFromRequest is a helper function to get userID from context or request
func ExtractUserIDFromRequest(r *http.Request) (string, error) {
	// First check if it's in the context (middleware might have put it there)
	if userID, ok := r.Context().Value("userID").(string); ok {
		return userID, nil
	}

	// Otherwise extract from token
	return GetUserIDFromToken(r)
}

func GetUserIDFromEmail(ctx context.Context, email string) (string, error) {
	// Get the users collection from your config package
	collection := config.GetUserCollection()

	// Create a filter to find the user by email
	filter := bson.M{"email": email}

	// Create a variable to store the user document
	var user struct {
		ID primitive.ObjectID `bson:"_id"`
	}

	// Find the user and extract the ID
	err := collection.FindOne(ctx, filter).Decode(&user)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			return "", errors.New("no user found with this email")
		}
		return "", fmt.Errorf("error retrieving user: %v", err)
	}

	// Convert ObjectID to string and return
	return user.ID.Hex(), nil
}
