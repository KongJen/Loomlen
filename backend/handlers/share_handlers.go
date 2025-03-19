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

	"github.com/gorilla/mux"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
)

// ShareFile handles the sharing of a file with other users
func ShareFile(w http.ResponseWriter, r *http.Request) {
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
	var shareRequest struct {
		FileID      string        `json:"fileId"`
		SharedWith  []string      `json:"sharedWith"`
		Permission  string        `json:"permission"`
		FileContent []interface{} `json:"fileContent"` // Changed to match frontend
		PaperData   []interface{} `json:"paperData"`   // Changed to match frontend
		Name        string        `json:"name"`
	}

	if err := json.Unmarshal(body, &shareRequest); err != nil {
		log.Printf("Error decoding request: %v", err)
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	log.Printf("Received share request: %+v", shareRequest)

	// Validate permission
	if shareRequest.Permission != "read" && shareRequest.Permission != "write" {
		http.Error(w, "Invalid permission. Must be 'read' or 'write'", http.StatusBadRequest)
		return
	}

	// Convert FileContent and PaperData to JSON bytes for storage
	fileContentBytes, err := json.Marshal(shareRequest.FileContent)
	if err != nil {
		log.Printf("Error marshaling file content: %v", err)
		http.Error(w, "Invalid file content format", http.StatusBadRequest)
		return
	}

	paperDataBytes, err := json.Marshal(shareRequest.PaperData)
	if err != nil {
		log.Printf("Error marshaling paper data: %v", err)
		http.Error(w, "Invalid paper data format", http.StatusBadRequest)
		return
	}

	// Create shared file document
	sharedFile := models.SharedFile{
		ID:          primitive.NewObjectID(),
		OriginalID:  shareRequest.FileID,
		OwnerID:     userID,
		SharedWith:  shareRequest.SharedWith,
		Name:        shareRequest.Name,
		FileContent: fileContentBytes,
		PaperData:   paperDataBytes,
		Permission:  shareRequest.Permission,
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}

	// Insert into database
	sharedCollection := config.GetSharedCollection()
	result, err := sharedCollection.InsertOne(context.Background(), sharedFile)
	if err != nil {
		log.Printf("MongoDB insertion error: %v", err)
		http.Error(w, fmt.Sprintf("Failed to share file: %v", err), http.StatusInternalServerError)
		return
	}

	log.Printf("Document inserted with ID: %v", result.InsertedID)

	// Return success response
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"message": "File shared successfully",
		"id":      sharedFile.ID.Hex(),
	})
}

// GetSharedFiles returns all files shared with the user
func GetSharedFiles(w http.ResponseWriter, r *http.Request) {
	// Verify user is authenticated
	userID, err := utils.GetUserIDFromToken(r)
	if err != nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	// Query database for files shared with the user
	sharedCollection := config.GetSharedCollection()
	filter := bson.M{"$or": []bson.M{
		{"sharedWith": bson.M{"$in": []string{userID}}},
		{"ownerId": userID},
	}}

	cursor, err := sharedCollection.Find(context.Background(), filter)
	if err != nil {
		http.Error(w, "Failed to fetch shared files", http.StatusInternalServerError)
		return
	}
	defer cursor.Close(context.Background())

	// Decode results
	var sharedFiles []models.SharedFile
	if err = cursor.All(context.Background(), &sharedFiles); err != nil {
		http.Error(w, "Failed to decode shared files", http.StatusInternalServerError)
		return
	}

	// Return files
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(sharedFiles)
}

// CloneSharedFile allows a user to clone a shared file to their local storage
func CloneSharedFile(w http.ResponseWriter, r *http.Request) {
	// Verify user is authenticated
	userID, err := utils.GetUserIDFromToken(r)
	if err != nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	// Get shared file ID from URL params
	vars := mux.Vars(r)
	sharedFileID, err := primitive.ObjectIDFromHex(vars["id"])
	if err != nil {
		http.Error(w, "Invalid ID", http.StatusBadRequest)
		return
	}

	// Find the shared file
	sharedCollection := config.GetSharedCollection()
	var sharedFile models.SharedFile
	err = sharedCollection.FindOne(context.Background(), bson.M{"_id": sharedFileID}).Decode(&sharedFile)
	if err != nil {
		http.Error(w, "Shared file not found", http.StatusNotFound)
		return
	}

	// Check if user has access to this file
	hasAccess := false
	for _, sharedUserID := range sharedFile.SharedWith {
		if sharedUserID == userID {
			hasAccess = true
			break
		}
	}
	if !hasAccess && sharedFile.OwnerID != userID {
		http.Error(w, "Access denied", http.StatusForbidden)
		return
	}

	// Return the file content for cloning
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"name":        sharedFile.Name,
		"fileContent": sharedFile.FileContent,
		"paperData":   sharedFile.PaperData,
	})
}
