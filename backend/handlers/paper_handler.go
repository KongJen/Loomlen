// handlers/share_handler.go
package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"backend/config"
	"backend/models"
	"backend/socketio"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
)

func AddPaper(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Error reading request body", http.StatusBadRequest)
		return
	}

	var paperRequest struct {
		PaperID    string  `json:"paper_id"`
		RoomID     string  `json:"room_id"`
		FileID     string  `json:"file_id"`
		TemplateID string  `json:"template_id"`
		PageNumber int     `json:"page_number"`
		Width      float64 `json:"width"`
		Height     float64 `json:"height"`
	}

	if err := json.Unmarshal(body, &paperRequest); err != nil {
		http.Error(w, "Invalid request format", http.StatusBadRequest)
		return

	}

	paper := models.Paper{
		ID:         primitive.NewObjectID(),
		OriginalID: paperRequest.PaperID,
		RoomID:     paperRequest.RoomID,
		FileID:     paperRequest.FileID,
		TemplateID: paperRequest.TemplateID,
		PageNumber: paperRequest.PageNumber,
		Width:      paperRequest.Width,
		Height:     paperRequest.Height,
		CreatedAt:  time.Now(),
		UpdatedAt:  time.Now(),
	}

	paperCollection := config.GetPaperCollection()
	_, err = paperCollection.InsertOne(context.Background(), paper)
	if err != nil {
		http.Error(w, "Failed to add paper", http.StatusInternalServerError)
		return
	}

	// 🔥 **Emit to all users in the room**
	socketServer := socketio.ServerInstance
	if socketServer != nil {
		// Fetch updated folder list
		var papers []models.Paper
		cursor, _ := paperCollection.Find(context.Background(), bson.M{"room_id": paperRequest.RoomID})
		cursor.All(context.Background(), &papers)

		socketServer.BroadcastToRoom("", paperRequest.RoomID, "paper_list_updated", map[string]interface{}{
			"roomID": paperRequest.RoomID,
			"papers": papers,
		})
	}

	// ✅ Send success response
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"message":  "Folder added successfully",
		"paper_id": paper.ID.Hex(),
	})
}

func AddDrawingPoint(w http.ResponseWriter, r *http.Request) {
	paperID := r.Header.Get("paper_id")
	if paperID == "" {
		http.Error(w, "Missing paper_id header", http.StatusBadRequest)
		return
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Error reading request body", http.StatusBadRequest)
		return
	}

	// Convert paper ID to ObjectID
	paperObjID, err := primitive.ObjectIDFromHex(paperID)
	if err != nil {
		http.Error(w, "Invalid paper ID format", http.StatusBadRequest)
		return
	}

	// Define a struct to match the incoming data structure
	var drawingRequests []struct {
		Type string `json:"type"`
		Data struct {
			ID      int64 `json:"id"`
			Offsets []struct {
				X float64 `json:"x"`
				Y float64 `json:"y"`
			} `json:"offsets"`
			Color int     `json:"color"`
			Width float64 `json:"width"`
			Tool  string  `json:"tool"`
		} `json:"data"`
		Timestamp int64 `json:"timestamp"`
	}

	// Unmarshal the JSON data
	if err := json.Unmarshal(body, &drawingRequests); err != nil {
		http.Error(w, "Invalid request format", http.StatusBadRequest)
		return
	}

	// Validate input
	if len(drawingRequests) == 0 {
		// If no drawing data, set the drawing data to null in the database
		update := bson.M{
			"$set": bson.M{
				"drawing_data": nil,
				"updated_at":   time.Now(),
			},
		}

		// Update the paper with null drawing data
		paperCollection := config.GetPaperCollection()
		_, err := paperCollection.UpdateOne(context.Background(), bson.M{"_id": paperObjID}, update)
		if err != nil {
			http.Error(w, "Failed to update paper", http.StatusInternalServerError)
			return
		}

		// Send success response for no drawing data
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{
			"message":   "Drawing data set to null successfully",
			"paper_id":  paperID,
			"room_id":   "", // Empty room_id for no data
			"file_id":   "", // Empty file_id for no data
			"timestamp": time.Now().Format(time.RFC3339),
		})
		return
	}

	// If there is drawing data, convert it to DrawingPoints
	var drawingPoints []models.DrawingPoint
	for _, req := range drawingRequests {
		if req.Type != "drawing" {
			continue // Skip non-drawing types
		}

		// Create offsets
		offsets := make([]models.Offset, len(req.Data.Offsets))
		for i, offset := range req.Data.Offsets {
			offsets[i] = models.Offset{
				X: offset.X,
				Y: offset.Y,
			}
		}

		// Create DrawingPoint
		drawingPoint := models.DrawingPoint{
			ID:      int(req.Data.ID),
			Type:    "drawing",
			Offsets: offsets,
			Color:   req.Data.Color,
			Width:   req.Data.Width,
			Tool:    req.Data.Tool,
		}
		drawingPoints = append(drawingPoints, drawingPoint)
	}

	// Replace drawing points instead of appending
	paperCollection := config.GetPaperCollection()
	var paper models.Paper
	filter := bson.M{"_id": paperObjID}
	err = paperCollection.FindOne(context.Background(), filter).Decode(&paper)

	// If paper not found, return an error
	if err != nil {
		http.Error(w, "Paper not found", http.StatusNotFound)
		return
	}

	// Update the paper's drawing data and timestamp
	update := bson.M{
		"$set": bson.M{
			"drawing_data": drawingPoints,
			"updated_at":   time.Now(),
		},
	}

	_, err = paperCollection.UpdateOne(context.Background(), filter, update)
	if err != nil {
		http.Error(w, "Failed to update paper", http.StatusInternalServerError)
		return
	}

	// Broadcast to socket if needed
	socketServer := socketio.ServerInstance
	if socketServer != nil {
		var papers []models.Paper
		cursor, _ := paperCollection.Find(context.Background(), bson.M{"room_id": paper.RoomID})
		cursor.All(context.Background(), &papers)

		socketServer.BroadcastToRoom("", paper.RoomID, "paper_list_updated", map[string]interface{}{
			"roomID": paper.RoomID,
			"papers": papers,
		})
	}

	// Send success response
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"message":   "Drawing data replaced successfully",
		"paper_id":  paperID,
		"room_id":   paper.RoomID,
		"file_id":   paper.FileID,
		"timestamp": time.Now().Format(time.RFC3339),
	})
}

