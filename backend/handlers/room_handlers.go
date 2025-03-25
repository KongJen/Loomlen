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
		Color  int    `bson:"color" json:"color"`
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
		Color:      roomRequest.Color,
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
	// Create a default favorite entry for this room
	favorite := models.Favorite{
		ID:        primitive.NewObjectID(),
		UserID:    userID,
		RoomID:    Room.ID.Hex(),
		IsFav:     false,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}

	favoriteCollection := config.GetFavoriteCollection()
	_, err = favoriteCollection.InsertOne(context.Background(), favorite)
	if err != nil {
		log.Printf("Warning: Failed to create default favorite status: %v", err)
		// Continue even if this fails
	}

	log.Printf("Room inserted with ID: %v", result.InsertedID)

	// Return success response
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"message": "Room shared successfully",
		"id":      Room.ID.Hex(),
	})
}

// Add Get shared room with other users
func GetRooms(w http.ResponseWriter, r *http.Request) {
	// Verify user is authenticated
	userID, err := utils.GetUserIDFromToken(r)
	if err != nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	// Get room collections
	roomCollection := config.GetRoomCollection()
	roomMemberCollection := config.GetRoomMemberCollection()
	favoriteCollection := config.GetFavoriteCollection()

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	ownedRoomsFilter := bson.M{"owner_id": userID}

	// Find owned rooms
	ownedRoomsCursor, err := roomCollection.Find(ctx, ownedRoomsFilter)
	if err != nil {
		log.Printf("Error finding owned rooms: %v", err)
		http.Error(w, "Failed to fetch owned rooms", http.StatusInternalServerError)
		return
	}
	defer ownedRoomsCursor.Close(ctx)

	// Decode owned rooms
	var ownedRooms []models.Room
	if err = ownedRoomsCursor.All(ctx, &ownedRooms); err != nil {
		log.Printf("Error decoding owned rooms: %v", err)
		http.Error(w, "Failed to decode owned rooms", http.StatusInternalServerError)
		return
	}

	sharedRoomMembersFilter := bson.M{"shared_with": userID}
	sharedRoomMembersCursor, err := roomMemberCollection.Find(ctx, sharedRoomMembersFilter)
	if err != nil {
		log.Println("Database query error:", err)
		http.Error(w, "Failed to fetch rooms", http.StatusInternalServerError)
		log.Printf("Error finding shared room members: %v", err)
		http.Error(w, "Failed to fetch shared room members", http.StatusInternalServerError)
		return
	}
	defer sharedRoomMembersCursor.Close(ctx)

	// Decode shared room members
	var sharedRoomMembers []models.RoomMembers
	if err = sharedRoomMembersCursor.All(ctx, &sharedRoomMembers); err != nil {
		log.Printf("Error decoding shared room members: %v", err)
		http.Error(w, "Failed to decode shared rooms", http.StatusInternalServerError)
		return
	}

	sharedRoomIDs := make([]string, 0)
	for _, member := range sharedRoomMembers {
		sharedRoomIDs = append(sharedRoomIDs, member.RoomID)
	}

	allRooms := ownedRooms

	// Find shared rooms details
	if len(sharedRoomIDs) > 0 {
		sharedRoomsFilter := bson.M{"original_id": bson.M{"$in": sharedRoomIDs}}

		sharedRoomsCursor, err := roomCollection.Find(ctx, sharedRoomsFilter)
		if err != nil {
			log.Printf("Error finding shared room details: %v", err)
			http.Error(w, "Failed to fetch shared room details", http.StatusInternalServerError)
			return
		}
		defer sharedRoomsCursor.Close(ctx)

		var sharedRooms []models.Room
		if err = sharedRoomsCursor.All(ctx, &sharedRooms); err != nil {
			log.Printf("Error decoding shared room details: %v", err)
			http.Error(w, "Failed to decode shared room details", http.StatusInternalServerError)
			return
		}

		for _, room := range sharedRooms {
			log.Printf("Found Shared Room - ID: %v, OriginalID: %v", room.ID, room.OriginalID)
		}

		allRooms = append(allRooms, sharedRooms...)
	}

	roomsWithFav := make([]map[string]interface{}, 0)

	for _, room := range allRooms {
		roomData := make(map[string]interface{})

		roomBytes, _ := json.Marshal(room)
		json.Unmarshal(roomBytes, &roomData)

		var favorite models.Favorite
		favFilter := bson.M{"user_id": userID, "room_id": room.OriginalID}
		err = favoriteCollection.FindOne(ctx, favFilter).Decode(&favorite)

		if err == nil {
			roomData["is_favorite"] = favorite.IsFav
		} else {
			roomData["is_favorite"] = false
		}

		roomsWithFav = append(roomsWithFav, roomData)
	}

	// Return rooms
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(roomsWithFav)
}

// // GetSharedRooms returns all rooms shared with the user
// func GetAllRooms(w http.ResponseWriter, r *http.Request) {
// 	// Verify user is authenticated
// 	userID, err := utils.GetUserIDFromToken(r)
// 	if err != nil {
// 		http.Error(w, "Unauthorized", http.StatusUnauthorized)
// 		return
// 	}

// 	// Query database for files shared with the user
// 	roomCollection := config.GetRoomCollection()
// 	filter := bson.M{"$or": []bson.M{
// 		{"owner_id": userID},
// 	}}

// 	cursor, err := roomCollection.Find(context.Background(), filter)
// 	if err != nil {
// 		http.Error(w, "Failed to fetch rooms", http.StatusInternalServerError)
// 		return
// 	}
// 	defer cursor.Close(context.Background())

// 	// Decode results
// 	var Rooms []models.Room
// 	if err = cursor.All(context.Background(), &Rooms); err != nil {
// 		http.Error(w, "Failed to decode shared rooms", http.StatusInternalServerError)
// 		return
// 	}

// 	// Return files
// 	w.Header().Set("Content-Type", "application/json")
// 	json.NewEncoder(w).Encode(Rooms)
// }
