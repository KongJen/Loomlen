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
	"go.mongodb.org/mongo-driver/bson/primitive"
	"golang.org/x/crypto/argon2"
	"google.golang.org/api/idtoken"

	"backend/config"
	"backend/models"
	"backend/utils"
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

type TokenPair struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
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

func GenerateTokenPair(userID string) (TokenPair, error) {
	// Generate access token (short-lived)
	accessToken := jwt.New(jwt.SigningMethodHS256)
	accessClaims := accessToken.Claims.(jwt.MapClaims)
	accessClaims["user_id"] = userID
	accessClaims["exp"] = time.Now().Add(1 * 24 * time.Hour).Unix() // 1 hour expiration
	accessClaims["type"] = "access"

	accessTokenString, err := accessToken.SignedString(SECRET_KEY)
	if err != nil {
		return TokenPair{}, err
	}

	// Generate refresh token (long-lived)
	refreshToken := jwt.New(jwt.SigningMethodHS256)
	refreshClaims := refreshToken.Claims.(jwt.MapClaims)
	refreshClaims["user_id"] = userID
	refreshClaims["exp"] = time.Now().Add(7 * 24 * time.Hour).Unix() // 7 days expiration
	refreshClaims["type"] = "refresh"

	refreshTokenString, err := refreshToken.SignedString(SECRET_KEY)
	if err != nil {
		return TokenPair{}, err
	}

	return TokenPair{
		AccessToken:  accessTokenString,
		RefreshToken: refreshTokenString,
	}, nil
}

// func GenerateJWT(userID string) (string, error) {
// 	token := jwt.New(jwt.SigningMethodHS256)
// 	claims := token.Claims.(jwt.MapClaims)
// 	claims["user_id"] = userID
// 	claims["exp"] = time.Now().Add(24 * time.Hour).Unix() // Token expires in 24 hours

// 	tokenString, err := token.SignedString(SECRET_KEY)
// 	if err != nil {
// 		log.Println("Error in JWT token generation", err)
// 		return "", err
// 	}
// 	return tokenString, nil
// }

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

	// Check if email already exists
	existingUser := models.User{}
	err = collection.FindOne(ctx, bson.M{"email": user.Email}).Decode(&existingUser)
	if err == nil {
		// User with this email already exists
		response.WriteHeader(http.StatusConflict)
		response.Write([]byte(`{"message":"Email already registered"}`))
		return
	}

	// If we reach here, the email is unique, so proceed with insertion
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

	log.Printf("User successfully logged in: %s (%s)", dbUser.Email, dbUser.ID.Hex())

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

	tokenPair, err := GenerateTokenPair(dbUser.ID.Hex())
	//jwtToken, err := GenerateJWT(dbUser.ID.Hex()) // Assuming ID is a primitive.ObjectID
	if err != nil {
		response.WriteHeader(http.StatusInternalServerError)
		response.Write([]byte(`{"message":"` + err.Error() + `"}`))
		return
	}

	refreshTokenDoc := bson.M{
		"user_id":    dbUser.ID,
		"token":      tokenPair.RefreshToken,
		"created_at": time.Now(),
		"expires_at": time.Now().Add(7 * 24 * time.Hour),
	}

	refreshCollection := config.GetRefreshTokenCollection() // Create this collection
	_, err = refreshCollection.InsertOne(ctx, refreshTokenDoc)
	if err != nil {
		log.Printf("Error storing refresh token: %v", err)
		// Continue with login process even if storing token fails
	}

	// Return both token and user info (excluding password)
	dbUser.Password = "" // Remove password from response
	responseData := struct {
		AccessToken  string      `json:"access_token"`
		RefreshToken string      `json:"refresh_token"`
		User         models.User `json:"user"`
	}{
		AccessToken:  tokenPair.AccessToken,
		RefreshToken: tokenPair.RefreshToken,
		User:         dbUser,
	}

	json.NewEncoder(response).Encode(responseData)
}

