// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:frontend/providers/file_provider.dart';
import 'package:frontend/providers/paper_provider.dart';
import 'package:uuid/uuid.dart';
import '../services/storage_service.dart';

class FolderProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  final List<Map<String, dynamic>> _folders = [];
  final Uuid _uuid = Uuid();

  List<Map<String, dynamic>> get folders => List.unmodifiable(_folders);

  FolderProvider() {
    _loadFolders();
  }

  Future<void> loadFolders() async {
    await _loadFolders();
  }

  Future<void> _loadFolders() async {
    _folders.clear();
    _folders.addAll(await _storageService.loadData('folders'));
    notifyListeners();
  }

  Future<void> _saveFolders() async {
    await _storageService.saveData('folders', _folders);
  }

  void addFolder(
    String name,
    Color color, {
    String? roomId,
    String? parentFolderId,
  }) {
    final newFolder = {
      'id': _uuid.v4(),
      'roomId': roomId,
      'parentFolderId': parentFolderId,
      'name': name,
      'createdDate': DateTime.now().toIso8601String(),
      'color': color.value,
    };

    _folders.add(newFolder);
    _saveFolders();
    notifyListeners();
  }

  void renameFolder(String folderId, String newName) {
    final folder = _folders.firstWhere(
      (f) => f['id'] == folderId,
      orElse: () => {},
    );
    if (folder.isNotEmpty) {
      folder['name'] = newName;
      _saveFolders();
      notifyListeners();
    }
  }

  Future<void> deleteFolder(
    String folderId,
    FolderProvider folderProvider_,
    FileProvider fileProvider,
    PaperProvider paperProvider,
  ) async {
    await folderProvider_.loadFolders();
    await fileProvider.loadFiles();
    await paperProvider.loadPapers();

    List<Map<String, dynamic>> subfoldersToDelete =
        folderProvider_.folders
            .where((folder) => folder['parentFolderId'] == folderId)
            .toList();

    for (var folder in subfoldersToDelete) {
      await folderProvider_.deleteFolder(
        folder['id'],
        folderProvider_,
        fileProvider,
        paperProvider,
      );
    }

    List<Map<String, dynamic>> filesToDelete =
        fileProvider.files
            .where((file) => file['folderId'] == folderId)
            .toList();

    for (var file in filesToDelete) {
      await fileProvider.deleteFile(file['id'], paperProvider);
    }

    _folders.removeWhere((folder) => folder['id'] == folderId);
    await _saveFolders();
    await _loadFolders();
    notifyListeners();
  }
}
