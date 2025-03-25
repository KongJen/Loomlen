package models

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

type Room struct {
	ID         primitive.ObjectID `bson:"_id,omitempty" json:"id"`
	OriginalID string             `bson:"original_id" json:"original_id"`
	OwnerID    string             `bson:"owner_id" json:"owner_id"`
	Name       string             `bson:"name" json:"name"`
	Color      int                `bson:"color" json:"color"`
	SharedWith []string           `bson:"sharedWith" json:"sharedWith"`
	Permission string             `bson:"permission" json:"permission"`
	//sharelink string
	//isshare bool
	CreatedAt time.Time `bson:"createdAt" json:"createdAt"`
	UpdatedAt time.Time `bson:"updatedAt" json:"updatedAt"`
}
