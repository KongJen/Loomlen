import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class RoomProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _rooms = [];

  List<Map<String, dynamic>> get rooms => _rooms;

  RoomProvider() {
    _loadRooms();
  }

  // Load rooms from local storage
  Future<void> _loadRooms() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/rooms.json');

    if (await file.exists()) {
      final data = jsonDecode(await file.readAsString());

      _rooms = List<Map<String, dynamic>>.from(data).map((room) {
        return {
          'name': room['name'],
          'createdDate': room['createdDate'],
          'color': (room['color'] is int)
              ? Color(room['color'])
              : room['color'], // Fix color conversion
          'isFavorite': room['isFavorite'],
        };
      }).toList();

      notifyListeners(); // Refresh UI
    }
  }

  // Save rooms to local storage
  Future<void> _saveRooms() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/rooms.json');

    List<Map<String, dynamic>> roomsToSave = _rooms.map((room) {
      return {
        'name': room['name'],
        'createdDate': room['createdDate'],
        'color': (room['color'] is Color)
            ? (room['color'] as Color).value
            : room['color'], // Convert Color to int
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
      'name': name,
      'createdDate': DateTime.now().toIso8601String(),
      'color': color.value, // Save color as int
      'isFavorite': false,
    };

    _rooms.add(newRoom);
    _saveRooms();
    notifyListeners(); // Refresh UI after adding a new room
  }
}
