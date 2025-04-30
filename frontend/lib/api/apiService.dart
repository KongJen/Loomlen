import 'dart:convert';
import 'package:frontend/global.dart';
import 'package:frontend/items/drawingpoint_item.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

class ApiService {
  final String baseUrl = baseurl;

  Future<String?> _getAccessToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  // Get the refresh token from shared preferences
  Future<String?> _getRefreshToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }

  // Headers with authorization
  Future<Map<String, String>> _getHeaders() async {
    String? token = await _getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<bool> _refreshTokens() async {
    try {
      String? refreshToken = await _getRefreshToken();
      print("object refreshToken: $refreshToken");
      if (refreshToken == null) return false;

      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Save new tokens to shared preferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', data['access_token']);

        // Save new refresh token if provided
        if (data.containsKey('refresh_token')) {
          await prefs.setString('refresh_token', data['refresh_token']);
        }

        return true;
      }
      if (response.statusCode == 401) {
        // Handle token expiration or invalid refresh token
        print('Refresh token expired or invalid');
      }
      return false;
    } catch (e) {
      print('Error refreshing token: $e');
      return false;
    }
  }

  // Custom HTTP request with automatic token refresh
  Future<http.Response> authenticatedRequest(
    String url, {
    String method = 'GET',
    Map<String, String>? headers,
    Object? body,
  }) async {
    headers = headers ?? {};
    String? token = await _getAccessToken();
    headers['Authorization'] = 'Bearer $token';

    http.Response response;

    // Function to make the actual request
    Future<http.Response> makeRequest() async {
      switch (method) {
        case 'GET':
          return await http.get(Uri.parse(url), headers: headers);
        case 'POST':
          return await http.post(Uri.parse(url), headers: headers, body: body);
        case 'PUT':
          return await http.put(Uri.parse(url), headers: headers, body: body);
        case 'DELETE':
          return await http.delete(Uri.parse(url),
              headers: headers, body: body);
        default:
          throw Exception('Unsupported HTTP method: $method');
      }
    }

    // Make the initial request
    response = await makeRequest();

    // If we get a 401 (Unauthorized), try to refresh the token and retry
    if (response.statusCode == 401) {
      bool refreshed = await _refreshTokens();
      if (refreshed) {
        // Update authorization header with new token
        token = await _getAccessToken();
        headers['Authorization'] = 'Bearer $token';
        // Retry the request
        response = await makeRequest();
      }
    }

    return response;
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

      final response = await authenticatedRequest('$baseUrl/api/shared',
          method: 'POST', headers: headers, body: bodyf);

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

      final response = await authenticatedRequest(
        '$baseUrl/api/room',
        method: 'POST',
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
        final responseData = jsonDecode(response.body);
        return responseData['id'];
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
    String? subFolderId,
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

      print("payload = ${bodyf}");

      final response = await authenticatedRequest('$baseUrl/api/folder',
          method: 'POST',
          body: bodyf,
          headers: {'Content-Type': 'application/json'});

      // Check for error status codes
      if (response.statusCode >= 400) {
        throw Exception('Server error: ${response.statusCode}');
      }

      if (response.body.isEmpty) {
        return {'message': 'Operation completed but server returned no data'};
      }

      // Try to parse the response
      try {
        final responseData = jsonDecode(response.body);
        print("reponse Add file ID : ${responseData['folder_id']}");
        return responseData['folder_id'];
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

      final response = await authenticatedRequest(
        '$baseUrl/api/file',
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
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
        print("File_id : ${data["file_id"]} Shared!");
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

      final response = await authenticatedRequest('$baseUrl/api/paper',
          method: 'POST',
          body: bodyf,
          headers: {'Content-Type': 'application/json'});

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

  Future<void> renameRoom(String roomId, String name) async {
    try {
      final response = await authenticatedRequest(
        '$baseUrl/api/room/name',
        method: 'PUT',
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"room_id": roomId, "name": name}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to rename room: ${response.body}');
      }
    } catch (e) {
      print('Error in renameRoom: $e');
      rethrow;
    }
  }

  Future<void> renameFolder(
    String folderId,
    String name,
  ) async {
    try {
      final response = await authenticatedRequest(
        '$baseUrl/api/folder/name',
        method: 'PUT',
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"folder_id": folderId, "name": name}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to rename folder: ${response.body}');
      }
    } catch (e) {
      print('Error in renameFolder: $e');
      rethrow;
    }
  }

  Future<void> renameFile(
    String fileId,
    String name,
  ) async {
    try {
      final response = await authenticatedRequest(
        '$baseUrl/api/file/name',
        method: 'PUT',
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"file_id": fileId, "name": name}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to rename file: ${response.body}');
      }
    } catch (e) {
      print('Error in renameFile: $e');
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

      print("roomID MEMBER : ${roomId}");

      final bodyf = jsonEncode(payload);

      final headers = await _getHeaders();

      final response = await authenticatedRequest(
        '$baseUrl/api/roomMember',
        method: 'POST',
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
    final response = await authenticatedRequest(
      '$baseUrl/api/room',
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data.cast<Map<String, dynamic>>();
      } else {
        return [];
      }
    } else {
      throw Exception('Failed to get shared rooms: ${response.body}');
    }
  }

  Future<String> getRoomID(String originalID) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/room/id')
          .replace(queryParameters: {"original_id": originalID}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["room_id"];
    } else {
      throw Exception('Failed to get roomID: ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> getMembersInRoom(roomId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/roomMember')
          .replace(queryParameters: {"room_id": roomId}),
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

  Future<List<Map<String, dynamic>>> updateMemberRole(
      String room_id, List<Map<String, dynamic>> members) async {
    final response = await authenticatedRequest(
      '$baseUrl/api/roomMember',
      method: 'PUT',
      body: jsonEncode({"room_id": room_id, "members": members}),
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
    final response = await authenticatedRequest(
      '$baseUrl/api/room',
      method: 'PUT',
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
    List<DrawingPoint>
        drawingData, // Assuming drawingData is a List of DrawingPoint objects
  ) async {
    print("Drawing to db: $drawingData");

    // Convert the drawing data to the correct format
    List<Map<String, dynamic>> formattedDrawingData = drawingData.map((point) {
      return {
        'type': 'drawing',
        'data': {
          'id': point.id,
          'offsets': point.offsets
              .map((offset) => {
                    'x': offset.dx,
                    'y': offset.dy,
                  })
              .toList(),
          'color': point.color.value, // Assuming 'color' is a Color object
          'width': point.width,
          'tool': point.tool
              .toString()
              .split('.')
              .last, // Get the tool name as a string
        },
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
    }).toList();

    final response = await authenticatedRequest(
      '$baseUrl/api/paper/drawing',
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        'paper_id': paperId,
      },
      body: jsonEncode(formattedDrawingData),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update drawing: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> addDraw(
    String paperId,
    List<dynamic>
        drawingData, // Assuming drawingData is a List of DrawingPoint objects
  ) async {
    print("Drawing to db: $drawingData");

    final response = await authenticatedRequest(
      '$baseUrl/api/paper/drawing',
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        'paper_id': paperId,
      },
      body: jsonEncode(drawingData),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update drawing: ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> getFolders(String roomId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/folder')
            .replace(queryParameters: {"room_id": roomId}),
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');
      print('RoomID Response: ${roomId}');

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          print('Received empty response');
          return [];
        }

        try {
          final List<dynamic> decodedBody = jsonDecode(response.body);

          return decodedBody
              .map((item) => item is Map<String, dynamic>
                  ? item
                  : throw FormatException('Invalid folder item format'))
              .toList();
        } on FormatException catch (e) {
          print('JSON parsing error: $e');
          return [];
        }
      } else {
        // More informative error handling
        print('Failed to get folders. Status code: ${response.statusCode}');
        print('Error body: ${response.body}');
        throw Exception('Failed to get folders: ${response.body}');
      }
    } catch (e) {
      print('Unexpected error in getFolders: $e');
      rethrow;
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

  Future<void> deleteMember(String roomId, String email) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/api/roomMember'),
      headers: headers,
      body: jsonEncode({"room_id": roomId, "email": email}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete member: ${response.body}');
    }
  }

  Future<void> deleteRoom(String roomId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/room'),
      body: jsonEncode({"room_id": roomId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete room: ${response.body}');
    }
  }

  Future<void> deleteFolder(String folderId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/folder'),
      body: jsonEncode({"folder_id": folderId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete folder: ${response.body}');
    }
  }

  Future<void> deleteFile(String fileId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/file'),
      body: jsonEncode({"file_id": fileId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete file: ${response.body}');
    }
  }

  Future<void> deletePaper(String paperId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/paper'),
      body: jsonEncode({"paper_id": paperId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete paper: ${response.body}');
    }
  }

  // Get files shared with the user
  Future<List<Map<String, dynamic>>> getSharedFiles() async {
    final headers = await _getHeaders();
    final response = await authenticatedRequest(
      '$baseUrl/api/shared',
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
    final response = await authenticatedRequest(
      '$baseUrl/shared/$sharedFileId/clone',
      headers: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to clone file: ${response.body}');
    }
  }
}
