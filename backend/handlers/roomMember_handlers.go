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
	"backend/socketio"
	"backend/utils"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
)

/*
func RoomMember(w http.ResponseWriter, r *http.Request) {
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
	var roomMemberRequest struct {
		RoomID string `bson:"room_id" json:"room_id"`
		Email  string `bson:"email" json:"email"`
		RoleID string `bson:"role_id" json:"role_id"`
	}

	if err := json.Unmarshal(body, &roomMemberRequest); err != nil {
		log.Printf("Error decoding request: %v", err)
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	log.Printf("Received request: %+v", roomMemberRequest)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	EmailID, err := utils.GetUserIDFromEmail(ctx, roomMemberRequest.Email)
	if err != nil {
		log.Printf("Error getting user ID from email: %v", err)
		http.Error(w, "User not found", http.StatusNotFound)
		return
	}

	// Create shared file document
	RoomMember := models.RoomMembers{
		ID:         primitive.NewObjectID(),
		InviterID:  userID,
		RoomID:     roomMemberRequest.RoomID,
		SharedWith: EmailID,
		RoleID:     roomMemberRequest.RoleID,
		JoinAt:     time.Now(),
	}

	// Insert into database
	RoomMemberCollection := config.GetRoomMemberCollection()
	result, err := RoomMemberCollection.InsertOne(context.Background(), RoomMember)
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
		"id":      RoomMember.ID.Hex(),
	})
}
*/

func RoomMember(w http.ResponseWriter, r *http.Request) {
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
	var roomMemberRequest struct {
		RoomID string   `bson:"room_id" json:"room_id"`
		Emails []string `bson:"email" json:"email"`
		RoleID string   `bson:"role_id" json:"role_id"`
	}

	if err := json.Unmarshal(body, &roomMemberRequest); err != nil {
		log.Printf("Error decoding request: %v", err)
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	log.Printf("Received request: %+v", roomMemberRequest)

	// Prepare a slice to store insertion results
	var insertedDocuments []primitive.ObjectID

	// Get room member collection
	RoomMemberCollection := config.GetRoomMemberCollection()

	// Process each email
	for _, email := range roomMemberRequest.Emails {
		// Get user ID from email
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		EmailID, err := utils.GetUserIDFromEmail(ctx, email)
		if err != nil {
			log.Printf("Error getting user ID for email %s: %v", email, err)
			// Optional: Skip this email or handle error as needed
			continue
		}

		// Create room member document
		RoomMember := models.RoomMembers{
			ID:         primitive.NewObjectID(),
			InviterID:  userID,
			RoomID:     roomMemberRequest.RoomID,
			SharedWith: EmailID,
			RoleID:     roomMemberRequest.RoleID,
			JoinAt:     time.Now(),
		}

		// Insert individual document
		result, err := RoomMemberCollection.InsertOne(context.Background(), RoomMember)
		if err != nil {
			log.Printf("MongoDB insertion error for email %s: %v", email, err)
			continue
		}

		insertedDocuments = append(insertedDocuments, RoomMember.ID)
		log.Printf("Room Member inserted with ID: %v for email: %s", result.InsertedID, email)
	}

	// Check if any documents were inserted
	if len(insertedDocuments) == 0 {
		http.Error(w, "No room members could be added", http.StatusBadRequest)
		return
	}

	// Return success response
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"message":        "Room Members added successfully",
		"inserted_count": len(insertedDocuments),
		"inserted_ids":   insertedDocuments,
	})
}

func ChangeRoomMemberRole(w http.ResponseWriter, r *http.Request) {

	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Error reading request body", http.StatusBadRequest)
		return
	}

	var req struct {
		RoomID  string                   `json:"room_id"`
		Members []map[string]interface{} `json:"members"` // Array of member objects with email and role
	}

	if err := json.Unmarshal(body, &req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	// Get collections
	roomMemberCollection := config.GetRoomMemberCollection()

	// Counter for successful updates
	successCount := 0
	updatedMembers := make([]map[string]interface{}, 0)

	for _, member := range req.Members {
		email, ok := member["email"].(string)
		if !ok {
			continue
		}

		role, ok := member["role"].(string)
		if !ok {
			continue
		}

		// Validate role
		if role != "write" && role != "read" && role != "owner" {
			continue // Skip invalid roles
		}

		// Skip updating owner roles
		if role == "owner" {
			continue
		}

		// Get user ID from email
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		emailID, err := utils.GetUserIDFromEmail(ctx, email)
		fmt.Print("RoomID=", req.RoomID, "\n")
		fmt.Print("emailID=", emailID, "\n")
		fmt.Print("role=", role, "\n")
		if err != nil {
			log.Printf("Error getting user ID for email %s: %v", email, err)
			continue
		}

		// Update the role in the database
		filter := bson.M{
			"room_id":     req.RoomID,
			"shared_with": emailID,
		}
		fmt.Print("filter=", filter, "\n")

		update := bson.M{
			"$set": bson.M{"role_id": role},
		}
		fmt.Print("role_id=", role, "\n")

		result, err := roomMemberCollection.UpdateOne(context.Background(), filter, update)
		if err != nil {
			log.Printf("Error updating role for %s: %v", email, err)
			continue
		}

		if result.ModifiedCount > 0 {
			successCount++

			updatedMembers = append(updatedMembers, map[string]interface{}{
				"email": email,
				"role":  role,
			})
		}
	}

	if successCount == 0 {
		http.Error(w, "No member roles were updated", http.StatusBadRequest)
		return
	}

	socketServer := socketio.ServerInstance
	if socketServer != nil {
		socketServer.BroadcastToRoom("", req.RoomID, "room_members_updated", map[string]interface{}{
			"roomID":  req.RoomID,
			"members": updatedMembers,
		})
		log.Printf("Broadcasted role updates to room %s", req.RoomID)
	} else {
		log.Println("⚠️ Socket.IO server instance not available")
	}

	// Return success response
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"message":       "Member roles updated successfully",
		"updated_count": successCount,
	})
}

