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

	server.OnEvent("/", "folder_list_updated", func(s socketio.Conn, data map[string]interface{}) {
		roomID, ok := data["roomID"].(string)
		if !ok {
			fmt.Println("Invalid roomID in folder_list_updated")
			return
		}

		// Broadcast the updated folder list to all users in the room
		server.BroadcastToRoom("", roomID, "folder_list_updated", data["folders"])
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
