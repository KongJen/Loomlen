import 'package:flutter/material.dart';
import 'package:frontend/api/apiService.dart';

class RoomDBProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final List<Map<String, dynamic>> _rooms = [];
  final List<Map<String, dynamic>> _roomsDB = [];

  List<Map<String, dynamic>> get rooms => List.unmodifiable(_rooms);

  Future<void> loadRoomsDB() async {
    try {
      _rooms.clear();
      final roomDBData = await _apiService.getRooms();
      _rooms.addAll(roomDBData); // Ensure _rooms is populated
      print('Rooms loaded: ${_rooms}');
      notifyListeners();
    } catch (e) {
      print('Error loading rooms: $e');
    }
  }

  void toggleFavorite(String roomId) async {
    try {
      await _apiService.toggleFav(roomId);
      loadRoomsDB();
      notifyListeners();
    } catch (e) {
      print('Error loading rooms: $e');
    }
  }

  Future<void> refreshRooms() async {
    await loadRoomsDB();
  }
}
