package config

import (
	"context"
	"log"
	"os"
	"time"

	"github.com/joho/godotenv"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

var (
	client           *mongo.Client
	fileCollection   *mongo.Collection
	userCollection   *mongo.Collection
	roomCollection   *mongo.Collection
	folderCollection *mongo.Collection
	sharedCollection *mongo.Collection
)

func ConnectDB() {

	err := godotenv.Load()
	if err != nil {
		log.Fatal("Error loading .env file")
	}

	mongoURI := os.Getenv("MONGODB_URI")
	if mongoURI == "" {
		log.Fatal("MONGODB_URI environment variable is not set")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	clientOptions := options.Client().ApplyURI(mongoURI)
	client, err = mongo.Connect(ctx, clientOptions)
	if err != nil {
		log.Fatal("MongoDB connection error:", err)
	}

	// Check the connection
	err = client.Ping(ctx, nil)
	if err != nil {
		log.Fatal(err)
	}

	db := client.Database("Roomlen")
	userCollection = db.Collection("Users")
	roomCollection = db.Collection("Rooms")
	folderCollection = db.Collection("Folders")
	fileCollection = db.Collection("Files")
	sharedCollection = db.Collection("SharedFiles")
}

func GetFileCollection() *mongo.Collection {
	return fileCollection
}

func GetUserCollection() *mongo.Collection {
	return userCollection
}

func GetRoomCollection() *mongo.Collection {
	return roomCollection
}

func GetFolderCollection() *mongo.Collection {
	return folderCollection
}

func GetSharedCollection() *mongo.Collection {
	return sharedCollection
}
