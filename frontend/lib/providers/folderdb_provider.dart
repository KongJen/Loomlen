// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:frontend/api/apiService.dart';
import 'package:uuid/uuid.dart';

class FolderDBProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final List<Map<String, dynamic>> _folders = [];
  final Uuid _uuid = Uuid();

  List<Map<String, dynamic>> get folders => List.unmodifiable(_folders);

  Future<void> loadFoldersDB(String roomId) async {
    try {
      _folders.clear();
      final folderDBData = await _apiService.getFolders(roomId);
      print(folderDBData);
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
    await _apiService.addFolder(
        id: _uuid.v4(),
        roomId: roomId,
        subFolderId: parentFolderId,
        name: name,
        color: color.value);

    notifyListeners();
  }

  Future<void> refreshRooms(String roomId) async {
    await loadFoldersDB(roomId);
  }
}
