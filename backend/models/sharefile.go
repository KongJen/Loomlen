// models/shared_file.go
package models

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

type SharedFile struct {
	ID          primitive.ObjectID `bson:"_id,omitempty" json:"id"`
	OriginalID  string             `bson:"originalId" json:"originalId"` // UUID from flutter
	OwnerID     string             `bson:"ownerId" json:"ownerId"`       // User ID of owner
	SharedWith  []string           `bson:"sharedWith" json:"sharedWith"` // List of user IDs
	Name        string             `bson:"name" json:"name"`
	FileContent []byte             `bson:"fileContent" json:"fileContent"` // Serialized file content
	PaperData   []byte             `bson:"paperData" json:"paperData"`     // Serialized paper data
	Permission  string             `bson:"permission" json:"permission"`   // "read" or "write"
	CreatedAt   time.Time          `bson:"createdAt" json:"createdAt"`
	UpdatedAt   time.Time          `bson:"updatedAt" json:"updatedAt"`
}
