package models

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

type Paper struct {
	ID         primitive.ObjectID `bson:"_id,omitempty" json:"id"`
	OriginalID string             `bson:"original_id" json:"original_id"`
	RoomID     string             `bson:"room_id" json:"room_id"`
	FileID     string             `bson:"file_id" json:"file_id"`
	//pdfpath
	TemplateID  string         `bson:"template_id" json:"template_id"`
	PageNumber  int            `bson:"page_number" json:"page_number"`
	Width       float64        `bson:"width" json:"width"`
	Height      float64        `bson:"height" json:"height"`
	DrawingData []DrawingPoint `json:"drawing_data" bson:"drawing_data"`
	CreatedAt   time.Time      `bson:"created_at" json:"created_at"`
	UpdatedAt   time.Time      `bson:"updated_at" json:"updated_at"`
}

type Offset struct {
	X float64 `json:"x" bson:"x"`
	Y float64 `json:"y" bson:"y"`
}

type DrawingPoint struct {
	ID      int      `json:"id" bson:"id"`
	Type    string   `json:"type" bson:"type"`
	Offsets []Offset `json:"offsets" bson:"offsets"`
	Color   int      `json:"color" bson:"color"`
	Width   float64  `json:"width" bson:"width"`
	Tool    string   `json:"tool" bson:"tool"`
}
