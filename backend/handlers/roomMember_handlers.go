package handlers

import (
	"context"
	"encoding/json"
	"io/ioutil"
	"log"
	"net/http"
	"time"

	"backend/config"
	"backend/models"
	"backend/utils"

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
