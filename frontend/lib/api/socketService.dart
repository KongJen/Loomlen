import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:frontend/global.dart';

class SocketService {
  IO.Socket? socket;
  final String baseUrl = baseurl;

  void initializeSocket(
    String roomID,
    Function(bool success, String error) onRoomJoined,
  ) {
    print("🌐 Initializing socket connection to: $baseUrl");
    // Detailed socket configuration
    socket = IO.io(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'forceNew': true,
      'reconnection': true,
      'reconnectionAttempts': 5,
      'reconnectionDelay': 1000,
      'timeout': 5000,
    });

    // Comprehensive event logging
    socket?.onConnect((_) {
      print('Connected! Socket ID: ${socket?.id}');
      socket?.emit('join_room', {'roomID': roomID, 'socketID': socket?.id});
    });

    socket?.onConnectError((error) {
      print('Connection Error: $error');
      onRoomJoined(false, 'Connection failed: $error');
    });

    socket?.onDisconnect((_) {
      print('Disconnected from server.');
    });

    socket?.on('error', (error) {
      print('Socket Error: $error');
    });

    try {
      socket?.connect();
      print("Attempting to connect...");
    } catch (e) {
      print('Connection Attempt Failed: $e');
      onRoomJoined(false, 'Failed to connect');
    }
  }

  void closeSocket() {
    socket?.disconnect();
    socket?.dispose();
  }
}
