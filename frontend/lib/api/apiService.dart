import 'dart:convert';
import 'package:frontend/global.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  final String baseUrl = baseurl;

  // Get the auth token from shared preferences
  Future<String?> _getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // Headers with authorization
  Future<Map<String, String>> _getHeaders() async {
    String? token = await _getToken();
    print("Token is : $token");
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Share a file with other users
  Future<dynamic> shareFile({
    required String fileId,
    required List<String> sharedWith,
    required String permission,
    required List<dynamic> fileContent,
    required List<dynamic> paperData,
    required String name,
  }) async {
    try {
      // Convert the data to JSON strings
      final Map<String, dynamic> payload = {
        'fileId': fileId,
        'sharedWith': sharedWith,
        'permission': permission,
        'fileContent': fileContent, // Convert to JSON string
        'paperData': paperData, // Convert to JSON string
        'name': name,
      };

      final bodyf = jsonEncode(payload);

      final headers = await _getHeaders();

      final response = await http.post(
        Uri.parse('$baseUrl/api/shared'),
        headers: headers,
        body: bodyf,
      );

      // Check for error status codes
      if (response.statusCode >= 400) {
        throw Exception('Server error: ${response.statusCode}');
      }

      if (response.body.isEmpty) {
        return {'message': 'Operation completed but server returned no data'};
      }

      // Try to parse the response
      try {
        return jsonDecode(response.body);
      } catch (e) {
        throw Exception('Invalid response format');
      }
    } catch (e) {
      print('Error in shareFile: $e');
      rethrow;
    }
  }

  // Share a file with other users
  Future<dynamic> shareRoom({
    required String roomId,
    required String name,
    required int color,
  }) async {
    try {
      // Convert the data to JSON strings
      final Map<String, dynamic> payload = {
        'room_id': roomId,
        'name': name,
        'color': color,
      };

      final bodyf = jsonEncode(payload);

      final headers = await _getHeaders();

      final response = await http.post(
        Uri.parse('$baseUrl/api/room'),
        headers: headers,
        body: bodyf,
      );

      // Check for error status codes
      if (response.statusCode >= 400) {
        throw Exception('Server error: ${response.statusCode}');
      }

      if (response.body.isEmpty) {
        return {'message': 'Operation completed but server returned no data'};
      }

      // Try to parse the response
      try {
        return jsonDecode(response.body);
      } catch (e) {
        throw Exception('Invalid response format');
      }
    } catch (e) {
      print('Error in shareFile: $e');
      rethrow;
    }
  }

  Future<dynamic> addFolder({
    required String id,
    required String roomId,
    required String subFolderId,
    required String name,
    required int color,
  }) async {
    try {
      // Convert the data to JSON strings
      final Map<String, dynamic> payload = {
        'folder_id': id,
        'room_id': roomId,
        'sub_folder_id': subFolderId,
        'name': name,
        'color': color,
      };

      final bodyf = jsonEncode(payload);

      final response = await http.post(
        Uri.parse('$baseUrl/api/folder'),
        body: bodyf,
      );

      // Check for error status codes
      if (response.statusCode >= 400) {
        throw Exception('Server error: ${response.statusCode}');
      }

      if (response.body.isEmpty) {
        return {'message': 'Operation completed but server returned no data'};
      }

      // Try to parse the response
      try {
        return jsonDecode(response.body);
      } catch (e) {
        throw Exception('Invalid response format');
      }
    } catch (e) {
      print('Error in addFolder: $e');
      rethrow;
    }
  }

  Future<dynamic> addFile({
    required String id,
    required String roomId,
    required String subFolderId,
    required String name,
  }) async {
    try {
      // Convert the data to JSON strings
      final Map<String, dynamic> payload = {
        'file_id': id,
        'room_id': roomId,
        'sub_folder_id': subFolderId,
        'name': name,
      };

      final bodyf = jsonEncode(payload);

      final response = await http.post(
        Uri.parse('$baseUrl/api/file'),
        body: bodyf,
      );

      // Check for error status codes
      if (response.statusCode >= 400) {
        throw Exception('Server error: ${response.statusCode}');
      }

      if (response.body.isEmpty) {
        return {'message': 'Operation completed but server returned no data'};
      }

      // Try to parse the response
      try {
        final data = jsonDecode(response.body);
        return data["file_id"];
      } catch (e) {
        throw Exception('Invalid response format');
      }
    } catch (e) {
      print('Error in addFolder: $e');
      rethrow;
    }
  }

  Future<dynamic> addPaper(
      {required String id,
      required String roomId,
      required String fileId,
      required String templateId,
      required int pageNumber,
      required double width,
      required double height}) async {
    try {
      // Convert the data to JSON strings
      final Map<String, dynamic> payload = {
        'paper_id': id,
        'room_id': roomId,
        'file_id': fileId,
        'template_id': templateId,
        'page_number': pageNumber,
        'width': width,
        'height': height,
      };

      final bodyf = jsonEncode(payload);

      final response = await http.post(
        Uri.parse('$baseUrl/api/paper'),
        body: bodyf,
      );

      // Check for error status codes
      if (response.statusCode >= 400) {
        throw Exception('Server error: ${response.statusCode}');
      }

      if (response.body.isEmpty) {
        return {'message': 'Operation completed but server returned no data'};
      }

      // Try to parse the response
      try {
        final data = jsonDecode(response.body);
        return data["paper_id"];
      } catch (e) {
        throw Exception('Invalid response format');
      }
    } catch (e) {
      print('Error in addPaper: $e');
      rethrow;
    }
  }

  // Share a file with other users
  Future<dynamic> shareMember({
    required String roomId,
    required List<String> sharedWith,
    required String permission,
  }) async {
    try {
      // Convert the data to JSON strings
      final Map<String, dynamic> payload = {
        'room_id': roomId,
        'email': sharedWith,
        'role_id': permission,
      };

      final bodyf = jsonEncode(payload);

      final headers = await _getHeaders();

      final response = await http.post(
        Uri.parse('$baseUrl/api/roomMember'),
        headers: headers,
        body: bodyf,
      );

      // Check for error status codes
      if (response.statusCode >= 400) {
        throw Exception('Server error: ${response.statusCode}');
      }

      if (response.body.isEmpty) {
        return {'message': 'Operation completed but server returned no data'};
      }

      // Try to parse the response
      try {
        return jsonDecode(response.body);
      } catch (e) {
        throw Exception('Invalid response format');
      }
    } catch (e) {
      print('Error in shareFile: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getRooms() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/room'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data.cast<Map<String, dynamic>>();
      } else {
        return []; // Return an empty list if data is not a list
      }
    } else {
      throw Exception('Failed to get shared rooms: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> toggleFav(roomId) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/api/room'),
      headers: headers,
      body: jsonEncode({"room_id": roomId}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to toggle favorite: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> updateDraw(
    String paperId,
    List<Map<String, dynamic>> drawingData,
  ) async {
    print("Drawing to db: $drawingData");
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/api/drawing'),
      headers: headers,
      body: jsonEncode({
        'paper_id': paperId,
        'drawing_data': drawingData,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update drawing: ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> getFolders(String roomId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/folder')
          .replace(queryParameters: {"room_id": roomId}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data.map((item) => item as Map<String, dynamic>).toList();
      } else {
        return []; // Return an empty list if data is not a list
      }
    } else {
      throw Exception('Failed to get folders: ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> getFile(String roomId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/file')
          .replace(queryParameters: {"room_id": roomId}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data.map((item) => item as Map<String, dynamic>).toList();
      } else {
        return []; // Return an empty list if data is not a list
      }
    } else {
      throw Exception('Failed to get folders: ${response.body}');
    }
  }

  Future<String> getFileIdByOrigin(String originalId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/file/id')
          .replace(queryParameters: {"original_id": originalId}),
    );

    if (response.statusCode == 200) {
      return response.body.trim(); // Trim to remove any extra whitespace
    } else {
      throw Exception('Failed to get file ID: ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> getPaper(String roomId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/paper')
          .replace(queryParameters: {"room_id": roomId}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // print("data: $data");
      if (data is List) {
        return data.map((item) {
          return Map<String, dynamic>.from(item)
            ..addAll({
              "width": (item["width"] as num?)?.toDouble() ?? 595.0,
              "height": (item["height"] as num?)?.toDouble() ?? 842.0,
            });
        }).toList();
      } else {
        return []; // Return an empty list if data is not a list
      }
    } else {
      throw Exception('Failed to get files: ${response.body}');
    }
  }

  // Get files shared with the user
  Future<List<Map<String, dynamic>>> getSharedFiles() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/shared'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to get shared files: ${response.body}');
    }
  }

  // Clone a shared file
  Future<Map<String, dynamic>> cloneSharedFile(String sharedFileId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/shared/$sharedFileId/clone'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to clone file: ${response.body}');
    }
  }
}
