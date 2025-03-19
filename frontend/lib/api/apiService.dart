import 'dart:convert';
import 'package:frontend/global.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  final String baseUrl = baseurl;

  // Get the auth token from shared preferences
  Future<String?> _getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Headers with authorization
  Future<Map<String, String>> _getHeaders() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("token");
    print("Token is : ${token}");
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

      // Log the request payload for debugging
      print('Sharing file payload: ${jsonEncode(payload)}');

      final bodyf = jsonEncode(payload);
      print('Body being sent: $bodyf');

      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString("token");

      final response = await http.post(
        Uri.parse('$baseUrl/api/share'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },

        body: bodyf,
      );
      print('Response status code: ${response.statusCode}');
      print('respond Header: ${response.headers}');
      print('respond body : ${response.body}');

      // Check for error status codes
      if (response.statusCode >= 400) {
        print('Server error: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception('Server error: ${response.statusCode}');
      }

      if (response.body.isEmpty) {
        print('Warning: Empty response body');
        return {'message': 'Operation completed but server returned no data'};
      }

      // Try to parse the response
      try {
        return jsonDecode(response.body);
      } catch (e) {
        print('JSON parsing error: $e');
        print('Response body: ${response.body}');
        throw Exception('Invalid response format');
      }
    } catch (e) {
      print('Error in shareFile: $e');
      rethrow;
    }
  }

  // Get files shared with the user
  Future<List<Map<String, dynamic>>> getSharedFiles() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/shared'),
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
