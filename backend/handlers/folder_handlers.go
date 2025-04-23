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

func RenameFolder(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Error reading request body", http.StatusBadRequest)
		return
	}

	var requestRename struct {
		FolderID string `json:"folder_id"`
		Name     string `json:"name"`
	}

	if err := json.Unmarshal(body, &requestRename); err != nil {
		log.Printf("Error decoding request: %v", err)
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	folderCollection := config.GetFolderCollection()

	FolderID, err := primitive.ObjectIDFromHex(requestRename.FolderID)
	if err != nil {
		http.Error(w, "Invalid folder ID", http.StatusBadRequest)
		return
	}
	filter := bson.M{"_id": FolderID}
	update := bson.M{"$set": bson.M{"name": requestRename.Name, "updated_at": time.Now()}}

	_, err = folderCollection.UpdateOne(context.Background(), filter, update)
	if err != nil {
		log.Printf("Error updating folder: %v", err)
		http.Error(w, "Failed to update folder name", http.StatusInternalServerError)
		return
	}

	// Return success response with stats
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"message":  "Rename room successfully",
		"folderId": FolderID.Hex(),
	})
}

func DeleteFolder(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Error reading request body", http.StatusBadRequest)
		return
	}

	var folderRequest struct {
		FolderID string `json:"folder_id"`
	}
	if err := json.Unmarshal(body, &folderRequest); err != nil {
		http.Error(w, "Invalid request format", http.StatusBadRequest)
		return
	}

	objID, err := primitive.ObjectIDFromHex(folderRequest.FolderID)
	if err != nil {
		http.Error(w, "Invalid Folder ID format", http.StatusBadRequest)
		return
	}

	// First, check if folder exists
	var folder models.Folder
	folderCollection := config.GetFolderCollection()
	err = folderCollection.FindOne(context.Background(), bson.M{"_id": objID}).Decode(&folder)
	if err != nil {
		http.Error(w, "Folder not found", http.StatusNotFound)
		return
	}

	roomID := folder.RoomID

	// Use a recursive function to delete the folder and all its contents
	deletedStats, err := deleteFolderAndContents(folder)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	socketServer := socketio.ServerInstance
	if socketServer != nil {
		// Fetch updated folder list for the room
		var folders []models.Folder
		cursor, _ := folderCollection.Find(context.Background(), bson.M{"room_id": roomID})
		cursor.All(context.Background(), &folders)

		socketServer.BroadcastToRoom("", roomID, "folder_list_updated", map[string]interface{}{
			"roomID":  roomID,
			"folders": folders,
		})
	}

	// Return success response with stats
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"message": "Folder and all its contents deleted successfully",
		"stats":   deletedStats,
	})
}

// DeletionStats keeps track of the number of deleted items
type DeletionStats struct {
	Folders int64 `json:"folders"`
	Files   int64 `json:"files"`
	Papers  int64 `json:"papers"`
}

// deleteFolderAndContents recursively deletes a folder, its sub-folders, files, and papers
func deleteFolderAndContents(folder models.Folder) (DeletionStats, error) {
	ctx := context.Background()
	stats := DeletionStats{}

	// Print debugging info to help diagnose the issue
	log.Printf("Deleting folder: ID=%s, OriginalID=%s, Name=%s", folder.ID.Hex(), folder.OriginalID, folder.Name)

	// CRITICAL: Find all sub-folders using the correct field relationship
	// We need to find folders where the current folder's OriginalID is the parent folder ID
	subFolderFilter := bson.M{"sub_folder_id": folder.ID.Hex()}
	log.Printf("Looking for subfolders with filter: %v", subFolderFilter)

	subFolderCursor, err := config.GetFolderCollection().Find(ctx, subFolderFilter)
	if err != nil {
		return stats, fmt.Errorf("failed to query sub-folders: %v", err)
	}
	defer subFolderCursor.Close(ctx)

	// Process each sub-folder recursively
	var subFolders []models.Folder
	if err = subFolderCursor.All(ctx, &subFolders); err != nil {
		return stats, fmt.Errorf("failed to process sub-folders: %v", err)
	}

	log.Printf("Found %d subfolders within folder %s", len(subFolders), folder.Name)

	// Recursively delete each subfolder and its contents
	for _, subFolder := range subFolders {
		log.Printf("Processing subfolder: %s (ID: %s)", subFolder.Name, subFolder.ID.Hex())
		subStats, err := deleteFolderAndContents(subFolder)
		if err != nil {
			return stats, err
		}
		// Accumulate deletion statistics
		stats.Folders += subStats.Folders
		stats.Files += subStats.Files
		stats.Papers += subStats.Papers
	}

	// Find all files directly in this folder
	fileFilter := bson.M{"sub_folder_id": folder.ID.Hex()}
	log.Printf("Looking for files with filter: %v", fileFilter)

	fileCursor, err := config.GetFileCollection().Find(ctx, fileFilter)
	if err != nil {
		return stats, fmt.Errorf("failed to query files: %v", err)
	}
	defer fileCursor.Close(ctx)

	// Collect all files to delete
	var files []models.File
	if err = fileCursor.All(ctx, &files); err != nil {
		return stats, fmt.Errorf("failed to process files: %v", err)
	}

	log.Printf("Found %d files to delete in folder %s", len(files), folder.Name)

	// Delete all papers associated with these files
	for _, file := range files {
		log.Printf("Deleting papers for file: %s (ID: %s)", file.Name, file.ID.Hex())
		paperResult, err := config.GetPaperCollection().DeleteMany(ctx, bson.M{"file_id": file.ID.Hex()})
		if err != nil {
			return stats, fmt.Errorf("failed to delete papers for file %s: %v", file.ID.Hex(), err)
		}
		log.Printf("Deleted %d papers from file %s", paperResult.DeletedCount, file.Name)
		stats.Papers += paperResult.DeletedCount
	}

	// Delete all files in the folder
	fileResult, err := config.GetFileCollection().DeleteMany(ctx, fileFilter)
	if err != nil {
		return stats, fmt.Errorf("failed to delete files in folder: %v", err)
	}
	log.Printf("Deleted %d files from folder %s", fileResult.DeletedCount, folder.Name)
	stats.Files += fileResult.DeletedCount

	// Finally, delete the folder itself
	folderResult, err := config.GetFolderCollection().DeleteOne(ctx, bson.M{"_id": folder.ID})
	if err != nil {
		return stats, fmt.Errorf("failed to delete folder: %v", err)
	}

	if folderResult.DeletedCount == 0 {
		return stats, fmt.Errorf("folder not found during deletion")
	}
	log.Printf("Successfully deleted folder: %s", folder.Name)
	stats.Folders++

	return stats, nil
}

func GetFolder(w http.ResponseWriter, r *http.Request) {
	// Set CORS headers
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Content-Type", "application/json")

	// Get room_id from query parameters
	roomID := r.URL.Query().Get("room_id")
	originalID := r.URL.Query().Get("original_id")
	if roomID == "" {
		http.Error(w, "Missing room_id parameter", http.StatusBadRequest)
		return
	}

	if originalID == "" {
		http.Error(w, "Missing originalID parameter", http.StatusBadRequest)
		return
	}

	// Query database for folders
	folderCollection := config.GetFolderCollection()
	filter := bson.M{
		"$or": []bson.M{
			{"room_id": roomID},
			{"room_id": originalID},
		},
	}

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