func RemoveRoomMember(w http.ResponseWriter, r *http.Request) {

	userID, err := utils.GetUserIDFromToken(r)
	if err != nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Error reading request body", http.StatusBadRequest)
		return
	}

	var req struct {
		RoomID string `json:"room_id"`
		Email  string `json:"email"`
	}

	if err := json.Unmarshal(body, &req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	if req.RoomID == "" {
		http.Error(w, "Room ID is required", http.StatusBadRequest)
		return
	}

	roomMemberCollection := config.GetRoomMemberCollection()

	// Variable to store the user ID that will be used in the deletion query
	var memberID string

	// Case 1: Email is provided
	if req.Email != "" {
		// Get userID from email
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		var err error
		memberID, err = utils.GetUserIDFromEmail(ctx, req.Email)
		if err != nil {
			log.Printf("Error getting user ID from email: %v", err)
			http.Error(w, "User not found with provided email", http.StatusNotFound)
			return
		}

		log.Printf("Using email %s to remove user with ID: %s", req.Email, memberID)
	} else if userID != "" {
		// Case 2: UserToken is provided
		memberID = userID
		log.Printf("Using provided user token: %s", memberID)
	} else {
		// Neither email nor user_token provided
		http.Error(w, "Either email or user_token must be provided", http.StatusBadRequest)
		return
	}

	log.Printf("Using userID %s to remove member from room %s", memberID, req.RoomID)

	filter := bson.M{
		"room_id":     req.RoomID,
		"shared_with": memberID,
	}

	result, err := roomMemberCollection.DeleteOne(context.Background(), filter)
	if err != nil {
		log.Printf("MongoDB deletion error: %v", err)
		http.Error(w, "Failed to remove room member", http.StatusInternalServerError)
		return
	}

	if result.DeletedCount == 0 {
		http.Error(w, "No room member found", http.StatusNotFound)
		return
	}

	// socketServer := socketio.ServerInstance
	// if socketServer != nil {
	// 	socketServer.BroadcastToRoom("", req.RoomID, "room_member_removed", map[string]interface{}{
	// 		"roomID": req.RoomID,
	// 		"userID": userID,
	// 	})
	// 	log.Printf("Broadcasted member removal from room %s", req.RoomID)
	// }

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"message": "Successfully removed from the room",
		"roomID":  req.RoomID,
		"userID":  memberID,
	})
}

func GetRoomMembersInRoom(w http.ResponseWriter, r *http.Request) {

	// Read the request body once
	// roomID := r.URL.Query().Get("room_id")
	roomID := r.URL.Query().Get("room_id")
	// if roomID == "" {
	// 	http.Error(w, "Missing room_id parameter", http.StatusBadRequest)
	// 	return
	// }

	if roomID == "" {
		http.Error(w, "Missing roomID parameter", http.StatusBadRequest)
		return
	}

	roomMemberCollection := config.GetRoomMemberCollection()
	userCollection := config.GetUserCollection()

	filter := bson.M{"room_id": roomID}
	cursor, err := roomMemberCollection.Find(context.Background(), filter)
	if err != nil {
		log.Printf("MongoDB find error: %v", err)
		http.Error(w, "Failed to retrieve room members", http.StatusInternalServerError)
		return
	}
	defer cursor.Close(context.Background())

	var roomMembers []models.RoomMembers
	if err := cursor.All(context.Background(), &roomMembers); err != nil {
		log.Printf("MongoDB decode error: %v", err)
		http.Error(w, "Failed to decode room members", http.StatusInternalServerError)
		return
	}

	roomCollection := config.GetRoomCollection()
	var room models.Room

	roomObjectId, err := primitive.ObjectIDFromHex(roomID)
	if err != nil {
		log.Printf("Error converting RoomID to ObjectID: %v", err)
		http.Error(w, "Invalid Room ID format", http.StatusBadRequest)
		return
	}

	err = roomCollection.FindOne(context.Background(), bson.M{"_id": roomObjectId}).Decode(&room)
	if err != nil {
		log.Printf("Error finding room: %v", err)
		http.Error(w, "Room not found", http.StatusNotFound)
		return
	}

	type MemberInfo struct {
		Email string `json:"email"`
		Name  string `json:"name"`
		Role  string `json:"role"`
	}

	var ownerUser models.User
	ownerObjectID, err := primitive.ObjectIDFromHex(room.OwnerID)
	if err != nil {
		log.Printf("Error converting owner ID to ObjectID: %v", err)
		// Continue without owner info
	} else {
		err = userCollection.FindOne(context.Background(), bson.M{"_id": ownerObjectID}).Decode(&ownerUser)
		if err != nil {
			log.Printf("Error finding owner user: %v", err)
			// Continue without owner info
		}
	}

	membersResponse := []MemberInfo{
		{
			Email: ownerUser.Email,
			Name:  ownerUser.Name,
			Role:  "owner"},
	}

	for _, member := range roomMembers {
		var user models.User
		userObjectID, err := primitive.ObjectIDFromHex(member.SharedWith)
		if err != nil {
			log.Printf("Error converting SharedWith ID to ObjectID: %v", err)
			continue
		}

		err = userCollection.FindOne(context.Background(), bson.M{"_id": userObjectID}).Decode(&user)
		if err != nil {
			log.Printf("Error finding user: %v", err)
			continue
		}

		membersResponse = append(membersResponse, MemberInfo{
			Email: user.Email,
			Name:  user.Name,
			Role:  member.RoleID,
		})

	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(membersResponse)

}
