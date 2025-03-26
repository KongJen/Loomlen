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
)

func AddFolder(w http.ResponseWriter, r *http.Request) {
	body, err := ioutil.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Error reading request body", http.StatusBadRequest)
		return
	}

	var folderRequest struct {
		FolderID    string `json:"folder_id"`
		RoomID      string `json:"room_id"`
		SubFolderID string `json:"sub_folder_id"`
		Name        string `json:"name"`
		Color       int    `json:"color"`
	}

	if err := json.Unmarshal(body, &folderRequest); err != nil {
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

	folder := models.Folder{
		ID:          primitive.NewObjectID(),
		OriginalID:  folderRequest.FolderID,
		RoomID:      folderRequest.RoomID,
		SubFolderID: folderRequest.SubFolderID,
		Name:        folderRequest.Name,
		Color:       folderRequest.Color,
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}

	folderCollection := config.GetFolderCollection()
	_, err = folderCollection.InsertOne(context.Background(), folder)
	if err != nil {
		http.Error(w, "Failed to add folder", http.StatusInternalServerError)
		return
	}

	// 🔥 **Emit to all users in the room**
	socketServer := socketio.ServerInstance
	if socketServer != nil {
		// Fetch updated folder list
		var folders []models.Folder
		cursor, _ := folderCollection.Find(context.Background(), bson.M{"room_id": folderRequest.RoomID})
		cursor.All(context.Background(), &folders)

		socketServer.BroadcastToRoom("", folderRequest.RoomID, "folder_list_updated", map[string]interface{}{
			"roomID":  folderRequest.RoomID,
			"folders": folders,
		})
	}

	// ✅ Send success response
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"message":   "Folder added successfully",
		"folder_id": folder.ID.Hex(),
	})
}

func GetFolder(w http.ResponseWriter, r *http.Request) {
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
	folderCollection := config.GetFolderCollection()
	filter := bson.M{"room_id": roomID}

	cursor, err := folderCollection.Find(context.Background(), filter)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to fetch folders: %v", err), http.StatusInternalServerError)
		return
	}
	defer cursor.Close(context.Background())

	// Decode results into slice
	var folders []models.Folder
	if err = cursor.All(context.Background(), &folders); err != nil {
		http.Error(w, fmt.Sprintf("Failed to decode folders: %v", err), http.StatusInternalServerError)
		return
	}

	// Broadcast to socket if needed
	socketServer := socketio.ServerInstance
	socketServer.BroadcastToRoom("", roomID, "folder_list_updated", folders)

	// Encode and return folders
	json.NewEncoder(w).Encode(folders)
}
