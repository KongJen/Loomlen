// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:frontend/api/apiService.dart';
import 'package:uuid/uuid.dart';

class FileDBProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final List<Map<String, dynamic>> _files = [];
  final Uuid _uuid = Uuid();

  List<Map<String, dynamic>> get files => List.unmodifiable(_files);

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

  Future<Map<String, String>> addFile(
    String name, {
    required String roomId,
    required String parentFolderId,
  }) async {
    String baseName = name.trim();
    String uniqueName = baseName;
    int counter = 1;

    // Filter folders within the same room and parent
    final existingFolders = _files.where((file) =>
        file['room_id'].toString().trim() == roomId &&
        file['sub_folder_id'].toString().trim() == parentFolderId);

    // Ensure name is unique in this context
    while (existingFolders.any((file) => file['name'] == uniqueName)) {
      uniqueName = '$baseName ($counter)';
      counter++;
    }

    final String fileId = _uuid.v4();
    String fileDbId = await _apiService.addFile(
      id: fileId,
      roomId: roomId,
      subFolderId: parentFolderId,
      name: uniqueName,
    );

    notifyListeners();
    return {'id': fileDbId, 'name': uniqueName};
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

  Future<void> renameFile(
    String fileId,
    String newName,
  ) async {
    final file = _files.firstWhere(
      (f) => f['id'] == fileId,
      orElse: () => <String, dynamic>{},
    );

    String baseName = newName.trim();
    String uniqueName = baseName;
    int counter = 1;

    final roomId = file['room_id'].toString().trim();
    final parentFolderId = file['sub_folder_id'].toString().trim();

    // Filter existing files in the same room and folder, excluding the current file
    final existingFiles = _files.where((f) =>
        f['room_id'].toString().trim() == roomId &&
        f['sub_folder_id'].toString().trim() == parentFolderId &&
        f['id'] != fileId);

    // Ensure unique name
    while (existingFiles.any((f) => f['name'] == uniqueName)) {
      uniqueName = '$baseName ($counter)';
      counter++;
    }

    // Update in API and locally
    await _apiService.renameFile(fileId, uniqueName);
    file['name'] = uniqueName;

    notifyListeners();
  }
}
