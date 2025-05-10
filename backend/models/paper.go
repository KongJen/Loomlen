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
	TemplateID      string           `bson:"template_id" json:"template_id"`
	PageNumber      int              `bson:"page_number" json:"page_number"`
	Width           float64          `bson:"width" json:"width"`
	Height          float64          `bson:"height" json:"height"`
	DrawingData     []DrawingPoint   `json:"drawing_data" bson:"drawing_data"`
	TextData        []TextAnnotation `json:"text_data" bson:"text_data"`
	BackgroundImage string           `json:"background_image" bson:"background_image"`
	CreatedAt       time.Time        `bson:"created_at" json:"created_at"`
	UpdatedAt       time.Time        `bson:"updated_at" json:"updated_at"`
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

type TextAnnotation struct {
	ID       int     `json:"id" bson:"id"`
	Type     string  `json:"type" bson:"type"`
	Text     string  `json:"text" bson:"text"`
	Position Offset  `json:"position" bson:"position"`
	Color    int     `json:"color" bson:"color"`
	FontSize float64 `json:"fontSize" bson:"fontSize"`
	IsBold   bool    `json:"isBold" bson:"isBold"`
	IsItalic bool    `json:"isItalic" bson:"isItalic"`
	IsBubble bool    `json:"isBubble" bson:"isBubble"`
}