func DeletePaper(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Error reading request body", http.StatusBadRequest)
		return
	}

	var paperRequest struct {
		PaperID string `json:"paper_id"`
		// RoomID   string `json:"room_id"`
	}
	if err := json.Unmarshal(body, &paperRequest); err != nil {
		http.Error(w, "Invalid request format", http.StatusBadRequest)
		return
	}

	objID, err := primitive.ObjectIDFromHex(paperRequest.PaperID)
	if err != nil {
		http.Error(w, "Invalid Paper ID format", http.StatusBadRequest)
		return
	}

	result, err := config.GetPaperCollection().DeleteOne(context.Background(), bson.M{"_id": objID})
	if err != nil {
		http.Error(w, "Failed to delete paper", http.StatusInternalServerError)
		return
	}

	if result.DeletedCount == 0 {
		http.Error(w, "Paper not found", http.StatusNotFound)
		return
	}
}

func GetPaper(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	roomID := r.URL.Query().Get("room_id")
	if roomID == "" {
		http.Error(w, "Missing file_id parameter", http.StatusBadRequest)
		return
	}

	// Query database for folders
	paperCollection := config.GetPaperCollection()
	filter := bson.M{"room_id": roomID}

	cursor, err := paperCollection.Find(context.Background(), filter)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to fetch papers: %v", err), http.StatusInternalServerError)
		return
	}
	defer cursor.Close(context.Background())

	// Decode results into slice
	var papers []models.Paper
	if err = cursor.All(context.Background(), &papers); err != nil {
		http.Error(w, fmt.Sprintf("Failed to decode papers: %v", err), http.StatusInternalServerError)
		return
	}

	// Broadcast to socket if needed
	socketServer := socketio.ServerInstance
	socketServer.BroadcastToRoom("", roomID, "paper_list_updated", papers)

	// Encode and return folders
	json.NewEncoder(w).Encode(papers)
}

func GetPaperByFileID(w http.ResponseWriter, r *http.Request) {
	// Set CORS headers
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Content-Type", "application/json")

	fileID := r.URL.Query().Get("file_id")
	if fileID == "" {
		http.Error(w, "Missing file_id parameter", http.StatusBadRequest)
		return
	}

	// Query database for folders
	fileCollection := config.GetFileCollection()
	filter := bson.M{"file_id": fileID}

	cursor, err := fileCollection.Find(context.Background(), filter)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to fetch papers: %v", err), http.StatusInternalServerError)
		return
	}
	defer cursor.Close(context.Background())

	// Decode results into slice
	var papers []models.Folder
	if err = cursor.All(context.Background(), &papers); err != nil {
		http.Error(w, fmt.Sprintf("Failed to decode papers: %v", err), http.StatusInternalServerError)
		return
	}

	// Broadcast to socket if needed
	socketServer := socketio.ServerInstance
	socketServer.BroadcastToRoom("", fileID, "paper_list_updated", papers)

	// Encode and return folders
	json.NewEncoder(w).Encode(papers)
}
