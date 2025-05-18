package main

import (
	"log"
	"net/http"

	"backend/config"
	"backend/handlers"
	"backend/middleware"
	"backend/socketio"

	"github.com/gorilla/mux"
	"github.com/grandcat/zeroconf"
)

func main() {

	server, err := zeroconf.Register(
		"my-backend", // service instance name
		"_http._tcp", // service type and protocol
		"local.",     // service domain
		8080,         // service port
		[]string{"txtv=1", "app=flutter-backend"}, // optional txt records
		nil, // use default interface
	)
	if err != nil {
		log.Fatal("mDNS register failed:", err)
	}

	log.Println("Successfully registered mDNS service:", server)
	log.Println("Service name: my-backend._http._tcp.local")
	log.Println("Service port: 8080")
	defer server.Shutdown()

	log.Println("Registered mDNS service: my-backend._http._tcp.local")

	// Initialize database
	config.ConnectDB()

	// Set up the router
	router := mux.NewRouter()
	router.Use(middleware.CorsMiddleware)

	// Define REST API routes
	router.HandleFunc("/api/user/login", handlers.UserLogin).Methods("POST")
	router.HandleFunc("/api/user/google-login", handlers.GoogleLogin).Methods("POST")
	router.HandleFunc("/api/user/signup", handlers.UserSignup).Methods("POST")
	router.HandleFunc("/api/user/logout", handlers.UserLogout).Methods("POST")
	router.HandleFunc("/api/room", handlers.AddRoom).Methods("POST")
	router.HandleFunc("/api/room/name", handlers.RenameRoom).Methods("PUT")
	router.HandleFunc("/api/room", handlers.GetRooms).Methods("GET")
	router.HandleFunc("/api/room", handlers.ToggleFavoriteRoom).Methods("PUT")
	router.HandleFunc("/api/room/id", handlers.GetSharedRoomID).Methods("GET")
	router.HandleFunc("/api/room", handlers.DeleteRoom).Methods("DELETE")
	router.HandleFunc("/api/folder", handlers.AddFolder).Methods("POST")
	router.HandleFunc("/api/folder", handlers.GetFolder).Methods("GET")
	router.HandleFunc("/api/folder/name", handlers.RenameFolder).Methods("PUT")
	router.HandleFunc("/api/folder", handlers.DeleteFolder).Methods("DELETE")
	router.HandleFunc("/api/file", handlers.AddFile).Methods("POST")
	router.HandleFunc("/api/file", handlers.GetFile).Methods("GET")
	router.HandleFunc("/api/file/name", handlers.RenameFile).Methods("PUT")
	router.HandleFunc("/api/file/id", handlers.GetFileIDByOriginalID).Methods("GET")
	router.HandleFunc("/api/file", handlers.DeleteFile).Methods("DELETE")
	router.HandleFunc("/api/paper", handlers.AddPaper).Methods("POST")
	router.HandleFunc("/api/paper/insert", handlers.InsertPaperAt).Methods("POST") // addmore
	router.HandleFunc("/api/paper", handlers.GetPaper).Methods("GET")
	router.HandleFunc("/api/paper", handlers.DeletePaper).Methods("DELETE")
	router.HandleFunc("/api/paper/drawing", handlers.AddDrawingPoint).Methods("PUT")
	router.HandleFunc("/api/paper/text", handlers.AddTextAnnotation).Methods("PUT")
	router.HandleFunc("/api/paper/swap", handlers.SwapPaper).Methods("PUT") // addmore

	router.HandleFunc("/api/paper/import", handlers.UploadHandler).Methods("POST")

	// router.HandleFunc("/api/paper", handlers.AddDrawing).Methods("PUT")
	router.HandleFunc("/api/shared", handlers.ShareFile).Methods("POST")
	router.HandleFunc("/api/shared", handlers.GetSharedFiles).Methods("GET")
	router.HandleFunc("/api/shared/{id}/clone", handlers.CloneSharedFile).Methods("GET")
	router.HandleFunc("/api/roomMember", handlers.RoomMember).Methods("POST")
	router.HandleFunc("/api/roomMember", handlers.ChangeRoomMemberRole).Methods("PUT")
	router.HandleFunc("/api/roomMember", handlers.GetRoomMembersInRoom).Methods("GET")
	router.HandleFunc("/api/roomMember", handlers.RemoveRoomMember).Methods("DELETE")

	router.HandleFunc("/api/auth/refresh", handlers.RefreshToken).Methods("POST")

	socketServer := socketio.SetupSocketIO(router)

	// Explicitly handle socket.io routes
	router.Handle("/socket.io/", socketServer)

	// Start the HTTP server with the router
	log.Printf("Server starting on port 8080...")
	log.Fatal(http.ListenAndServe("0.0.0.0:8080", router))
}
