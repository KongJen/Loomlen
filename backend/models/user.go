package models

import (
	"time"
)

type User struct {
	Email     string    `json:"email" bson:"email"`
	Password  string    `json:"password" bson:"password"`
	Name      string    `json:"name" bson:"name"`
	CreatedAt time.Time `bson:"created_at" json:"created_at"`
	LastLogin time.Time `bson:"last_login" json:"last_login"`
}
