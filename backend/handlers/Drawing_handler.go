package handlers

import (
	"context"
	"encoding/json"
	"net/http"
	"time"

	"backend/config"
	"backend/models"
	"backend/socketio"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
)

func AddDrawing(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	// Parse request body
	var request struct {
		PaperID     string                `json:"paper_id"`
		DrawingData []models.DrawingPoint `json:"drawing_data"`
	}
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		http.Error(w, "Invalid request format", http.StatusBadRequest)
		return
	}

	// Get the MongoDB collection
	paperCollection := config.GetPaperCollection()

	// Find the paper document
	filter := bson.M{"original_id": request.PaperID}
	var paper models.Paper
	err := paperCollection.FindOne(context.Background(), filter).Decode(&paper)
	if err == mongo.ErrNoDocuments {
		http.Error(w, "Paper not found", http.StatusNotFound)
		return
	} else if err != nil {
		http.Error(w, "Error finding paper", http.StatusInternalServerError)
		return
	}

	// Append new drawing points
	paper.DrawingData = append(paper.DrawingData, request.DrawingData...)

	// Update the paper in MongoDB
	update := bson.M{
		"$set": bson.M{
			"drawing_data": paper.DrawingData,
			"updated_at":   time.Now(),
		},
	}
	_, err = paperCollection.UpdateOne(context.Background(), filter, update)
	if err != nil {
		http.Error(w, "Failed to update drawing data", http.StatusInternalServerError)
		return
	}

	// Broadcast updated drawing data to other users in the same room
	socketServer := socketio.ServerInstance
	if socketServer != nil {
		socketServer.BroadcastToRoom("", paper.RoomID, "drawing_updated", map[string]interface{}{
			"paper_id":     request.PaperID,
			"drawing_data": paper.DrawingData,
		})
	}

	// Send success response
	json.NewEncoder(w).Encode(map[string]string{
		"message": "Drawing data saved successfully",
	})
}

// Request payload structure
type UpdateDrawingRequest struct {
	PaperID     string         `json:"paper_id"`
	DrawingData []DrawingPoint `json:"drawing_data"`
}

// DrawingPoint structure (define this in your models)
type DrawingPoint struct {
	ID      int64 `json:"id"`
	Offsets []struct {
		X float64 `json:"x"`
		Y float64 `json:"y"`
	} `json:"offsets"`
	Color int     `json:"color"`
	Width float64 `json:"width"`
	Tool  string  `json:"tool"`
}

func UpdateDrawingData(w http.ResponseWriter, r *http.Request) {
	// Read the request body
	var req UpdateDrawingRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request format", http.StatusBadRequest)
		return
	}

	// Get paper collection
	paperCollection := config.GetPaperCollection()

	// Convert paperID to ObjectID
	filter := bson.M{"id": req.PaperID}

	// Check if the paper exists
	var paper bson.M
	err := paperCollection.FindOne(context.Background(), filter).Decode(&paper)
	if err == mongo.ErrNoDocuments {
		http.Error(w, "Paper not found", http.StatusNotFound)
		return
	} else if err != nil {
		http.Error(w, "Database error", http.StatusInternalServerError)
		return
	}

	// Update the paper drawing data
	update := bson.M{
		"$set": bson.M{
			"drawing_data": req.DrawingData,
			"updated_at":   time.Now(),
		},
	}

	_, err = paperCollection.UpdateOne(context.Background(), filter, update)
	if err != nil {
		http.Error(w, "Failed to update drawing data", http.StatusInternalServerError)
		return
	}

	// ✅ Success response
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"message": "Drawing data updated successfully",
	})
}
