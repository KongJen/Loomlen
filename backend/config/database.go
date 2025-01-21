package config

import (
	"context"
	"log"
	"time"

	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

var (
	client         *mongo.Client
	fileCollection *mongo.Collection
	userCollection *mongo.Collection
)

func ConnectDB() {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	clientOptions := options.Client().ApplyURI("mongodb://localhost:27017")
	var err error
	client, err = mongo.Connect(ctx, clientOptions)
	if err != nil {
		log.Fatal(err)
	}

	// Check the connection
	err = client.Ping(ctx, nil)
	if err != nil {
		log.Fatal(err)
	}

	db := client.Database("Roomlen")
	fileCollection = db.Collection("Files")
	userCollection = db.Collection("Users")
}

func GetFileCollection() *mongo.Collection {
	return fileCollection
}

func GetUserCollection() *mongo.Collection {
	return userCollection
}
