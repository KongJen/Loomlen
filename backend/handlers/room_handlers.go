// handlers/share_handler.go
package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"time"

	"backend/config"
	"backend/models"
	"backend/utils"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
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

func RenameRoom(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Error reading request body", http.StatusBadRequest)
		return
	}

	var requestRename struct {
		RoomID string `json:"room_id"`
		Name   string `json:"name"`
	}

	if err := json.Unmarshal(body, &requestRename); err != nil {
		log.Printf("Error decoding request: %v", err)
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	roomCollection := config.GetRoomCollection()

	roomID, err := primitive.ObjectIDFromHex(requestRename.RoomID)
	if err != nil {
		http.Error(w, "Invalid room ID", http.StatusBadRequest)
		return
	}
	filter := bson.M{"_id": roomID}
	update := bson.M{"$set": bson.M{"name": requestRename.Name, "updated_at": time.Now()}}

	_, err = roomCollection.UpdateOne(context.Background(), filter, update)
	if err != nil {
		log.Printf("Error updating room: %v", err)
		http.Error(w, "Failed to update room name", http.StatusInternalServerError)
		return
	}

	// Return success response with stats
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"message": "Rename room successfully",
		"roomId":  roomID.Hex(),
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

	// Create maps to store room_id and role_id for each shared room
	sharedRoomIDs := make([]string, 0)
	roleIDMap := make(map[string]string) // Maps room ID to role ID

	for _, member := range sharedRoomMembers {
		sharedRoomIDs = append(sharedRoomIDs, member.RoomID)
		roleIDMap[member.RoomID] = member.RoleID // Store the role ID for each room
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

		allRooms = append(allRooms, sharedRooms...)
	}

	roomsWithFav := make([]map[string]interface{}, 0)

	for _, room := range allRooms {
		roomData := make(map[string]interface{})

		roomBytes, _ := json.Marshal(room)
		json.Unmarshal(roomBytes, &roomData)

		// For owned rooms, set role_id to "owner"
		if room.OwnerID == userID {
			roomData["role_id"] = "owner"
		} else {
			// For shared rooms, set role_id from the RoomMembers collection
			if roleID, exists := roleIDMap[room.OriginalID]; exists {
				roomData["role_id"] = roleID
			}
		}

		var favorite models.Favorite
		favFilter := bson.M{"user_id": userID, "room_id": room.ID.Hex()}
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

func GetSharedRoomID(w http.ResponseWriter, r *http.Request) {

	originalID := r.URL.Query().Get("original_id")
	if originalID == "" {
		http.Error(w, "Missing originalID parameter", http.StatusBadRequest)
		return
	}
	roomCollection := config.GetRoomCollection()

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	filter := bson.M{"original_id": originalID}

	var room models.Room

	err := roomCollection.FindOne(ctx, filter).Decode(&room)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			http.Error(w, "Room not found", http.StatusNotFound)
		} else {
			http.Error(w, "Error finding room: "+err.Error(), http.StatusInternalServerError)
		}
		return
	}

	roomID := room.ID.Hex()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"room_id": roomID})

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
