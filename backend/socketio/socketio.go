package socketio

import (
	// "backend/utils"
	"fmt"
	"log"
	"net/http"

	socketio "github.com/googollee/go-socket.io"
	"github.com/googollee/go-socket.io/engineio"
	"github.com/googollee/go-socket.io/engineio/transport"
	"github.com/googollee/go-socket.io/engineio/transport/polling"
	"github.com/googollee/go-socket.io/engineio/transport/websocket"
	"github.com/gorilla/mux"
)

func allowOriginFunc(r *http.Request) bool {
	return true
}

// ServerInstance holds the reference to the socket.io server
var ServerInstance *socketio.Server

// SetupSocketIO initializes the Socket.IO server and registers event handlers
func SetupSocketIO(router *mux.Router) *socketio.Server {
	fmt.Println("Socket")
	server := socketio.NewServer(&engineio.Options{
		Transports: []transport.Transport{
			&polling.Transport{
				CheckOrigin: allowOriginFunc,
			},
			&websocket.Transport{
				CheckOrigin: allowOriginFunc,
			},
		},
	})

	server.OnConnect("/", func(s socketio.Conn) error {
		s.SetContext("")
		fmt.Println("connected:", s.ID())
		return nil
	})

	server.OnEvent("/", "notice", func(s socketio.Conn, msg string) {
		fmt.Println("notice:", msg)
		s.Emit("reply", "have "+msg)
	})

	server.OnEvent("/", "join_room", func(s socketio.Conn, data map[string]interface{}) {
		roomID, ok := data["roomID"].(string)
		if !ok || roomID == "" {
			fmt.Println("Invalid roomID in join_room")
			s.Emit("room_joined", map[string]interface{}{
				"success": false,
				"error":   "Invalid room ID",
			})
			return
		}

		token, tokenOk := data["token"].(string)
		if !tokenOk || token == "" {
			fmt.Println("❌ Missing or invalid token in join_room")
			s.Emit("room_joined", map[string]interface{}{
				"success": false,
				"error":   "Missing or invalid token",
			})
			return
		}

		// userID, err := utils.GetUserIDFromTokenSocket(token)
		// if err != nil {
		// 	fmt.Println("❌ Unauthorized: Invalid token")
		// 	s.Emit("room_joined", map[string]interface{}{
		// 		"success": false,
		// 		"error":   "Unauthorized: Invalid token",
		// 	})
		// 	return
		// }

		// s.SetContext(userID)

		fmt.Printf("✅ User %s  joined room %s\n", s.ID(), roomID)
		s.Join(roomID)

		s.Emit("room_joined", map[string]interface{}{
			"success": true,
			"roomID":  roomID,
			// "userID":   userID,
			"clientID": s.ID(),
		})
	})

	server.OnEvent("/", "join_file", func(s socketio.Conn, msg map[string]string) {
		fileId := msg["fileId"]
		userId := s.ID()

		server.JoinRoom("/", fileId, s)
		AddUserToFile(fileId, userId)

		users := GetUsersInFile(fileId)
		fmt.Printf("User %s joined file %s\n", userId, fileId)
		server.BroadcastToRoom("/", fileId, "file_users_update", map[string]interface{}{
			"users": users,
		})
	})

	server.OnEvent("/", "leave_file", func(s socketio.Conn, msg map[string]string) {
		fileId := msg["fileId"]
		userId := s.ID()

		server.LeaveRoom("/", fileId, s)
		RemoveUserFromFile(fileId, userId)

		users := GetUsersInFile(fileId)
		server.BroadcastToRoom("/", fileId, "file_users_update", map[string]interface{}{
			"users": users,
		})
	})

	server.OnEvent("/", "request_canvas_state", func(s socketio.Conn, data map[string]interface{}) {
		fmt.Println("📥 Canvas state requested")

		roomID, ok := data["roomId"].(string)
		if !ok || roomID == "" {
			fmt.Println("⚠️ Invalid or missing roomId in request_canvas_state event")
			return
		}

		pageID, pageOk := data["pageId"].(string)
		if !pageOk || pageID == "" {
			fmt.Println("⚠️ Invalid or missing pageId in request_canvas_state event")
			return
		}

		// Add the requesting client's ID to the data
		data["clientId"] = s.ID()

		// Broadcast the request to all clients in the room
		server.BroadcastToRoom("", roomID, "request_canvas_state", data)
		fmt.Printf("📤 Broadcasted canvas state request for page %s to room %s\n", pageID, roomID)
	})

	server.OnEvent("/", "canvas_state", func(s socketio.Conn, data map[string]interface{}) {
		roomID, ok := data["roomId"].(string)
		if !ok || roomID == "" {
			fmt.Println("⚠️ Invalid or missing roomId in canvas_state event")
			return
		}

		// Broadcast the canvas state to all users in the room
		server.BroadcastToRoom("", roomID, "canvas_state", data)
		fmt.Println("📤 Broadcasted canvas state to room:", roomID)
	})

	server.OnEvent("/", "undo", func(s socketio.Conn, data map[string]interface{}) {
		roomID, ok := data["roomId"].(string)
		if !ok || roomID == "" {
			fmt.Println("⚠️ Invalid or missing roomId in undo event")
			return
		}

		fmt.Printf("🔄 Undo requested by %s in room %s\n", s.ID(), roomID)

		// Broadcast undo to other clients
		server.BroadcastToRoom("/", roomID, "undo", data)
	})

	server.OnEvent("/", "redo", func(s socketio.Conn, data map[string]interface{}) {
		roomID, ok := data["roomId"].(string)
		if !ok || roomID == "" {
			fmt.Println("⚠️ Invalid or missing roomId in redo event")
			return
		}

		fmt.Printf("🔄 Redo requested by %s in room %s\n", s.ID(), roomID)

		// Broadcast redo to other clients
		server.BroadcastToRoom("/", roomID, "redo", data)
	})

	server.OnEvent("/", "drawing", func(s socketio.Conn, data map[string]interface{}) {

		// Check if the roomId exists and is a string
		roomID, ok := data["roomId"].(string)
		if !ok || roomID == "" {
			fmt.Println("Invalid or missing roomId in drawing event")
			return
		}

		// Check if pageId is also received (for verification)
		pageID, pageOk := data["pageId"].(string)
		if pageOk {
			fmt.Printf("Received pageId: %s\n", pageID)
			fmt.Printf("ReceivedDrawing data: %v\n", data)
		}

		// Broadcast the drawing data to all users in the room
		server.BroadcastToRoom("", roomID, "drawing", data)
	})

	server.OnEvent("/", "text", func(s socketio.Conn, data map[string]interface{}) {

		// Check if the roomId exists and is a string
		roomID, ok := data["roomId"].(string)
		if !ok || roomID == "" {
			fmt.Println("Invalid or missing roomId in drawing event")
			return
		}

		// Check if pageId is also received (for verification)
		pageID, pageOk := data["pageId"].(string)
		if pageOk {
			fmt.Printf("Received pageId: %s\n", pageID)
			fmt.Printf("Received text data: %v\n", data)
		}

		// Broadcast the drawing data to all users in the room
		server.BroadcastToRoom("", roomID, "text", data)
	})

	server.OnEvent("/", "updatetext", func(s socketio.Conn, data map[string]interface{}) {

		// Check if the roomId exists and is a string
		roomID, ok := data["roomId"].(string)
		if !ok || roomID == "" {
			fmt.Println("Invalid or missing roomId in drawing event")
			return
		}

		// Check if pageId is also received (for verification)
		pageID, pageOk := data["pageId"].(string)
		if pageOk {
			fmt.Printf("Received pageId: %s\n", pageID)
			fmt.Printf("Received updatetext data: %v\n", data)
		}

		// Broadcast the drawing data to all users in the room
		server.BroadcastToRoom("", roomID, "updatetext", data)
	})

	server.OnEvent("/", "deletetext", func(s socketio.Conn, data map[string]interface{}) {

		// Check if the roomId exists and is a string
		roomID, ok := data["roomId"].(string)
		if !ok || roomID == "" {
			fmt.Println("Invalid or missing roomId in drawing event")
			return
		}

		// Check if pageId is also received (for verification)
		pageID, pageOk := data["pageId"].(string)
		if pageOk {
			fmt.Printf("Received pageId: %s\n", pageID)
			fmt.Printf("Received deletetext: %v\n", data)
		}

		// Broadcast the drawing data to all users in the room
		server.BroadcastToRoom("", roomID, "deletetext", data)
	})

	server.OnEvent("/", "eraser", func(s socketio.Conn, data map[string]interface{}) {
		fmt.Println("📥 Received eraser event data: ", data)

		// Check if the roomId exists and is a string
		roomID, ok := data["roomId"].(string)
		if !ok || roomID == "" {
			fmt.Println("⚠️ Invalid or missing roomId in eraser event")
			return
		}

		// Check if pageId is also received
		pageID, pageOk := data["pageId"].(string)
		if pageOk {
			fmt.Printf("✅ Received pageId for eraser: %s\n", pageID)
		}

		// Check if eraserAction is received
		eraserAction, eraserOk := data["eraserAction"].(map[string]interface{})
		if !eraserOk {
			fmt.Println("⚠️ Invalid or missing eraserAction in eraser event")
			return
		}

		// Get the eraser type (point or stroke)
		eraserType, typeOk := eraserAction["type"].(string)
		if !typeOk {
			fmt.Println("⚠️ Missing eraser type in eraserAction")
			return
		}

		fmt.Printf("🧹 Broadcasting eraser action of type: %s\n", eraserType)

		// Broadcast the eraser data to all users in the room except the sender
		server.BroadcastToRoom("", roomID, "eraser", data)
	})

	server.OnEvent("/", "room_members_updated", func(s socketio.Conn, data map[string]interface{}) {
		roomID, ok := data["roomID"].(string)
		if !ok {
			fmt.Println("Invalid roomID in room_members_updated")
			return
		}

		// Broadcast the updated member roles to all users in the room
		server.BroadcastToRoom("", roomID, "room_members_updated", data)
	})

	server.OnEvent("/", "folder_list_updated", func(s socketio.Conn, data map[string]interface{}) {
		log.Println("folder_list_updated event received:", data)
		roomID, ok := data["roomID"].(string)
		if !ok {
			fmt.Println("Invalid roomID in folder_list_updated")
			return
		}

		// Broadcast the updated folder list to all users in the room
		server.BroadcastToRoom("", roomID, "folder_list_updated", data["folders"])
	})

	server.OnEvent("/", "file_list_updated", func(s socketio.Conn, data map[string]interface{}) {
		roomID, ok := data["roomID"].(string)
		if !ok {
			fmt.Println("Invalid roomID in file_list_updated")
			return
		}
		// Broadcast the updated folder list to all users in the room
		server.BroadcastToRoom("", roomID, "file_list_updated", data["files"])
	})

	server.OnEvent("/", "paper_list_updated", func(s socketio.Conn, data map[string]interface{}) {
		roomID, ok := data["roomID"].(string)
		if !ok {
			fmt.Println("Invalid roomID in paper_list_updated")
			return
		}
		// Broadcast the updated folder list to all users in the room
		server.BroadcastToRoom("", roomID, "paper_list_updated", data["papers"])
	})

	server.OnError("/", func(s socketio.Conn, e error) {
		fmt.Println("error:", e)
	})

	server.OnDisconnect("/", func(s socketio.Conn, reason string) {
		userID := s.ID() // Get user ID from connection context
		fmt.Println("closed", reason, "UserID:", userID)

		// Iterate over the files the user is in and remove them
		for fileID := range fileUsers {
			if fileUsers[fileID][userID] {
				RemoveUserFromFile(fileID, userID)
				server.BroadcastToRoom("/", fileID, "file_users_update", map[string]interface{}{
					"users": GetUsersInFile(fileID),
				})
			}
		}
	})

	// Run the server in a goroutine
	go func() {
		if err := server.Serve(); err != nil {
			log.Fatalf("Socket.IO serve error: %v", err)
		}
	}()

	// Store the server instance globally (if needed)
	ServerInstance = server

	return server
}

var fileUsers = make(map[string]map[string]bool)

func AddUserToFile(fileID, userID string) {
	if fileUsers[fileID] == nil {
		fileUsers[fileID] = make(map[string]bool)
	}
	fileUsers[fileID][userID] = true
}

func RemoveUserFromFile(fileID, userID string) {
	if users, ok := fileUsers[fileID]; ok {
		delete(users, userID)
		if len(users) == 0 {
			delete(fileUsers, fileID) // Clean up if empty
		}
	}
}

func GetUsersInFile(fileID string) []string {
	users := []string{}
	if userSet, ok := fileUsers[fileID]; ok {
		for userID := range userSet {
			users = append(users, userID)
		}
	}
	return users
}
