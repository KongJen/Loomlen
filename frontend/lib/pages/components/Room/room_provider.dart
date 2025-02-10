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

  Future<void> _loadRooms() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/rooms.json');

    if (await file.exists()) {
      final data = jsonDecode(await file.readAsString());
      _rooms = List<Map<String, dynamic>>.from(data);
      notifyListeners(); // Notify UI
    }
  }

  Future<void> _saveRooms() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/rooms.json');
    await file.writeAsString(jsonEncode(_rooms));
  }

  void toggleFavorite(String roomName) {
    final index = _rooms.indexWhere((room) => room['name'] == roomName);
    if (index != -1) {
      _rooms[index]['isFavorite'] = !_rooms[index]['isFavorite'];
      _saveRooms();
      notifyListeners(); // Update UI across all pages
    }
  }
}
