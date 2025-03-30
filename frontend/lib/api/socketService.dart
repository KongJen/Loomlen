import 'package:flutter/material.dart';
import 'package:frontend/providers/filedb_provider.dart';
import 'package:frontend/providers/folderdb_provider.dart';
import 'package:frontend/providers/paperdb_provider.dart';
import 'package:frontend/services/drawingDb_service.dart';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:frontend/global.dart';

class SocketService {
  IO.Socket? socket;
  final String baseUrl = baseurl;
  BuildContext? _context;

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

    socket?.onConnect((_) {
      print('Connected! Socket ID: ${socket?.id}');
      socket?.emit('join_room', {'roomID': roomID, 'socketID': socket?.id});
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
