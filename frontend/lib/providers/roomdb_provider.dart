import 'package:flutter/material.dart';
import 'package:frontend/api/apiService.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RoomDBProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final List<Map<String, dynamic>> _rooms = [];

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

  void updateMemberRole(String roomId, String originalId,
      List<Map<String, dynamic>> members) async {
    try {
      await _apiService.updateMemberRole(roomId, originalId, members);
      notifyListeners();
    } catch (e) {
      print('Error updating member role: $e');
    }
  }

  Future<void> changeMemberRole(
      String roomId, List<Map<String, dynamic>> members) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? email = prefs.getString('email');
    print("email: $email");
    bool roleChanged = false;

    for (int i = 0; i < _rooms.length; i++) {
      if (_rooms[i]['id'] == roomId) {
        for (int j = 0; j < members.length; j++) {
          if (members[j]['email'] == email) {
            if (_rooms[i]['role_id'] != members[j]['role']) {
              _rooms[i]['role_id'] = members[j]['role'];
              roleChanged = true;
              print('Role updated for member: ${_rooms[i]}');
            }
            break;
          }
        }
      }
    }

    if (roleChanged) {
      notifyListeners(); // Ensure listeners are notified when the role changes
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

  // Future<void> deleteRoom(String roomId) async {
  //   await _apiService.deleteRoom(roomId);
  //   notifyListeners();
  // }

  Future<void> renameRoom(String roomId, String newName) async {
    await _apiService.renameRoom(roomId, newName);
    loadRoomsDB();
    notifyListeners();
  }
}
