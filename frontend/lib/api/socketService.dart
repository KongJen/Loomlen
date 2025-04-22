import 'package:flutter/material.dart';
import 'package:frontend/providers/filedb_provider.dart';
import 'package:frontend/providers/folderdb_provider.dart';
import 'package:frontend/providers/paperdb_provider.dart';
import 'package:frontend/providers/roomdb_provider.dart';
import 'package:frontend/services/drawingDb_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:frontend/global.dart';

class SocketService {
  IO.Socket? socket;
  final String baseUrl = baseurl;
  BuildContext? _context;

  Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  void initializeSocket(
    String roomID,
    BuildContext context,
    Function(bool success, String error) onRoomJoined,
  ) {
    _context = context;
    print("🌐 Initializing socket connection to: $baseUrl");
    socket = IO.io(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'forceNew': true,
      'reconnection': true,
      'reconnectionAttempts': 5,
      'reconnectionDelay': 1000,
      'timeout': 5000,
    });

    socket?.onConnect((_) async {
      String? token = await getToken();
      String? Btoken = 'Bearer $token';
      print('Connected! Socket ID: ${socket?.id}');
      socket?.emit('join_room',
          {'roomID': roomID, 'socketID': socket?.id, 'token': token});
    });

    socket?.on('room_members_updated', (data) {
      print('👥 room_members_updated event received: $data');

      if (data is Map<String, dynamic>) {
        final roomID = data['roomID'];
        final members = data['members'];

        if (_context != null && members is List) {
          final roomDBProvider =
              Provider.of<RoomDBProvider>(_context!, listen: false);
          roomDBProvider.changeMemberRole(
              roomID, List<Map<String, dynamic>>.from(members));
        } else {
          print("❗Context not found or members is not a list");
        }
      } else {
        print("❗Invalid data format for room_members_updated event");
      }
    });

    socket?.on('folder_list_updated', (data) {
      print('Received updated folder list: $data');
      if (_context != null) {
        final folderDBProvider =
            Provider.of<FolderDBProvider>(_context!, listen: false);

        // Ensure data is a list of folders
        if (data is Map && data['folders'] is List) {
          folderDBProvider
              .updateFolders(List<Map<String, dynamic>>.from(data['folders']));
        }
      }
    });

    socket?.on('file_list_updated', (data) {
      print('Received updated file list: $data');
      if (_context != null) {
        final fileDBProvider =
            Provider.of<FileDBProvider>(_context!, listen: false);

        // Ensure data is a list of folders
        if (data is Map && data['files'] is List) {
          fileDBProvider
              .updateFiles(List<Map<String, dynamic>>.from(data['files']));
        }
      }
    });

    socket?.on('paper_list_updated', (data) {
      print('Received updated paper list: $data');
      if (_context != null) {
        final paperDBProvider =
            Provider.of<PaperDBProvider>(_context!, listen: false);

        // Ensure data is a map containing a list of papers
        if (data is Map && data['papers'] is List) {
          final papers = List<Map<String, dynamic>>.from(data['papers']);

          for (var paper in papers) {
            paper["width"] = (paper["width"] as num?)?.toDouble() ?? 595.0;
            paper["height"] = (paper["height"] as num?)?.toDouble() ?? 842.0;
          }

          paperDBProvider.updatePapers(papers);
        }
      }
    });

    socket?.on('paper_updated', (data) {
      print('Received updated paper data: $data');
      if (_context != null) {
        final paperDBProvider =
            Provider.of<PaperDBProvider>(_context!, listen: false);

        // Ensure width and height are set correctly
        data["width"] = (data["width"] as num?)?.toDouble() ?? 595.0;
        data["height"] = (data["height"] as num?)?.toDouble() ?? 842.0;

        // Cast data to Map<String, dynamic> before passing it to updatePaper
        if (data is Map<String, dynamic>) {
          paperDBProvider.updatePaper(data); // Update with new paper data
        } else {
          print("Error: Received data is not of type Map<String, dynamic>");
        }
      }
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

// Listen for events
  void on(String event, Function(dynamic) callback) {
    socket?.on(event, callback);
  }

  // Emit events to the server
  void emit(String event, dynamic data) {
    socket?.emit(event, data);
  }
}
