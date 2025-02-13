import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'object.dart';

//------------------------ Room Provider ------------------------

class RoomProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _rooms = [];
  final Uuid _uuid = Uuid();

  List<Map<String, dynamic>> get rooms => _rooms;

  RoomProvider() {
    _loadRooms();
  }

  // Load rooms from local storage
  Future<void> _loadRooms() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/rooms.json');

    if (await file.exists()) {
      final data = jsonDecode(await file.readAsString());

      _rooms = List<Map<String, dynamic>>.from(data).map((room) {
        return {
          'id': room['id'],
          'name': room['name'],
          'createdDate': room['createdDate'],
          'color':
              (room['color'] is int) ? Color(room['color']) : room['color'],
          'isFavorite': room['isFavorite'],
          'folderIds': List<String>.from(room['folderids'] ?? []),
        };
      }).toList();

      notifyListeners();
    }
  }

  Future<void> _saveRooms() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/rooms.json');

    List<Map<String, dynamic>> roomsToSave = _rooms.map((room) {
      return {
        'id': room['id'],
        'name': room['name'],
        'createdDate': room['createdDate'],
        'color': (room['color'] is Color)
            ? (room['color'] as Color).value
            : room['color'],
        'isFavorite': room['isFavorite'],
        'folderids': room['folderIds'] ?? [],
      };
    }).toList();
    print("Saveroom $roomsToSave");

    await file.writeAsString(jsonEncode(roomsToSave));
  }

  /// Toggle favorite status of a room
  void toggleFavorite(String roomName) {
    final index = _rooms.indexWhere((room) => room['name'] == roomName);
    if (index != -1) {
      _rooms[index]['isFavorite'] = !_rooms[index]['isFavorite'];
      _saveRooms();
      notifyListeners(); //Refresh UI
    }
  }

  /// Add a new room
  void addRoom(String name, Color color) {
    final newRoom = {
      'id': _uuid.v4(), // Generate unique ID
      'name': name,
      'createdDate': DateTime.now().toIso8601String(),
      'color': color.value, // Save color as int
      'isFavorite': false,
    };

    _rooms.add(newRoom);
    _saveRooms();
    notifyListeners(); // Refresh UI after adding a new room
  }

  void addFolderToRoom(String roomId, String folderId) {
    final index = _rooms.indexWhere((room) => room['id'] == roomId);
    if (index != -1) {
      // Ensure 'folderIds' is a List<String> before adding the new folder
      var folders = _rooms[index]['folderIds'];

      // If folders is not already a List<String>, initialize it
      if (folders == null || folders is! List<String>) {
        folders = <String>[]; // Initialize an empty list if needed
      }

      // Add the new folder ID to the list
      (folders as List<String>).add(folderId);

      // Save the updated rooms and notify listeners
      _rooms[index]['folderIds'] = folders; // Correct the key here
      _saveRooms();
      notifyListeners();
    }
  }
}

//------------------------ Folder Provider ------------------------

class FolderProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _folders = [];
  final Uuid _uuid = Uuid();

  List<Map<String, dynamic>> get folders => _folders;

  FolderProvider() {
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/folders.json');

    if (await file.exists()) {
      final fileContent = await file.readAsString();

      // Check if file content is empty
      if (fileContent.isEmpty) {
        // Handle the case when the file is empty
        _folders = [];
        notifyListeners();
        return;
      }

      try {
        final data = jsonDecode(fileContent);

        _folders = List<Map<String, dynamic>>.from(data).map((folder) {
          return {
            'id': folder['id'],
            'name': folder['name'],
            'createdDate': folder['createdDate'],
            'color': (folder['color'] is int)
                ? Color(folder['color'])
                : folder['color'],
            'isFavorite': folder['isFavorite'],
            'folderids': (folder['folderids'] as List<dynamic>?)
                    ?.map((folder) => folder['id'] as String)
                    .toList() ??
                [],
          };
        }).toList();

        notifyListeners();
      } catch (e) {
        print("Error decoding JSON: $e");
      }
    }
  }

  // Save folders to local storage
  Future<void> _saveFolders() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/folders.json');

    List<Map<String, dynamic>> foldersToSave = _folders.map((folder) {
      return {
        'id': folder['id'],
        'name': folder['name'],
        'createdDate': folder['createdDate'],
        'color': (folder['color'] is Color)
            ? (folder['color'] as Color).value
            : folder['color'],
        'isFavorite': folder['isFavorite'],
      };
    }).toList();

    await file.writeAsString(jsonEncode(foldersToSave));
  }

  /// Toggle favorite status of a folder
  void toggleFavoriteFolder(String folderId) {
    final index = _folders.indexWhere((folder) => folder['id'] == folderId);
    if (index != -1) {
      _folders[index]['isFavorite'] = !_folders[index]['isFavorite'];
      _saveFolders();
      notifyListeners();
    }
  }

  /// Add a new folder
  String addFolder(String name, Color color) {
    final String folderId = _uuid.v4();
    final newFolder = {
      'id': folderId,
      'name': name,
      'createdDate': DateTime.now().toIso8601String(),
      'color': color.value,
      'isFavorite': false,
    };

    _folders.add(newFolder);
    _saveFolders();
    notifyListeners();

    return folderId;
  }
}
