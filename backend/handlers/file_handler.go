// handlers/share_handler.go
package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"time"

	"backend/config"
	"backend/models"
	"backend/socketio"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

func AddFile(w http.ResponseWriter, r *http.Request) {
	body, err := ioutil.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Error reading request body", http.StatusBadRequest)
		return
	}

	var fileRequest struct {
		FileID      string `json:"file_id"`
		RoomID      string `json:"room_id"`
		SubFolderID string `json:"sub_folder_id"`
		Name        string `json:"name"`
	}

	if err := json.Unmarshal(body, &fileRequest); err != nil {
		http.Error(w, "Invalid request format", http.StatusBadRequest)
		return
	}

	// roomCollection := config.GetRoomCollection()
	// roomIDObjID, err := primitive.ObjectIDFromHex(folderRequest.RoomID)
	// if err != nil {
	// 	http.Error(w, "Invalid Room ID format", http.StatusBadRequest)
	// 	return
	// }
	// var room models.Room
	// err = roomCollection.FindOne(context.Background(), bson.M{"id": roomIDObjID}).Decode(&room)
	// if err != nil {
	// 	http.Error(w, "Room not found", http.StatusNotFound)
	// 	return
	// }

	file := models.File{
		ID:          primitive.NewObjectID(),
		OriginalID:  fileRequest.FileID,
		RoomID:      fileRequest.RoomID,
		SubFolderID: fileRequest.SubFolderID,
		Name:        fileRequest.Name,
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}

	fileCollection := config.GetFileCollection()
	_, err = fileCollection.InsertOne(context.Background(), file)
	if err != nil {
		http.Error(w, "Failed to add file", http.StatusInternalServerError)
		return
	}

	// 🔥 **Emit to all users in the room**
	socketServer := socketio.ServerInstance
	if socketServer != nil {
		// Fetch updated folder list
		var files []models.File
		cursor, _ := fileCollection.Find(context.Background(), bson.M{"room_id": fileRequest.RoomID})
		cursor.All(context.Background(), &files)

		socketServer.BroadcastToRoom("", fileRequest.RoomID, "file_list_updated", map[string]interface{}{
			"roomID": fileRequest.RoomID,
			"files":  files,
		})
	}

	// ✅ Send success response
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"message": "Folder added successfully",
		"file_id": file.ID.Hex(),
	})
}

func GetFile(w http.ResponseWriter, r *http.Request) {
	// Set CORS headers
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Content-Type", "application/json")

	// Get room_id from query parameters
	roomID := r.URL.Query().Get("room_id")
	if roomID == "" {
		http.Error(w, "Missing room_id parameter", http.StatusBadRequest)
		return
	}

	// Query database for folders
	fileCollection := config.GetFileCollection()
	filter := bson.M{"room_id": roomID}

	cursor, err := fileCollection.Find(context.Background(), filter)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to fetch files: %v", err), http.StatusInternalServerError)
		return
	}
	defer cursor.Close(context.Background())

	// Decode results into slice
	var files []models.Folder
	if err = cursor.All(context.Background(), &files); err != nil {
		http.Error(w, fmt.Sprintf("Failed to decode files: %v", err), http.StatusInternalServerError)
		return
	}

	// Broadcast to socket if needed
	socketServer := socketio.ServerInstance
	socketServer.BroadcastToRoom("", roomID, "folder_list_updated", files)

	// Encode and return folders
	json.NewEncoder(w).Encode(files)
}

func GetFileIDByOriginalID(w http.ResponseWriter, r *http.Request) {
	// Set CORS headers
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Content-Type", "text/plain") // Return plain text instead of JSON

	// Get original_id from query parameters
	originalID := r.URL.Query().Get("original_id")
	if originalID == "" {
		http.Error(w, "Missing original_id parameter", http.StatusBadRequest)
		return
	}

	// Query database for file by original_id, return only _id
	fileCollection := config.GetFileCollection()
	filter := bson.M{"original_id": originalID}
	projection := bson.M{"_id": 1} // Only select the _id field

	var result struct {
		ID primitive.ObjectID `bson:"_id"`
	}

	err := fileCollection.FindOne(context.Background(), filter, options.FindOne().SetProjection(projection)).Decode(&result)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			http.Error(w, "No file found for given original_id", http.StatusNotFound)
		} else {
			http.Error(w, fmt.Sprintf("Failed to fetch file ID: %v", err), http.StatusInternalServerError)
		}
		return
	}

	// Return only the ID as a string
	fmt.Fprint(w, result.ID.Hex())
}
