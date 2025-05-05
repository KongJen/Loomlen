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
	"go.mongodb.org/mongo-driver/mongo"
)

func AddPaper(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Error reading request body", http.StatusBadRequest)
		return
	}

	var paperRequest struct {
		PaperID         string  `json:"paper_id"`
		RoomID          string  `json:"room_id"`
		FileID          string  `json:"file_id"`
		TemplateID      string  `json:"template_id"`
		PageNumber      int     `json:"page_number"`
		Width           float64 `json:"width"`
		Height          float64 `json:"height"`
		BackgroundImage string  `json:"image"`
	}

	if err := json.Unmarshal(body, &paperRequest); err != nil {
		http.Error(w, "Invalid request format", http.StatusBadRequest)
		return

	}

	paper := models.Paper{
		ID:              primitive.NewObjectID(),
		OriginalID:      paperRequest.PaperID,
		RoomID:          paperRequest.RoomID,
		FileID:          paperRequest.FileID,
		TemplateID:      paperRequest.TemplateID,
		PageNumber:      paperRequest.PageNumber,
		Width:           paperRequest.Width,
		Height:          paperRequest.Height,
		BackgroundImage: paperRequest.BackgroundImage,
		CreatedAt:       time.Now(),
		UpdatedAt:       time.Now(),
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

// InsertPaperAt adds a new paper at a specific position and shifts other papers
func InsertPaperAt(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Error reading request body", http.StatusBadRequest)
		return
	}

	var insertRequest struct {
		PaperID         string  `json:"paper_id"`
		FileID          string  `json:"file_id"`
		RoomID          string  `json:"room_id"`
		InsertPosition  int     `json:"insert_position"` // Position to insert (0-based)
		TemplateID      string  `json:"template_id"`
		Width           float64 `json:"width"`
		Height          float64 `json:"height"`
		BackgroundImage string  `json:"image,omitempty"`
	}

	if err := json.Unmarshal(body, &insertRequest); err != nil {
		http.Error(w, "Invalid request format", http.StatusBadRequest)
		return
	}

	// Calculate the new page number (position + 1)
	newPageNumber := insertRequest.InsertPosition + 1

	// Create the new paper
	paper := models.Paper{
		ID:              primitive.NewObjectID(),
		OriginalID:      insertRequest.PaperID, // Generate a new unique ID
		RoomID:          insertRequest.RoomID,
		FileID:          insertRequest.FileID,
		TemplateID:      insertRequest.TemplateID,
		PageNumber:      newPageNumber,
		Width:           insertRequest.Width,
		Height:          insertRequest.Height,
		BackgroundImage: insertRequest.BackgroundImage,
		CreatedAt:       time.Now(),
		UpdatedAt:       time.Now(),
	}

	paperCollection := config.GetPaperCollection()

	// First, update existing papers' page numbers
	// Increment page number for all papers with page number >= newPageNumber
	filter := bson.M{
		"file_id":     insertRequest.FileID,
		"page_number": bson.M{"$gte": newPageNumber},
	}
	update := bson.M{
		"$inc": bson.M{"page_number": 1},
	}

	_, err = paperCollection.UpdateMany(context.Background(), filter, update)
	if err != nil {
		http.Error(w, "Failed to update existing papers", http.StatusInternalServerError)
		return
	}

	// Now insert the new paper
	_, err = paperCollection.InsertOne(context.Background(), paper)
	if err != nil {
		http.Error(w, "Failed to insert new paper", http.StatusInternalServerError)
		return
	}

	// Broadcast to all users in the room
	socketServer := socketio.ServerInstance
	if socketServer != nil {
		// Fetch updated paper list
		var papers []models.Paper
		cursor, _ := paperCollection.Find(context.Background(), bson.M{"room_id": insertRequest.RoomID})
		cursor.All(context.Background(), &papers)

		socketServer.BroadcastToRoom("", insertRequest.RoomID, "paper_list_updated", map[string]interface{}{
			"roomID": insertRequest.RoomID,
			"papers": papers,
		})
	}

	// Send success response
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"message":  "Paper inserted successfully",
		"paper_id": paper.ID.Hex(),
		"position": newPageNumber,
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
	}
	if err := json.Unmarshal(body, &paperRequest); err != nil {
		http.Error(w, "Invalid request format", http.StatusBadRequest)
		return
	}

	paperCollection := config.GetPaperCollection()

	// Convert paper ID to ObjectID
	objID, err := primitive.ObjectIDFromHex(paperRequest.PaperID)
	if err != nil {
		http.Error(w, "Invalid Paper ID format", http.StatusBadRequest)
		return
	}

	// First get the paper to be deleted
	var paperToDelete models.Paper
	err = paperCollection.FindOne(context.Background(), bson.M{"_id": objID}).Decode(&paperToDelete)
	if err != nil {
		http.Error(w, "Paper not found", http.StatusNotFound)
		return
	}

	// Store the file ID and page number before deletion
	fileID := paperToDelete.FileID
	roomID := paperToDelete.RoomID
	deletedPageNumber := paperToDelete.PageNumber

	// Delete the paper
	result, err := paperCollection.DeleteOne(context.Background(), bson.M{"_id": objID})
	if err != nil {
		http.Error(w, "Failed to delete paper", http.StatusInternalServerError)
		return
	}

	if result.DeletedCount == 0 {
		http.Error(w, "Paper not found", http.StatusNotFound)
		return
	}

	// Get all remaining papers with the same file ID to update their page numbers
	var remainingPapers []models.Paper
	cursor, err := paperCollection.Find(
		context.Background(),
		bson.M{"file_id": fileID},
	)
	if err != nil {
		// Even if this fails, we've already deleted the paper, so just log the error
		fmt.Printf("Error fetching remaining papers: %v\n", err)
	} else {
		defer cursor.Close(context.Background())
		if err = cursor.All(context.Background(), &remainingPapers); err == nil {
			// Create bulk write operations to update page numbers
			var bulkWrites []mongo.WriteModel

			// For each paper with page number > deleted page number, decrement its page number
			for _, paper := range remainingPapers {
				if paper.PageNumber > deletedPageNumber {
					bulkWrites = append(bulkWrites, mongo.NewUpdateOneModel().
						SetFilter(bson.M{"_id": paper.ID}).
						SetUpdate(bson.M{"$set": bson.M{"page_number": paper.PageNumber - 1}}))
				}
			}

			// Execute bulk write operations if there are any
			if len(bulkWrites) > 0 {
				_, bulkErr := paperCollection.BulkWrite(context.Background(), bulkWrites)
				if bulkErr != nil {
					fmt.Printf("Error updating page numbers: %v\n", bulkErr)
				}
			}
		}
	}

	// Broadcast updated paper list
	socketServer := socketio.ServerInstance
	if socketServer != nil {
		var updatedPapers []models.Paper
		cursor, _ := paperCollection.Find(context.Background(), bson.M{"file_id": fileID})
		cursor.All(context.Background(), &updatedPapers)

		socketServer.BroadcastToRoom("", roomID, "paper_list_updated", map[string]interface{}{
			"roomID": roomID,
			"papers": updatedPapers,
		})
	}

	// Send success response
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"message":  "Paper deleted successfully",
		"paper_id": paperRequest.PaperID,
	})
}

