package models

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

type Folder struct {
	ID          primitive.ObjectID `bson:"_id,omitempty" json:"id"`
	OriginalID  string             `bson:"original_id" json:"original_id"`
	RoomID      string             `bson:"room_id" json:"room_id"`
	SubFolderID string             `bson:"sub_folder_id" json:"sub_folder_id"`
	Name        string             `bson:"name" json:"name"`
	Color       int                `bson:"color" json:"color"`
	CreatedAt   time.Time          `bson:"createdAt" json:"createdAt"`
	UpdatedAt   time.Time          `bson:"updatedAt" json:"updatedAt"`
}
