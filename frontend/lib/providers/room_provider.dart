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

  Future<void> shareRoom(
      String roomId,
      List<String> sharedWith,
      String permission,
      FolderProvider folderProvider,
      FileProvider fileProvider,
      PaperProvider paperProvider) async {
    try {
      final room = _rooms.firstWhere(
        (f) => f['id'] == roomId,
        orElse: () => {},
      );
      if (room.isEmpty) return;

      // Share the file
      final roomID = await _apiService.shareRoom(
        roomId: roomId,
        name: room['name'],
        color: room['color'],
      );

      await _apiService.shareMember(
        roomId: roomID,
        sharedWith: sharedWith,
        permission: permission,
      );

      print("room ID from Database: ${roomID}");

      List<Map<String, dynamic>> rootFolders = folderProvider.folders
          .where((folder) =>
              folder['roomId'] == roomId &&
              (folder['parentFolderId'] == null ||
                  folder['parentFolderId'] == ''))
          .toList();

      print("RootFolders : ${rootFolders}");

      Map<String, String> folderIdMapping = {};
      Map<String, String> fileIdMapping = {};

      for (var folder in rootFolders) {
        print("Folders : ${folder}");
        print("roomID : ${roomID}");
        print("folderIDMapping : ${folderIdMapping}");
        await _processFolder(
          folder,
          roomID,
          '',
          folderProvider,
          fileProvider,
          paperProvider,
          folderIdMapping,
          fileIdMapping,
        );
      }

      List<Map<String, dynamic>> rootFiles = fileProvider.files
          .where((file) =>
              file['roomId'] == roomId &&
              (file['parentFolderId'] == null || file['parentFolderId'] == ''))
          .toList();

      for (var file in rootFiles) {
        final newFileId = await _apiService.addFile(
          id: file['id'],
          roomId: roomID,
          subFolderId: '',
          name: file['name'],
        );
        print("Root File ID: ${file['id']}");

        fileIdMapping[file['id']] = newFileId;

        await _processPapers(file['id'], roomID, newFileId, paperProvider);
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

  Future<String> _processFolder(
    Map<String, dynamic> folder,
    String sharedRoomId,
    String parentFolderId,
    FolderProvider folderProvider,
    FileProvider fileProvider,
    PaperProvider paperProvider,
    Map<String, String> folderIdMapping,
    Map<String, String> fileIdMapping,
  ) async {
    // Add the folder
    final newFolderId = await _apiService.addFolder(
      id: folder['id'],
      roomId: sharedRoomId,
      subFolderId: parentFolderId,
      name: folder['name'],
      color: folder['color'],
    );

    print("Created folder ID: ${folder['id']} -> $newFolderId");

    // Store the mapping between original and new folder ID
    folderIdMapping[folder['id']] = newFolderId;

    // Find and process child folders
    List<Map<String, dynamic>> childFolders = folderProvider.folders
        .where((f) => f['parentFolderId'] == folder['id'])
        .toList();

    print("Child folders of ${folder['id']}: ${childFolders.length}");

    // Process each child folder recursively
    for (var childFolder in childFolders) {
      await _processFolder(
        childFolder,
        sharedRoomId,
        newFolderId,
        folderProvider,
        fileProvider,
        paperProvider,
        folderIdMapping,
        fileIdMapping,
      );
    }

    // Process files in this folder
    List<Map<String, dynamic>> filesInFolder = fileProvider.files
        .where((file) => file['parentFolderId'] == folder['id'])
        .toList();

    print("Files in folder ${folder['id']}: ${filesInFolder.length}");

    for (var file in filesInFolder) {
      final newFileId = await _apiService.addFile(
        id: file['id'],
        roomId: sharedRoomId,
        subFolderId: newFolderId,
        name: file['name'],
      );
      print("Added file: ${file['id']} to folder: $newFolderId");
      fileIdMapping[file['id']] = newFileId;

      await _processPapers(file['id'], sharedRoomId, newFileId, paperProvider);
    }

    return newFolderId;
  }

  Future<void> _processPapers(
    String originalFileId,
    String roomId,
    String newFileId,
    PaperProvider paperProvider,
  ) async {
    // Get all papers for this file
    List<Map<String, dynamic>> papersInFile = paperProvider.papers
        .where((paper) => paper['fileId'] == originalFileId)
        .toList();

    print("Papers in file $originalFileId: ${papersInFile.length}");

    for (var paper in papersInFile) {
      final paperId = await _apiService.addPaper(
        id: paper['id'],
        roomId: roomId,
        fileId: newFileId,
        templateId: paper['templateId'],
        pageNumber: paper['PageNumber'],
        width: paper['width'],
        height: paper['height'],
      );
      print("Added paper: ${paper['id']} to file: $newFileId");

      await _apiService.addDraw(paperId, paper['drawingData']);
    }
  }

  Future<void> refreshSharedRooms() async {
    await _loadRooms();
  }
}