func SwapPaper(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Error reading request body", http.StatusBadRequest)
		return
	}

	var request struct {
		FileID    string `json:"file_id"`
		FromIndex int    `json:"from_index"`
		ToIndex   int    `json:"to_index"`
	}

	if err := json.Unmarshal(body, &request); err != nil {
		http.Error(w, "Invalid request format", http.StatusBadRequest)
		return
	}

	if request.FromIndex == request.ToIndex {
		// No change needed if indices are the same
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{
			"message": "No change needed as indices are the same",
		})
		return
	}

	paperCollection := config.GetPaperCollection()

	// Find all papers for this file and sort them by page number
	var filePapers []models.Paper
	cursor, err := paperCollection.Find(
		context.Background(),
		bson.M{"file_id": request.FileID},
	)
	if err != nil {
		http.Error(w, "Failed to fetch papers", http.StatusInternalServerError)
		return
	}
	defer cursor.Close(context.Background())

	if err = cursor.All(context.Background(), &filePapers); err != nil {
		http.Error(w, "Failed to decode papers", http.StatusInternalServerError)
		return
	}

	// Check if indices are valid
	if request.FromIndex < 0 || request.FromIndex >= len(filePapers)+1 ||
		request.ToIndex < 0 || request.ToIndex >= len(filePapers)+1 {
		http.Error(w, "Invalid index values", http.StatusBadRequest)
		return
	}

	// Create a map to easily find papers by page number
	papersByPageNumber := make(map[int]models.Paper)
	for _, paper := range filePapers {
		papersByPageNumber[paper.PageNumber] = paper
	}

	// Get the paper to move
	fromPaper, exists := papersByPageNumber[request.FromIndex]
	if !exists {
		http.Error(w, fmt.Sprintf("Paper with page number %d not found", request.FromIndex), http.StatusNotFound)
		return
	}

	// Create models for bulk write operations
	var bulkWrites []mongo.WriteModel

	// Handle moving papers based on direction (up or down)
	if request.FromIndex < request.ToIndex {
		// Moving down - adjust papers in between
		for pageNum := request.FromIndex + 1; pageNum <= request.ToIndex; pageNum++ {
			if paper, ok := papersByPageNumber[pageNum]; ok {
				bulkWrites = append(bulkWrites, mongo.NewUpdateOneModel().
					SetFilter(bson.M{"_id": paper.ID}).
					SetUpdate(bson.M{"$set": bson.M{"page_number": pageNum - 1}}))
			}
		}
	} else {
		// Moving up - adjust papers in between
		for pageNum := request.ToIndex; pageNum < request.FromIndex; pageNum++ {
			if paper, ok := papersByPageNumber[pageNum]; ok {
				bulkWrites = append(bulkWrites, mongo.NewUpdateOneModel().
					SetFilter(bson.M{"_id": paper.ID}).
					SetUpdate(bson.M{"$set": bson.M{"page_number": pageNum + 1}}))
			}
		}
	}

	// Move the paper to the target position
	bulkWrites = append(bulkWrites, mongo.NewUpdateOneModel().
		SetFilter(bson.M{"_id": fromPaper.ID}).
		SetUpdate(bson.M{"$set": bson.M{"page_number": request.ToIndex}}))

	// Execute bulk write operations
	if len(bulkWrites) > 0 {
		_, err = paperCollection.BulkWrite(context.Background(), bulkWrites)
		if err != nil {
			http.Error(w, fmt.Sprintf("Failed to update paper positions: %v", err), http.StatusInternalServerError)
			return
		}
	}

	// Broadcast updated paper list
	socketServer := socketio.ServerInstance
	if socketServer != nil {
		var updatedPapers []models.Paper
		cursor, _ := paperCollection.Find(context.Background(), bson.M{"file_id": request.FileID})
		cursor.All(context.Background(), &updatedPapers)

		if len(updatedPapers) > 0 {
			roomID := updatedPapers[0].RoomID
			socketServer.BroadcastToRoom("", roomID, "paper_list_updated", map[string]interface{}{
				"roomID": roomID,
				"papers": updatedPapers,
			})
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"message":    "Paper pages swapped successfully",
		"file_id":    request.FileID,
		"from_index": fmt.Sprintf("%d", request.FromIndex),
		"to_index":   fmt.Sprintf("%d", request.ToIndex),
	})
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
