package models

import (
	"time"
)

type DrawingNote struct {
	FileID     string    `bson:"file_id" json:"file_id"`
	Name       string    `bson:"name" json:"name"`
	StrokeData []Stroke  `bson:"stroke_data" json:"stroke_data"`
	ImageData  string    `bson:"image_data,omitempty" json:"image_data,omitempty"`
	CreatedAt  time.Time `bson:"created_at" json:"created_at"`
	UpdatedAt  time.Time `bson:"updated_at" json:"updated_at"`
}

type Stroke struct {
	Points []Point `bson:"points" json:"points"`
	Color  string  `bson:"color" json:"color"`
	Width  float64 `bson:"width" json:"width"`
	Tool   string  `bson:"tool" json:"tool"`
}

type Point struct {
	X        float64 `bson:"x" json:"x"`
	Y        float64 `bson:"y" json:"y"`
	Pressure float64 `bson:"pressure,omitempty" json:"pressure,omitempty"`
}
