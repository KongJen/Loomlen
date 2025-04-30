package models

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

type RoomMembers struct {
	ID         primitive.ObjectID `bson:"_id,omitempty" json:"id"`
	InviterID  string             `bson:"inviter_id" json:"inviter_id"`
	RoomID     string             `bson:"room_id" json:"room_id"`
	SharedWith string             `bson:"shared_with" json:"shared_with"`
	RoleID     string             `bson:"role_id" json:"role_id"`
	JoinAt     time.Time          `bson:"join_at" json:"join_at"`
}
