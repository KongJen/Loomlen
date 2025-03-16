import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:frontend/OBJ/object.dart';

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
      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString);

      _rooms =
          List<Map<String, dynamic>>.from(data).map((room) {
            return {
              'id': room['id'],
              'name': room['name'],
              'createdDate': room['createdDate'],
              'color':
                  (room['color'] is int) ? Color(room['color']) : room['color'],
              'isFavorite': room['isFavorite'],
            };
          }).toList();

      notifyListeners();
    }
  }

  Future<void> _saveRooms() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/rooms.json');

    List<Map<String, dynamic>> roomsToSave =
        _rooms.map((room) {
          return {
            'id': room['id'],
            'name': room['name'],
            'createdDate': room['createdDate'],
            'color':
                (room['color'] is Color)
                    // ignore: deprecated_member_use
                    ? (room['color'] as Color).value
                    : room['color'],
            'isFavorite': room['isFavorite'],
          };
        }).toList();

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
      // ignore: deprecated_member_use
      'color': color.value, // Save color as int
      'isFavorite': false,
    };

    _rooms.add(newRoom);
    _saveRooms();
    notifyListeners(); // Refresh UI after adding a new room
  }

  Future<void> deleteRoom(
    String roomId,
    FolderProvider folderProvider,
    FileProvider fileProvider,
    PaperProvider paperProvider,
  ) async {
    await folderProvider._loadFolders(); // Load latest data
    await fileProvider._loadFiles(); // Load latest data
    await paperProvider._loadPapers();

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

    List<Map<String, dynamic>> filesToDelete =
        fileProvider.files.where((file) => file['roomId'] == roomId).toList();

    for (var file in filesToDelete) {
      await fileProvider.deleteFile(file['id'], paperProvider);
    }

    _rooms.removeWhere((room) => room['id'] == roomId);
    await _saveRooms();
    notifyListeners();
  }

  void renameRoom(String roomId, String newName) {
    final index = _rooms.indexWhere((room) => room['id'] == roomId);
    if (index != -1) {
      _rooms[index]['name'] = newName;
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

        _folders =
            List<Map<String, dynamic>>.from(data).map((folder) {
              return {
                'roomId': folder['roomId'],
                'parentFolderId': folder['parentFolderId'],
                'id': folder['id'],
                'name': folder['name'],
                'createdDate': folder['createdDate'],
                'color':
                    (folder['color'] is int)
                        ? Color(folder['color'])
                        : folder['color'],
                'subfolderIds': List<String>.from(folder['subfolderIds'] ?? []),
                'fileIds': List<String>.from(folder['fileIds'] ?? []),
              };
            }).toList();

        notifyListeners();
      } catch (e) {
        if (kDebugMode) {
          ("Error decoding JSON: $e");
        }
      }
    }
  }

  // Save folders to local storage
  Future<void> _saveFolders() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/folders.json');

    List<Map<String, dynamic>> foldersToSave =
        _folders.map((folder) {
          return {
            'roomId': folder['roomId'],
            'parentFolderId': folder['parentFolderId'],
            'id': folder['id'],
            'name': folder['name'],
            'createdDate': folder['createdDate'],
            'color':
                (folder['color'] is Color)
                    // ignore: deprecated_member_use
                    ? (folder['color'] as Color).value
                    : folder['color'],
          };
        }).toList();

    await file.writeAsString(jsonEncode(foldersToSave));
  }

  /// Add a new folder
  String addFolder(
    String name,
    Color color, {
    String? roomId,
    String? parentFolderId,
  }) {
    final String folderId = _uuid.v4();
    final newFolder = {
      'roomId': roomId, // If adding to a room
      'parentFolderId': parentFolderId, // If adding to another folder
      'id': folderId,
      'name': name,
      'createdDate': DateTime.now().toIso8601String(),
      // ignore: deprecated_member_use
      'color': color.value,
    };

    _folders.add(newFolder);
    _saveFolders();
    notifyListeners();

    return folderId;
  }

  Future<void> deleteFolder(
    String folderId,
    FolderProvider folderProvider_,
    FileProvider fileProvider,
    PaperProvider paperProvider,
  ) async {
    await folderProvider_._loadFolders(); // Load latest data
    await fileProvider._loadFiles(); // Load latest data
    await paperProvider._loadPapers();

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

  void renameFolder(String folderId, String newName) {
    final index = _folders.indexWhere((folder) => folder['id'] == folderId);
    if (index != -1) {
      _folders[index]['name'] = newName;
      _saveFolders();
      notifyListeners();
    }
  }
}

//------------------------ File Provider ----------------------------

class FileProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _files = [];
  final Uuid _uuid = Uuid();

  List<Map<String, dynamic>> get files => _files;

  FileProvider() {
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/files.json');

    if (await file.exists()) {
      final fileContent = await file.readAsString();

      // Check if file content is empty
      if (fileContent.isEmpty) {
        // Handle the case when the file is empty
        _files = [];
        notifyListeners();
        return;
      }

      try {
        final data = jsonDecode(fileContent);

        _files =
            List<Map<String, dynamic>>.from(data).map((file) {
              return {
                'roomId': file['roomId'],
                'parentFolderId': file['parentFolderId'],
                'id': file['id'],
                'name': file['name'],
                'createdDate': file['createdDate'],
                'pageIds': List<String>.from(file['pageIds'] ?? []),
              };
            }).toList();

        notifyListeners();
      } catch (e) {
        if (kDebugMode) {
          print("Error decoding JSON: $e");
        }
        _files = [];
      }
    }
  }

  // Save files to local storage
  Future<void> _saveFiles() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/files.json');

    List<Map<String, dynamic>> filesToSave =
        _files.map((file) {
          return {
            'roomId': file['roomId'],
            'parentFolderId': file['parentFolderId'],
            'id': file['id'],
            'name': file['name'],
            'createdDate': file['createdDate'],
            'pageIds': List<String>.from(file['pageIds'] ?? []),
          };
        }).toList();

    await file.writeAsString(jsonEncode(filesToSave));
  }

  /// Add a new file
  String addFile(String name, {String? roomId, String? parentFolderId}) {
    final String fileId = _uuid.v4();
    final newFile = {
      'roomId': roomId,
      'parentFolderId': parentFolderId,
      'id': fileId,
      'name': name,
      'createdDate': DateTime.now().toIso8601String(),
    };

    _files.add(newFile);
    _saveFiles();
    notifyListeners();

    return fileId;
  }

  Map<String, dynamic>? getFileById(String fileId) {
    final index = _files.indexWhere((file) => file['id'] == fileId);
    if (index != -1) {
      return _files[index];
    }
    return null;
  }

  Future<void> deleteFile(String fileId, PaperProvider paperProvider) async {
    await paperProvider._loadPapers(); // Load latest data

    List<Map<String, dynamic>> papersToDelete =
        paperProvider.papers
            .where((paper) => paper['fileId'] == fileId)
            .toList();

    for (var paper in papersToDelete) {
      await paperProvider.deletePaper(paper['id']);
    }
    _files.removeWhere((file) => file['id'] == fileId);
    await _saveFiles();
    notifyListeners();
  }

  void renameFile(String fileId, String newName) {
    final index = _files.indexWhere((file) => file['id'] == fileId);
    if (index != -1) {
      _files[index]['name'] = newName;
      _saveFiles();
      notifyListeners();
    }
  }
}

//------------------------ Paper Provider ----------------------------//

class PaperProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _papers = [];
  final Uuid _uuid = Uuid();

  List<Map<String, dynamic>> get papers => _papers;

  PaperProvider() {
    _loadPapers();
  }

  Future<void> _loadPapers() async {
    final directory = await getApplicationDocumentsDirectory();
    final paper = File('${directory.path}/papers.json');

    if (await paper.exists()) {
      final paperContent = await paper.readAsString();

      // Check if paper content is empty
      if (paperContent.isEmpty) {
        // Handle the case when the paper is empty
        _papers = [];
        notifyListeners();
        return;
      }

      try {
        final data = jsonDecode(paperContent);

        _papers =
            List<Map<String, dynamic>>.from(data).map((paper) {
              return {
                'fileId': paper['fileId'],
                'id': paper['id'],
                'pdfPath': paper['pdfPath'],
                'recognizedText': paper['recognizedText'],
                'templateId': paper['templateId'],
                'templateType': paper['templateType'],
                'PageNumber': paper['PageNumber'],
                'width': paper['width'],
                'height': paper['height'],
                'drawingData':
                    paper['drawingData'] ??
                    [], // Add this line to include drawing data
              };
            }).toList();

        notifyListeners();
      } catch (e) {
        if (kDebugMode) {
          print("Error decoding JSON: $e");
        }
        _papers = [];
      }
    }
  }

  // Save papers to local storage
  Future<void> _savePapers() async {
    final directory = await getApplicationDocumentsDirectory();
    final paper = File('${directory.path}/papers.json');

    List<Map<String, dynamic>> papersToSave =
        _papers.map((paper) {
          return {
            'fileId': paper['fileId'],
            'id': paper['id'],
            'pdfPath': paper['pdfPath'],
            'recognizedText': paper['recognizedText'],
            'templateId': paper['templateId'],
            'templateType': paper['templateType'],
            'PageNumber': paper['PageNumber'],
            'width': paper['width'],
            'height': paper['height'],
            'drawingData':
                paper['drawingData'] ??
                [], // Add this line to save drawing data
          };
        }).toList();

    await paper.writeAsString(jsonEncode(papersToSave));
  }

  /// Add a new file
  String addPaper(
    PaperTemplate template,
    int pageNumber,
    List<Map<String, dynamic>>? drawingData,
    String? pdfPath,
    double? width, // Add width parameter
    double? height, // Add height parameter
    String fileId,
  ) {
    final String paperId = _uuid.v4();
    final newPaper = {
      'fileId': fileId,
      'id': paperId,
      'templateId': template.id,
      'templateType': template.templateType.toString(),
      'drawingData': drawingData ?? [],
      'PageNumber': pageNumber,
      'pdfPath': pdfPath,
      'width': width ?? 595.0,
      'height': height ?? 842.0,
    };

    _papers.add(newPaper);
    _savePapers();
    notifyListeners();

    return paperId;
  }

  Future<void> updatePaperDrawingData(
    String paperId,
    List<Map<String, dynamic>> drawingData,
  ) async {
    final index = _papers.indexWhere((paper) => paper['id'] == paperId);
    if (index != -1) {
      _papers[index]['drawingData'] = drawingData;
      _savePapers();
      notifyListeners();
    }
  }

  Map<String, dynamic>? getPaperById(String paperId) {
    final index = _papers.indexWhere((paper) => paper['id'] == paperId);
    if (index != -1) {
      return _papers[index];
    }
    return null;
  }

  Future<void> deletePaper(String paperId) async {
    _papers.removeWhere((paper) => paper['id'] == paperId);
    await _savePapers();
    notifyListeners();
  }
}
