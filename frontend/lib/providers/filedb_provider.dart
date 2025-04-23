// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:frontend/api/apiService.dart';
import 'package:uuid/uuid.dart';

class FileDBProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final List<Map<String, dynamic>> _files = [];
  final Uuid _uuid = Uuid();

  List<Map<String, dynamic>> get folders => List.unmodifiable(_files);

  Future<void> loadFilesDB(String roomId) async {
    try {
      _files.clear();
      final folderDBData = await _apiService.getFile(roomId);
      _files.addAll(folderDBData);
      notifyListeners();
    } catch (e) {
      print('Error loading files: $e');
    }
  }

  void updateFiles(List<Map<String, dynamic>> newFolders) {
    _files.clear();
    _files.addAll(newFolders);
    notifyListeners();
  }

  Future<String> addFile(
    String name, {
    required String roomId,
    required String parentFolderId,
  }) async {
    final String fileId = _uuid.v4();
    String fileDbId = await _apiService.addFile(
      id: fileId,
      roomId: roomId,
      subFolderId: parentFolderId,
      name: name,
    );

    notifyListeners();
    return fileDbId;
  }

  Future<String> getId(String fileId) async {
    final String fileDbId =
        await _apiService.getFileIdByOrigin(fileId); // ✅ Use `await`

    print("fileDBID: $fileDbId");

    return fileDbId;
  }

  Future<void> refreshRooms(String roomId) async {
    await loadFilesDB(roomId);
  }

  Future<void> deleteFile(String fileId) async {
    await _apiService.deleteFile(fileId);
    notifyListeners();
  }
}
