// handlers/share_handler.go
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

// AddShareRoom handles the sharing of a room with other users
func AddRoom(w http.ResponseWriter, r *http.Request) {
	// Verify user is authenticated
	userID, err := utils.GetUserIDFromToken(r)
	if err != nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	// Read the request body once
	body, err := ioutil.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Error reading request body", http.StatusBadRequest)
		return
	}

	// Log the raw request for debugging
	log.Printf("Raw request body: %s\n", string(body))

	// Unmarshal the request into our struct
	var roomRequest struct {
		RoomID string `bson:"room_id" json:"room_id"`
		Name   string `bson:"name" json:"name"`
		IsFav  bool   `bson:"is_favorite" json:"is_favorite"`
	}

	if err := json.Unmarshal(body, &roomRequest); err != nil {
		log.Printf("Error decoding request: %v", err)
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	log.Printf("Received request: %+v", roomRequest)

	// Create shared file document
	Room := models.Room{
		ID:         primitive.NewObjectID(),
		OriginalID: roomRequest.RoomID,
		OwnerID:    userID,
		Name:       roomRequest.Name,
		IsFav:      roomRequest.IsFav,
		CreatedAt:  time.Now(),
		UpdatedAt:  time.Now(),
	}

	// Insert into database
	RoomCollection := config.GetRoomCollection()
	result, err := RoomCollection.InsertOne(context.Background(), Room)
	if err != nil {
		log.Printf("MongoDB insertion error: %v", err)
		http.Error(w, fmt.Sprintf("Failed to add Room: %v", err), http.StatusInternalServerError)
		return
	}

	log.Printf("Room inserted with ID: %v", result.InsertedID)

	// Return success response
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"message": "Room shared successfully",
		"id":      Room.ID.Hex(),
	})
}

// GetSharedRooms returns all rooms shared with the user
func GetRooms(w http.ResponseWriter, r *http.Request) {
	// Verify user is authenticated
	userID, err := utils.GetUserIDFromToken(r)
	if err != nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	// Query database for files shared with the user
	roomCollection := config.GetRoomCollection()
	filter := bson.M{"$or": []bson.M{
		{"owner_id": userID},
	}}

	cursor, err := roomCollection.Find(context.Background(), filter)
	if err != nil {
		http.Error(w, "Failed to fetch rooms", http.StatusInternalServerError)
		return
	}
	defer cursor.Close(context.Background())

	// Decode results
	var Rooms []models.Room
	if err = cursor.All(context.Background(), &Rooms); err != nil {
		http.Error(w, "Failed to decode shared rooms", http.StatusInternalServerError)
		return
	}

	// Return files
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(Rooms)
}

// GetSharedRooms returns all rooms shared with the user
func GetAllRooms(w http.ResponseWriter, r *http.Request) {
	// Verify user is authenticated
	userID, err := utils.GetUserIDFromToken(r)
	if err != nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	// Query database for files shared with the user
	roomCollection := config.GetRoomCollection()
	filter := bson.M{"$or": []bson.M{
		{"owner_id": userID},
	}}

	cursor, err := roomCollection.Find(context.Background(), filter)
	if err != nil {
		http.Error(w, "Failed to fetch rooms", http.StatusInternalServerError)
		return
	}
	defer cursor.Close(context.Background())

	// Decode results
	var Rooms []models.Room
	if err = cursor.All(context.Background(), &Rooms); err != nil {
		http.Error(w, "Failed to decode shared rooms", http.StatusInternalServerError)
		return
	}

	// Return files
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(Rooms)
}
