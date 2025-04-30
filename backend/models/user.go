package models

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

type User struct {
	ID        primitive.ObjectID `bson:"_id,omitempty" json:"id"`
	Email     string             `json:"email" bson:"email"`
	Password  string             `json:"password" bson:"password"`
	Name      string             `json:"name" bson:"name"`
	CreatedAt time.Time          `bson:"created_at" json:"created_at"`
	LastLogin time.Time          `bson:"last_login" json:"last_login"`
}
