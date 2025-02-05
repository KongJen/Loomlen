package handlers

import (
	"context"
	"encoding/json"
	"net/http"
	"time"

	"backend/config"
	"backend/models"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo/options"
)

func CreateNote(w http.ResponseWriter, r *http.Request) {
	var note models.DrawingNote
	if err := json.NewDecoder(r.Body).Decode(&note); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	note.FileID = uuid.New().String()
	note.CreatedAt = time.Now()
	note.UpdatedAt = time.Now()

	collection := config.GetFileCollection()
	_, err := collection.InsertOne(context.Background(), note)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(note)
}

func GetNotes(w http.ResponseWriter, r *http.Request) {
	var notes []models.DrawingNote
	collection := config.GetFileCollection()

	cursor, err := collection.Find(context.Background(), bson.M{})
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer cursor.Close(context.Background())

	if err = cursor.All(context.Background(), &notes); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(notes)
}

func GetNote(w http.ResponseWriter, r *http.Request) {
	params := mux.Vars(r)
	fileId := params["fileId"]

	var note models.DrawingNote
	collection := config.GetFileCollection()

	err := collection.FindOne(context.Background(), bson.M{"file_id": fileId}).Decode(&note)
	if err != nil {
		http.Error(w, "Note not found", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(note)
}

func UpdateNote(w http.ResponseWriter, r *http.Request) {
	params := mux.Vars(r)
	fileId := params["fileId"]

	var note models.DrawingNote
	if err := json.NewDecoder(r.Body).Decode(&note); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	note.UpdatedAt = time.Now()
	collection := config.GetFileCollection()

	update := bson.M{
		"$set": bson.M{
			"name":        note.Name,
			"stroke_data": note.StrokeData,
			"image_data":  note.ImageData,
			"updated_at":  note.UpdatedAt,
		},
	}

	result := collection.FindOneAndUpdate(
		context.Background(),
		bson.M{"file_id": fileId},
		update,
		options.FindOneAndUpdate().SetReturnDocument(options.After),
	)

	if result.Err() != nil {
		http.Error(w, "Note not found", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	if err := result.Decode(&note); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	json.NewEncoder(w).Encode(note)
}

func DeleteNote(w http.ResponseWriter, r *http.Request) {
	params := mux.Vars(r)
	fileId := params["fileId"]

	collection := config.GetFileCollection()
	result, err := collection.DeleteOne(context.Background(), bson.M{"file_id": fileId})
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	if result.DeletedCount == 0 {
		http.Error(w, "Note not found", http.StatusNotFound)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
