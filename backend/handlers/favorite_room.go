package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"time"

	"backend/config"
	"backend/models"
	"backend/utils"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
)

// ToggleFavoriteRoom toggles the favorite status of a room
func ToggleFavoriteRoom(w http.ResponseWriter, r *http.Request) {
	// Verify user is authenticated
	userID, err := utils.GetUserIDFromToken(r)
	if err != nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	// Read the request body
	body, err := ioutil.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Error reading request body", http.StatusBadRequest)
		return
	}

	// Unmarshal the request into our struct
	var request struct {
		RoomID string `json:"room_id"`
	}

	if err := json.Unmarshal(body, &request); err != nil {
		log.Printf("Error decoding request: %v", err)
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	// Query database for the favorite status
	favoriteCollection := config.GetFavoriteCollection()
	filter := bson.M{"user_id": userID, "room_id": request.RoomID}

	var favorite models.Favorite
	err = favoriteCollection.FindOne(context.Background(), filter).Decode(&favorite)
	if err != nil {
		// If not found, create a new favorite document
		favorite = models.Favorite{
			ID:        primitive.NewObjectID(),
			UserID:    userID,
			RoomID:    request.RoomID,
			IsFav:     true, // Set to true as we're toggling it ON
			CreatedAt: time.Now(),
			UpdatedAt: time.Now(),
		}
		_, err = favoriteCollection.InsertOne(context.Background(), favorite)
		if err != nil {
			http.Error(w, "Failed to create favorite", http.StatusInternalServerError)
			return
		}
	} else {
		// Toggle the favorite status
		favorite.IsFav = !favorite.IsFav
		favorite.UpdatedAt = time.Now()

		// Update the favorite status in the database
		// Use the correct field name - it's "is_favorite" in the database
		update := bson.M{"$set": bson.M{"is_favorite": favorite.IsFav, "updated_at": favorite.UpdatedAt}}
		_, err = favoriteCollection.UpdateOne(context.Background(), filter, update)
		if err != nil {
			http.Error(w, "Failed to update favorite", http.StatusInternalServerError)
			return
		}
	}

	// Return success response
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"message":     "Room favorite status updated successfully",
		"id":          request.RoomID,
		"is_favorite": fmt.Sprintf("%v", favorite.IsFav),
	})
}
