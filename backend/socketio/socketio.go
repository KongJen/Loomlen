package socketio

import (
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
		if !ok {
			fmt.Println("Invalid roomID in join_room")
			s.Emit("room_joined", map[string]interface{}{
				"success": false,
				"error":   "Invalid room ID",
			})
			return
		}

		fmt.Printf("🏠 Client %s joined room %s\n", s.ID(), roomID)
		s.Join(roomID)

		s.Emit("room_joined", map[string]interface{}{
			"success":  true,
			"roomID":   roomID,
			"clientID": s.ID(),
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

	server.OnEvent("/", "drawing", func(s socketio.Conn, data map[string]interface{}) {
		fmt.Println("Full Received drawing event data: ", data)

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
		}

		// Broadcast the drawing data to all users in the room
		server.BroadcastToRoom("", roomID, "drawing", data)
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

	server.OnEvent("/", "folder_list_updated", func(s socketio.Conn, data map[string]interface{}) {
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
		fmt.Println("closed", reason)
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