func GoogleLogin(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	var req struct {
		IdToken string `json:"id_token"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		w.Write([]byte(`{"message":"Invalid request body"}`))
		return
	}

	// Verify the ID token
	payload, err := idtoken.Validate(context.Background(), req.IdToken, "866885658869-abo5bnok75am8lbltqdj4b664n36m52h.apps.googleusercontent.com")
	if err != nil {
		w.WriteHeader(http.StatusUnauthorized)
		w.Write([]byte(`{"message":"Invalid Google ID token"}`))
		return
	}

	email, _ := payload.Claims["email"].(string)
	name, _ := payload.Claims["name"].(string)

	collection := config.GetUserCollection()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	var dbUser models.User
	err = collection.FindOne(ctx, bson.M{"email": email}).Decode(&dbUser)
	if err != nil {
		// User does not exist, create new user
		newUser := models.User{
			Email:     email,
			Name:      name,
			CreatedAt: time.Now(),
			LastLogin: time.Now(),
			Password:  "", // No password for Google users
		}
		result, err := collection.InsertOne(ctx, newUser)
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			w.Write([]byte(`{"message":"Error creating user"}`))
			return
		}
		newUser.ID = result.InsertedID.(primitive.ObjectID)
		dbUser = newUser
	} else {
		// Update last login
		collection.UpdateOne(ctx, bson.M{"email": email}, bson.M{"$set": bson.M{"last_login": time.Now()}})
	}

	// Generate JWT tokens as in your normal login
	tokenPair, err := GenerateTokenPair(dbUser.ID.Hex())
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte(`{"message":"Error generating tokens"}`))
		return
	}

	dbUser.Password = "" // Don't send password
	responseData := struct {
		AccessToken  string      `json:"access_token"`
		RefreshToken string      `json:"refresh_token"`
		User         models.User `json:"user"`
	}{
		AccessToken:  tokenPair.AccessToken,
		RefreshToken: tokenPair.RefreshToken,
		User:         dbUser,
	}

	json.NewEncoder(w).Encode(responseData)
}

func UserLogout(response http.ResponseWriter, request *http.Request) {
	response.Header().Set("Content-Type", "application/json")

	// Extract token from Authorization header
	authHeader := request.Header.Get("Authorization")
	if authHeader == "" || len(authHeader) < 8 || authHeader[:7] != "Bearer " {
		response.WriteHeader(http.StatusBadRequest)
		response.Write([]byte(`{"message":"Invalid or missing token"}`))
		return
	}

	tokenString := authHeader[7:] // Remove "Bearer " prefix

	// Validate the token using your existing function
	valid, err := utils.ValidateToken(tokenString)
	if err != nil || !valid {
		response.WriteHeader(http.StatusUnauthorized)
		response.Write([]byte(`{"message":"Invalid token"}`))
		return
	}

	// Parse token to get claims
	token, _ := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
		return SECRET_KEY, nil
	})

	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		response.WriteHeader(http.StatusInternalServerError)
		response.Write([]byte(`{"message":"Could not parse token claims"}`))
		return
	}

	userID, ok := claims["user_id"].(string)
	if !ok {
		response.WriteHeader(http.StatusInternalServerError)
		response.Write([]byte(`{"message":"Invalid user ID in token"}`))
		return
	}

	// Create a token blacklist collection if you don't already have one
	collection := config.GetBlacklistCollection()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// Store the token in the blacklist
	blacklistedToken := struct {
		Token         string    `bson:"token"`
		UserID        string    `bson:"user_id"`
		ExpiresAt     time.Time `bson:"expires_at"`
		BlacklistedAt time.Time `bson:"blacklisted_at"`
	}{
		Token:         tokenString,
		UserID:        userID,
		ExpiresAt:     time.Unix(int64(claims["exp"].(float64)), 0),
		BlacklistedAt: time.Now(),
	}

	_, err = collection.InsertOne(ctx, blacklistedToken)
	if err != nil {
		response.WriteHeader(http.StatusInternalServerError)
		response.Write([]byte(`{"message":"Error blacklisting token"}`))
		return
	}

	response.WriteHeader(http.StatusOK)
	response.Write([]byte(`{"message":"Successfully logged out"}`))
}

func RefreshToken(response http.ResponseWriter, request *http.Request) {
	response.Header().Set("Content-Type", "application/json")

	var requestBody struct {
		RefreshToken string `json:"refresh_token"`
	}

	err := json.NewDecoder(request.Body).Decode(&requestBody)
	if err != nil {
		response.WriteHeader(http.StatusBadRequest)
		response.Write([]byte(`{"message":"Invalid request body"}`))
		return
	}

	token, err := jwt.Parse(requestBody.RefreshToken, func(token *jwt.Token) (interface{}, error) {
		return SECRET_KEY, nil
	})

	if err != nil {
		response.WriteHeader(http.StatusUnauthorized)
		response.Write([]byte(`{"message":"Invalid refresh token"}`))
		return
	}

	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok || !token.Valid {
		response.WriteHeader(http.StatusUnauthorized)
		response.Write([]byte(`{"message":"Invalid token claims"}`))
		return
	}

	tokenType, ok := claims["type"].(string)
	if !ok || tokenType != "refresh" {
		response.WriteHeader(http.StatusUnauthorized)
		response.Write([]byte(`{"message":"Not a refresh token"}`))
		return
	}

	userID, ok := claims["user_id"].(string)
	if !ok {
		response.WriteHeader(http.StatusUnauthorized)
		response.Write([]byte(`{"message":"Invalid user ID in token"}`))
		return
	}

	blacklistCollection := config.GetBlacklistCollection()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	count, err := blacklistCollection.CountDocuments(ctx, bson.M{"token": requestBody.RefreshToken})
	if err != nil || count > 0 {
		response.WriteHeader(http.StatusUnauthorized)
		response.Write([]byte(`{"message":"Token has been revoked"}`))
		return
	}

	// refreshCollection := config.GetRefreshTokenCollection()
	// result := refreshCollection.FindOne(ctx, bson.M{
	// 	"user_id": userID,
	// 	"token":   requestBody.RefreshToken,
	// })

	// if result.Err() != nil {
	// 	response.WriteHeader(http.StatusUnauthorized)
	// 	response.Write([]byte(`{"message":"Refresh token not found or expired"}`))
	// 	return
	// }

	newTokenPair, err := GenerateTokenPair(userID)
	if err != nil {
		response.WriteHeader(http.StatusInternalServerError)
		response.Write([]byte(`{"message":"Error generating new tokens"}`))
		return
	}

	json.NewEncoder(response).Encode(map[string]string{
		"access_token":  newTokenPair.AccessToken,
		"refresh_token": newTokenPair.RefreshToken,
	})
}
