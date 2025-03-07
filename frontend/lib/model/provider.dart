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
              'folderIds': List<String>.from(room['folderIds'] ?? []),
              'fileIds': List<String>.from(room['fileIds'] ?? []),
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
            'folderIds': room['folderIds'] ?? [],
            'fileIds': room['fileIds'] ?? [],
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

  void addFolderToRoom(String roomId, String folderId) {
    final index = _rooms.indexWhere((room) => room['id'] == roomId);
    if (index != -1) {
      // Ensure 'folderIds' is a List<String> before adding the new folder
      var folders = _rooms[index]['folderIds'];

      // If folders is not already a List<String>, initialize it
      if (folders == null || folders is! List<String>) {
        folders = <String>[]; // Initialize an empty list if needed
      }
      folders.add(folderId);
      // Save the updated rooms and notify listeners
      _rooms[index]['folderIds'] = folders; // Correct the key here
      _saveRooms();
      notifyListeners();
    }
  }

  void addFileToRoom(String roomId, String fileId) {
    final index = _rooms.indexWhere((room) => room['id'] == roomId);
    //Change this function to add File
    if (index != -1) {
      // Ensure 'folderIds' is a List<String> before adding the new folder
      var files = _rooms[index]['fileIds'];

      // If folders is not already a List<String>, initialize it
      if (files == null || files is! List<String>) {
        files = <String>[]; // Initialize an empty list if needed
      }

      // Add the new folder ID to the list
      files.add(fileId);

      // Save the updated rooms and notify listeners
      _rooms[index]['fileIds'] = files; // Correct the key here
      _saveRooms();
      notifyListeners();

      // print("File $fileId added to room $roomId");
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
            'id': folder['id'],
            'name': folder['name'],
            'createdDate': folder['createdDate'],
            'color':
                (folder['color'] is Color)
                    // ignore: deprecated_member_use
                    ? (folder['color'] as Color).value
                    : folder['color'],
            'subfolderIds': folder['subfolderIds'] ?? [],
            'fileIds': folder['fileIds'] ?? [],
          };
        }).toList();

    await file.writeAsString(jsonEncode(foldersToSave));
  }

  /// Add a new folder
  String addFolder(String name, Color color) {
    final String folderId = _uuid.v4();
    final newFolder = {
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

  void addFolderToFolder(String folderId, String subfolderId) {
    final index = _folders.indexWhere((folder) => folder['id'] == folderId);
    if (index != -1) {
      // Ensure 'folderIds' is a List<String> before adding the new folder
      var folders = _folders[index]['subfolderIds'];

      // If folders is not already a List<String>, initialize it
      if (folders == null || folders is! List<String>) {
        folders = <String>[]; // Initialize an empty list if needed
      }

      // Add the new folder ID to the list
      folders.add(subfolderId);

      // Save the updated rooms and notify listeners
      _folders[index]['subfolderIds'] = folders; // Correct the key here
      _saveFolders();
      notifyListeners();
    }
  }

  void addFileToFolder(String folderId, String fileId) {
    final index = _folders.indexWhere((folder) => folder['id'] == folderId);
    if (index != -1) {
      // Ensure 'folderIds' is a List<String> before adding the new folder
      var files = _folders[index]['fileIds'];

      // If folders is not already a List<String>, initialize it
      if (files == null || files is! List<String>) {
        files = <String>[]; // Initialize an empty list if needed
      }

      // Add the new folder ID to the list
      files.add(fileId);

      // Save the updated rooms and notify listeners
      _folders[index]['fileIds'] = files; // Correct the key here
      _saveFolders();
      notifyListeners();

      // print("File $fileId added to folder $folderId");
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
            'id': file['id'],
            'name': file['name'],
            'createdDate': file['createdDate'],
            'pageIds': List<String>.from(file['pageIds'] ?? []),
          };
        }).toList();

    await file.writeAsString(jsonEncode(filesToSave));
  }

  /// Add a new file
  String addFile(
    String name, [
    List<Map<String, dynamic>>? drawingData,
    List<Map<String, dynamic>>? pageIds,
  ]) {
    final String fileId = _uuid.v4();
    final newFile = {
      'id': fileId,
      'name': name,
      'createdDate': DateTime.now().toIso8601String(),
      'drawingData': drawingData ?? [],
    };

    _files.add(newFile);
    _saveFiles();
    notifyListeners();

    return fileId;
  }

  void addPaperPageToFile(String fileId, String pageId) {
    final index = _files.indexWhere((file) => file['id'] == fileId);
    if (index != -1) {
      // Ensure 'folderIds' is a List<String> before adding the new folder
      var pages = _files[index]['pageIds'];

      // If folders is not already a List<String>, initialize it
      if (pages == null || pages is! List<String>) {
        pages = <String>[]; // Initialize an empty list if needed
      }

      // Add the new folder ID to the list
      pages.add(pageId);

      // Save the updated rooms and notify listeners
      _files[index]['pageIds'] = pages; // Correct the key here
      _saveFiles();
      notifyListeners();
    }
  }

  Future<void> updateFileDrawingData(
    String fileId,
    List<Map<String, dynamic>> drawingData,
  ) async {
    final index = _files.indexWhere((file) => file['id'] == fileId);
    if (index != -1) {
      _files[index]['drawingData'] = drawingData;
      _saveFiles();
      notifyListeners();
    }
  }

  Map<String, dynamic>? getFileById(String fileId) {
    final index = _files.indexWhere((file) => file['id'] == fileId);
    if (index != -1) {
      return _files[index];
    }
    return null;
  }
}

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
                'id': paper['id'],
                'pdfPath': paper['pdfPath'],
                'recognizedText': paper['recognizedText'],
                'templateId': paper['templateId'],
                'templateType': paper['templateType'],
                'PageNumber': paper['PageNumber'],
                'width': paper['width'],
                'height': paper['height'],
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
            'id': paper['id'],
            'pdfPath': paper['pdfPath'],
            'recognizedText': paper['recognizedText'],
            'templateId': paper['templateId'],
            'templateType': paper['templateType'],
            'PageNumber': paper['PageNumber'],
            'width': paper['width'],
            'height': paper['height'],
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
  ) {
    final String paperId = _uuid.v4();
    final newPaper = {
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
}
