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

func AddPaper(w http.ResponseWriter, r *http.Request) {
	body, err := ioutil.ReadAll(r.Body)
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

// func AddDrawing(w http.ResponseWriter, r *http.Request) {
// 	body, err := io.ReadAll(r.Body)
// 	if err != nil {
// 		http.Error(w, "Error reading request body", http.StatusBadRequest)
// 		return
// 	}

// 	// Define a struct to match the incoming data structure
// 	var DrawingRequests []struct {
// 		Type string `json:"type"`
// 		Data struct {
// 			ID      int64 `json:"id"`
// 			Offsets []struct {
// 				X float64 `json:"x"`
// 				Y float64 `json:"y"`
// 			} `json:"offsets"`
// 			Color int     `json:"color"`
// 			Width float64 `json:"width"`
// 			Tool  string  `json:"tool"`
// 		} `json:"data"`
// 		Timestamp int64 `json:"timestamp"`
// 	}

// 	// Unmarshal the JSON data
// 	if err := json.Unmarshal(body, &DrawingRequests); err != nil {
// 		http.Error(w, "Invalid request format", http.StatusBadRequest)
// 		return
// 	}

// 	// Validate input
// 	if len(DrawingRequests) == 0 {
// 		http.Error(w, "No drawing data provided", http.StatusBadRequest)
// 		return
// 	}

// 	// Convert ID to string
// 	fileIDStr := strconv.FormatInt(DrawingRequests[0].Data.ID, 10)

// 	paperCollection := config.GetPaperCollection()

// 	// Try to find existing paper
// 	var paper models.Paper
// 	filter := bson.M{"file_id": fileIDStr}
// 	err = paperCollection.FindOne(context.Background(), filter).Decode(&paper)

// 	// If paper not found, return an error
// 	if err == mongo.ErrNoDocuments {
// 		http.Error(w, "Paper not found", http.StatusNotFound)
// 		return
// 	} else if err != nil {
// 		http.Error(w, "Error finding paper", http.StatusInternalServerError)
// 		return
// 	}

// 	// Convert the incoming data to DrawingPoints
// 	var drawingPoints []models.DrawingPoint
// 	for _, req := range DrawingRequests {
// 		if req.Type != "drawing" {
// 			continue // Skip non-drawing types
// 		}

// 		// Create offsets
// 		offsets := make([]models.Offset, len(req.Data.Offsets))
// 		for i, offset := range req.Data.Offsets {
// 			offsets[i] = models.Offset{
// 				X: offset.X,
// 				Y: offset.Y,
// 			}
// 		}

// 		// Create DrawingPoint
// 		drawingPoint := models.DrawingPoint{
// 			Offset: offsets,
// 			Color:  req.Data.Color,
// 			Width:  req.Data.Width,
// 			Tool:   req.Data.Tool,
// 		}
// 		drawingPoints = append(drawingPoints, drawingPoint)
// 	}

// 	// Append new drawing points
// 	paper.DrawingPoint = append(paper.DrawingPoint, drawingPoints...)
// 	paper.UpdatedAt = time.Now()

// 	// Update the paper in the database
// 	update := bson.M{
// 		"$set": bson.M{
// 			"DrawingPoint": paper.DrawingPoint,
// 			"updated_at":   paper.UpdatedAt,
// 		},
// 	}
// 	_, err = paperCollection.UpdateOne(context.Background(), filter, update)
// 	if err != nil {
// 		http.Error(w, "Failed to update paper", http.StatusInternalServerError)
// 		return
// 	}

// 	// Broadcast to socket if needed
// 	socketServer := socketio.ServerInstance
// 	if socketServer != nil {
// 		socketServer.BroadcastToRoom("", fileIDStr, "drawing_point_updated", paper)
// 	}

// 	// Send success response
// 	w.Header().Set("Content-Type", "application/json")
// 	json.NewEncoder(w).Encode(map[string]string{
// 		"message": "Drawing points added successfully",
// 	})
// }

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
