import 'package:flutter/material.dart';
import 'package:frontend/api/apiService.dart';

class RoomDBProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final List<Map<String, dynamic>> _rooms = [];
  final List<Map<String, dynamic>> _roomsDB = [];

  List<Map<String, dynamic>> get rooms => List.unmodifiable(_rooms);

  RoomDBProvider() {
    _loadRoomsDB();
  }

  Future<void> _loadRoomsDB() async {
    try {
      _roomsDB.clear();
      final roomDBData = await _apiService.getRooms();
      _roomsDB.addAll(roomDBData);
      _rooms.addAll(roomDBData); // Ensure _rooms is populated
      print('Rooms loaded: $_roomsDB');
      notifyListeners();
    } catch (e) {
      print('Error loading rooms: $e');
    }
  }

  getRooms() {
    _loadRoomsDB();
  }
}
