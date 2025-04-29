package config

import (
	"context"
	"log"
	"os"
	"time"

	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

var (
	client                 *mongo.Client
	fileCollection         *mongo.Collection
	userCollection         *mongo.Collection
	favoriteCollection     *mongo.Collection
	roomCollection         *mongo.Collection
	folderCollection       *mongo.Collection
	paperCollection        *mongo.Collection
	sharedCollection       *mongo.Collection
	backlistCollection     *mongo.Collection
	roomMemberCollection   *mongo.Collection
	RefreshTokenCollection *mongo.Collection
)

func ConnectDB() {

	mongoURI := os.Getenv("MONGODB_URI")
	if mongoURI == "" {
		log.Fatal("MONGODB_URI environment variable is not set")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	clientOptions := options.Client().ApplyURI(mongoURI)
	var err error
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
	favoriteCollection = db.Collection("Favorites")
	folderCollection = db.Collection("Folders")
	fileCollection = db.Collection("Files")
	paperCollection = db.Collection("Papers")
	sharedCollection = db.Collection("SharedFiles")
	backlistCollection = db.Collection("Backlist")
	roomMemberCollection = db.Collection("Room_Member")
	RefreshTokenCollection = db.Collection("RefreshToken")
}

func GetFileCollection() *mongo.Collection {
	return fileCollection
}

func GetUserCollection() *mongo.Collection {
	return userCollection
}

func GetFavoriteCollection() *mongo.Collection {
	return favoriteCollection
}

func GetRoomCollection() *mongo.Collection {
	return roomCollection
}

func GetFolderCollection() *mongo.Collection {
	return folderCollection
}

func GetPaperCollection() *mongo.Collection {
	return paperCollection
}

func GetSharedCollection() *mongo.Collection {
	return sharedCollection
}

func GetBlacklistCollection() *mongo.Collection {
	return backlistCollection
}

func GetRoomMemberCollection() *mongo.Collection {
	return roomMemberCollection
}

func GetRefreshTokenCollection() *mongo.Collection {
	return RefreshTokenCollection
}
