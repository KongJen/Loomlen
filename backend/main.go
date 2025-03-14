package main

import (
	"log"
	"net/http"

	"backend/config"
	"backend/handlers"
	"backend/middleware"

	"github.com/gorilla/mux"
)

func main() {
	// Initialize database
	config.ConnectDB()

	// Set router
	router := mux.NewRouter()
	router.Use(middleware.CorsMiddleware)

	// Define routes
	router.HandleFunc("/api/notes", handlers.CreateNote).Methods("POST", "OPTIONS")
	router.HandleFunc("/api/notes", handlers.GetNotes).Methods("GET", "OPTIONS")
	router.HandleFunc("/api/notes/{fileId}", handlers.GetNote).Methods("GET", "OPTIONS")
	router.HandleFunc("/api/notes/{fileId}", handlers.UpdateNote).Methods("PUT", "OPTIONS")
	router.HandleFunc("/api/notes/{fileId}", handlers.DeleteNote).Methods("DELETE", "OPTIONS")
	router.HandleFunc("/api/user/login", handlers.UserLogin).Methods("POST")
	router.HandleFunc("/api/user/signup", handlers.UserSignup).Methods("POST")

	log.Printf("Server starting on port 8080...")
	log.Fatal(http.ListenAndServe(":8080", router))
}
