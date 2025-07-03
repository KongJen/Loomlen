// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:frontend/api/apiService.dart';
import 'package:frontend/providers/filedb_provider.dart';
import 'package:frontend/providers/paperdb_provider.dart';
import 'package:uuid/uuid.dart';

class FolderDBProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final List<Map<String, dynamic>> _folders = [];
  final Uuid _uuid = Uuid();

  List<Map<String, dynamic>> get folders => List.unmodifiable(_folders);

  Future<void> loadFoldersDB(String roomId) async {
    try {
      _folders.clear();
      print("Fetch RoomID: $roomId");
      final folderDBData = await _apiService.getFolders(roomId);
      print("Folder Data : ${folderDBData}");
      _folders.addAll(folderDBData); // Ensure _rooms is populated
      notifyListeners();
    } catch (e) {
      print('Error loading folders: $e');
    }
  }

  void updateFolders(List<Map<String, dynamic>> newFolders) {
    _folders.clear();
    _folders.addAll(newFolders);
    notifyListeners();
  }

  void addFolder(
    String name,
    Color color, {
    required String roomId,
    required String parentFolderId,
  }) async {
    String baseName = name.trim();
    String uniqueName = baseName;
    int counter = 1;

    // Filter folders within the same room and parent
    final existingFolders = _folders.where((folder) =>
        folder['room_id'].toString().trim() == roomId &&
        folder['sub_folder_id'].toString().trim() == parentFolderId);

    // Ensure name is unique in this context
    while (existingFolders.any((folder) => folder['name'] == uniqueName)) {
      uniqueName = '$baseName ($counter)';
      counter++;
    }

    await _apiService.addFolder(
        id: _uuid.v4(),
        roomId: roomId,
        subFolderId: parentFolderId,
        name: uniqueName,
        color: color.value);

    notifyListeners();
  }

  Future<void> refreshRooms(String roomId) async {
    await loadFoldersDB(roomId);
  }

  Future<void> deleteFolder(String folderId) async {
    await _apiService.deleteFolder(folderId);
    notifyListeners();
  }

  Future<void> renameFolder(
    String folderId,
    String newName,
  ) async {
    final folder =
        _folders.firstWhere((f) => f['id'] == folderId, orElse: () => {});
    if (folder.isEmpty) return;

    final roomId = folder['room_id'].toString().trim();
    final parentFolderId = folder['sub_folder_id'].toString().trim();

    String baseName = newName.trim();
    String uniqueName = baseName;
    int counter = 1;

    // Filter sibling folders excluding the current one
    final existingFolders = _folders.where((f) =>
        f['room_id'].toString().trim() == roomId &&
        f['sub_folder_id'].toString().trim() == parentFolderId &&
        f['id'] != folderId);

    // Ensure the new name is unique
    while (existingFolders.any((f) => f['name'] == uniqueName)) {
      uniqueName = '$baseName ($counter)';
      counter++;
    }

    await _apiService.renameFolder(folderId, uniqueName);
    folder['name'] = uniqueName;
    notifyListeners();
  }
}
