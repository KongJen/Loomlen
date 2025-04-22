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
      notifyListeners();
    } catch (e) {
      print('Error loading rooms: $e');
    }
  }

  Future<List<Map<String, dynamic>>> loadMembers(String roomId) async {
    try {
      final members = await _apiService.getMembersInRoom(roomId);
      notifyListeners();
      return members;
    } catch (e) {
      print('Error loading members: $e');
      return [];
    }
  }

  void changeMemberRole(
      String roomId, List<Map<String, dynamic>> members) async {
    try {
      await _apiService.ChangeMemberRole(roomId, members);
      notifyListeners();
    } catch (e) {
      print('Error updating member role: $e');
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
