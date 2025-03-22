package models

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

type RoomMembers struct {
	ID     primitive.ObjectID `bson:"_id,omitempty" json:"id"`
	RoomID string             `bson:"room_id" json:"room_id"`
	UserID string             `bson:"user_id" json:"user_id"`
	RoleID string             `bson:"role_id" json:"role_id"`
	JoinAt time.Time          `bson:"join_at" json:"join_at"`
}
