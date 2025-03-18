import 'package:flutter/material.dart';
import 'package:frontend/providers/file_provider.dart';
import 'package:frontend/providers/folder_provider.dart';
import 'package:frontend/providers/paper_provider.dart';
import 'package:uuid/uuid.dart';
import '../services/storage_service.dart';

class RoomProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  final List<Map<String, dynamic>> _rooms = [];
  final Uuid _uuid = Uuid();

  List<Map<String, dynamic>> get rooms => List.unmodifiable(_rooms);

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
    List<Map<String, dynamic>> foldersToDelete =
        folderProvider.folders
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
}
