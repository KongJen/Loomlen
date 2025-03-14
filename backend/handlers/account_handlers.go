package handlers

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"log"
	"net/http"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"go.mongodb.org/mongo-driver/bson"
	"golang.org/x/crypto/argon2"

	"backend/config"
	"backend/models"
)

var SECRET_KEY = []byte("gosecretkey")

// Argon2 parameters
type argon2Params struct {
	memory      uint32
	iterations  uint32
	parallelism uint8
	saltLength  uint32
	keyLength   uint32
}

// Initialize with recommended parameters
var params = &argon2Params{
	memory:      64 * 1024, // 64MB
	iterations:  3,
	parallelism: 2,
	saltLength:  16,
	keyLength:   32,
}

// generateSalt creates a random salt of specified length
func generateSalt(n uint32) ([]byte, error) {
	salt := make([]byte, n)
	_, err := rand.Read(salt)
	if err != nil {
		return nil, err
	}
	return salt, nil
}

// hashPassword creates an Argon2id hash of a password
func hashPassword(password string) (string, error) {
	salt, err := generateSalt(params.saltLength)
	if err != nil {
		return "", err
	}

	hash := argon2.IDKey(
		[]byte(password),
		salt,
		params.iterations,
		params.memory,
		params.parallelism,
		params.keyLength,
	)

	// Combine salt and hash, encode as base64
	combinedHash := append(salt, hash...)
	encodedHash := base64.RawStdEncoding.EncodeToString(combinedHash)
	return encodedHash, nil
}

// verifyPassword checks if a password matches its hash
func verifyPassword(password, encodedHash string) (bool, error) {
	// Decode the stored hash
	combinedHash, err := base64.RawStdEncoding.DecodeString(encodedHash)
	if err != nil {
		return false, err
	}

	// Extract salt and hash
	salt := combinedHash[:params.saltLength]
	storedHash := combinedHash[params.saltLength:]

	// Compute hash of provided password
	hash := argon2.IDKey(
		[]byte(password),
		salt,
		params.iterations,
		params.memory,
		params.parallelism,
		params.keyLength,
	)

	// Compare computed hash with stored hash
	return string(hash) == string(storedHash), nil
}

func GenerateJWT() (string, error) {
	token := jwt.New(jwt.SigningMethodHS256)
	tokenString, err := token.SignedString(SECRET_KEY)
	if err != nil {
		log.Println("Error in JWT token generation", err)
		return "", err
	}
	return tokenString, nil
}

func UserSignup(response http.ResponseWriter, request *http.Request) {
	response.Header().Set("Content-Type", "application/json")
	var user models.User
	err := json.NewDecoder(request.Body).Decode(&user)
	if err != nil {
		response.WriteHeader(http.StatusBadRequest)
		response.Write([]byte(`{"message":"Invalid request body"}`))
		return
	}

	// Set timestamps
	currentTime := time.Now()
	user.CreatedAt = currentTime
	user.LastLogin = currentTime

	// Hash password
	hashedPassword, err := hashPassword(user.Password)
	if err != nil {
		response.WriteHeader(http.StatusInternalServerError)
		response.Write([]byte(`{"message":"Error hashing password"}`))
		return
	}
	user.Password = hashedPassword

	collection := config.GetUserCollection()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	result, err := collection.InsertOne(ctx, user)
	if err != nil {
		response.WriteHeader(http.StatusInternalServerError)
		response.Write([]byte(`{"message":"Error creating user"}`))
		return
	}

	json.NewEncoder(response).Encode(result)
}

func UserLogin(response http.ResponseWriter, request *http.Request) {
	response.Header().Set("Content-Type", "application/json")
	var user models.User
	var dbUser models.User

	err := json.NewDecoder(request.Body).Decode(&user)
	if err != nil {
		response.WriteHeader(http.StatusBadRequest)
		response.Write([]byte(`{"message":"Invalid request body"}`))
		return
	}

	collection := config.GetUserCollection()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	err = collection.FindOne(ctx, bson.M{"email": user.Email}).Decode(&dbUser)
	if err != nil {
		response.WriteHeader(http.StatusInternalServerError)
		response.Write([]byte(`{"message":"` + err.Error() + `"}`))
		return
	}

	match, err := verifyPassword(user.Password, dbUser.Password)
	if err != nil {
		response.WriteHeader(http.StatusInternalServerError)
		response.Write([]byte(`{"message":"Error verifying password"}`))
		return
	}

	if !match {
		response.WriteHeader(http.StatusUnauthorized)
		response.Write([]byte(`{"response":"Wrong Password!"}`))
		return
	}

	// Update LastLogin time
	_, err = collection.UpdateOne(
		ctx,
		bson.M{"email": user.Email},
		bson.M{
			"$set": bson.M{
				"last_login": time.Now(),
			},
		},
	)
	if err != nil {
		log.Printf("Error updating last login time: %v", err)
		// Continue with login process even if updating timestamp fails
	}

	jwtToken, err := GenerateJWT()
	if err != nil {
		response.WriteHeader(http.StatusInternalServerError)
		response.Write([]byte(`{"message":"` + err.Error() + `"}`))
		return
	}

	// Return both token and user info (excluding password)
	dbUser.Password = "" // Remove password from response
	responseData := struct {
		Token string      `json:"token"`
		User  models.User `json:"user"`
	}{
		Token: jwtToken,
		User:  dbUser,
	}

	json.NewEncoder(response).Encode(responseData)
}
