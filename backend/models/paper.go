package models

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

type Paper struct {
	ID         primitive.ObjectID `bson:"_id,omitempty" json:"id"`
	OriginalID string             `bson:"original_id" json:"original_id"`
	FileID     string             `bson:"file_id" json:"file_id"`
	//pdfpath
	TemplateID string    `bson:"template_id" json:"template_id"`
	PageNumber int       `bson:"page_number" json:"page_number"`
	Width      float64   `bson:"width" json:"width"`
	Height     float64   `bson:"height" json:"height"`
	CreatedAt  time.Time `bson:"created_at" json:"created_at"`
	UpdatedAt  time.Time `bson:"updated_at" json:"updated_at"`
}

type Offset struct {
	X float64 `bson:"x" json:"x"`
	Y float64 `bson:"y" json:"y"`
}

type DrawingPoint struct {
	ID     primitive.ObjectID `bson:"_id,omitempty" json:"id"`
	Offset []Offset           `bson:"offset" json:"offset"`
	Color  int                `bson:"color" json:"color"`
	Width  float64            `bson:"width" json:"width"`
	Tool   string             `bson:"tool" json:"tool"`
}
