package main

import (
	"log"
	"net/http"

	"backend/config"
	"backend/handlers"
	"backend/middleware"
	"backend/socketio"

	"github.com/gorilla/mux"
)

func main() {
	// Initialize database
	config.ConnectDB()

	// Set up the router
	router := mux.NewRouter()
	router.Use(middleware.CorsMiddleware)

	// Define REST API routes
	router.HandleFunc("/api/user/login", handlers.UserLogin).Methods("POST")
	router.HandleFunc("/api/user/signup", handlers.UserSignup).Methods("POST")
	router.HandleFunc("/api/user/logout", handlers.UserLogout).Methods("POST")
	router.HandleFunc("/api/room", handlers.AddRoom).Methods("POST")
	router.HandleFunc("/api/room", handlers.GetRooms).Methods("GET")
	router.HandleFunc("/api/room", handlers.ToggleFavoriteRoom).Methods("PUT")
	router.HandleFunc("/api/folder", handlers.AddFolder).Methods("POST")
	router.HandleFunc("/api/folder", handlers.GetFolder).Methods("GET")
	router.HandleFunc("/api/file", handlers.AddFile).Methods("POST")
	router.HandleFunc("/api/file", handlers.GetFile).Methods("GET")
	router.HandleFunc("/api/file/id", handlers.GetFileIDByOriginalID).Methods("GET")
	router.HandleFunc("/api/paper", handlers.AddPaper).Methods("POST")
	router.HandleFunc("/api/paper", handlers.GetPaper).Methods("GET")
	router.HandleFunc("/api/paper/drawing", handlers.AddDrawingPoint).Methods("PUT")

	// router.HandleFunc("/api/paper", handlers.AddDrawing).Methods("PUT")
	router.HandleFunc("/api/shared", handlers.ShareFile).Methods("POST")
	router.HandleFunc("/api/shared", handlers.GetSharedFiles).Methods("GET")
	router.HandleFunc("/api/shared/{id}/clone", handlers.CloneSharedFile).Methods("GET")
	router.HandleFunc("/api/roomMember", handlers.RoomMember).Methods("POST")

	socketServer := socketio.SetupSocketIO(router)

	// Explicitly handle socket.io routes
	router.Handle("/socket.io/", socketServer)

	// Start the HTTP server with the router
	log.Printf("Server starting on port 8080...")
	log.Fatal(http.ListenAndServe(":8080", router))
}
