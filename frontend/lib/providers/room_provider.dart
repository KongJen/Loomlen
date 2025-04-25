import 'package:flutter/material.dart';
import 'package:frontend/providers/file_provider.dart';
import 'package:frontend/providers/folder_provider.dart';
import 'package:frontend/providers/paper_provider.dart';
import 'package:uuid/uuid.dart';
import '../services/storage_service.dart';
import '../api/apiService.dart';
import '../providers/folder_provider.dart';

class RoomProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  final List<Map<String, dynamic>> _rooms = [];
  final List<Map<String, dynamic>> _folders = [];
  final Uuid _uuid = Uuid();
  final ApiService _apiService = ApiService();

  List<Map<String, dynamic>> get rooms => List.unmodifiable(_rooms);

  List<Map<String, dynamic>> get folders => List.unmodifiable(_folders);

  RoomProvider() {
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    _rooms.clear();
    _rooms.addAll(await _storageService.loadData('rooms'));
    notifyListeners();
  }

  Future<void> _saveRooms() async {
    await _storageService.saveData('rooms', _rooms);
  }

  void addRoom(String name, Color color) {
    final newRoom = {
      'id': _uuid.v4(),
      'name': name,
      'createdDate': DateTime.now().toIso8601String(),
      // ignore: deprecated_member_use
      'color': color.value,
      'isFavorite': false,
    };

    _rooms.add(newRoom);
    _saveRooms();
    notifyListeners();
  }

  void renameRoom(String roomId, String newName) {
    final room = _rooms.firstWhere((r) => r['id'] == roomId, orElse: () => {});
    if (room.isNotEmpty) {
      room['name'] = newName;
      _saveRooms();
      notifyListeners();
    }
  }

  Future<void> deleteRoom(
    String roomId,
    FolderProvider folderProvider,
    FileProvider fileProvider,
    PaperProvider paperProvider,
  ) async {
    await folderProvider.loadFolders();
    await fileProvider.loadFiles();
    await paperProvider.loadPapers();

    // Delete all folders inside the room
    List<Map<String, dynamic>> foldersToDelete = folderProvider.folders
        .where((folder) => folder['roomId'] == roomId)
        .toList();

    for (var folder in foldersToDelete) {
      await folderProvider.deleteFolder(
        folder['id'],
        folderProvider,
        fileProvider,
        paperProvider,
      );
    }

    // Delete all files inside the room
    List<Map<String, dynamic>> filesToDelete =
        fileProvider.files.where((file) => file['roomId'] == roomId).toList();

    for (var file in filesToDelete) {
      await fileProvider.deleteFile(file['id'], paperProvider);
    }

    // Remove room
    _rooms.removeWhere((room) => room['id'] == roomId);
    await _saveRooms();
    notifyListeners();
  }

  void toggleFavorite(String roomId) {
    final roomIndex = _rooms.indexWhere((r) => r['id'] == roomId);

    if (roomIndex != -1) {
      _rooms[roomIndex]['isFavorite'] = !_rooms[roomIndex]['isFavorite'];
      _saveRooms();
      notifyListeners();
    }
  }

  Future<void> shareRoom(String roomId, List<String> sharedWith,
      String permission, FolderProvider folderProvider) async {
    try {
      final room = _rooms.firstWhere(
        (f) => f['id'] == roomId,
        orElse: () => {},
      );
      if (room.isEmpty) return;

      // Share the file
      await _apiService.shareRoom(
        roomId: roomId,
        name: room['name'],
        color: room['color'],
      );

      final roomID = await _apiService.getRoomID(roomId);

      await _apiService.shareMember(
        roomId: roomID,
        sharedWith: sharedWith,
        permission: permission,
      );

      print("room ID from Database: ${roomID}");

      List<Map<String, dynamic>> roomFolders = folderProvider.folders
          .where((folder) => folder['roomId'] == roomID)
          .toList();

      print("Folder room ID : ${roomFolders}");
      print("Folder room ID : ${roomID}");

      for (var folder in roomFolders) {
        await _apiService.addFolder(
          id: folder['id'],
          roomId: roomID,
          subFolderId: folder['parentFolderId'] ?? '',
          name: folder['name'],
          color: folder['color'],
        );
        print("Folder ID: ${folder['id']}");
      }

      // Update the local file to indicate it's shared
      room['isShared'] = true;
      await _saveRooms();

      // Refresh shared files
      await refreshSharedRooms();

      notifyListeners();
    } catch (e) {
      print('Error sharing room: $e');
      rethrow;
    }
  }

  Future<void> refreshSharedRooms() async {
    await _loadRooms();
  }
}
