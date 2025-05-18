import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/global.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthProvider with ChangeNotifier {
  final String baseUrl = baseurl;
  bool _isLoggedIn = false;
  String? _email;
  String? _userId;
  String? _name;
  String? _accessToken;
  String? _refreshToken;

  bool get isLoggedIn => _isLoggedIn;
  String? get email => _email;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  String? get name => _name;

  AuthProvider() {
    // Load authentication state from SharedPreferences
    _loadAuthState();
  }

  Future<void> _loadAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    _refreshToken = prefs.getString('refresh_token');
    _email = prefs.getString('email');
    _isLoggedIn =
        _accessToken != null && _refreshToken != null && _email != null;
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google sign-in aborted');
      }
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      // Send idToken to your backend and get tokens/user info
      final response = await http.post(
        Uri.parse('$baseUrl/api/user/google-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_token': idToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];
        _email = data['user']['email'];
        _name = data['user']['name'];
        _userId = data['user']['_id'] ?? data['user']['id'];
        _isLoggedIn = true;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', _accessToken!);
        await prefs.setString('refresh_token', _refreshToken!);
        await prefs.setString('email', _email!);
        await prefs.setString('user_id', _userId!);
        await prefs.setString('name', _name ?? "");
        await prefs.setString('last_login', DateTime.now().toIso8601String());
        if (googleUser.photoUrl != null) {
          await prefs.setString("photo_url", googleUser.photoUrl!);
        }

        notifyListeners();
      } else {
        throw Exception('Google login failed: ${response.body}');
      }
    } catch (e) {
      print('Google sign-in error: $e');
      rethrow;
    }
  }

  Future<void> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/user/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _accessToken = data['access_token'];
      _refreshToken = data['refresh_token'];
      _email = email;
      _userId = data['user']['_id'] ?? data['user']['id'];
      _isLoggedIn = true;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', _accessToken!);
      await prefs.setString('refresh_token', _refreshToken!);
      await prefs.setString('email', _email!);
      await prefs.setString('user_id', _userId!);

      notifyListeners();
      print("Access token received: $_accessToken");
    } else {
      throw Exception('Failed to login: ${response.body}');
    }
  }

  Future<void> signup(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/user/signup'),
      body: jsonEncode({'email': email, 'password': password, 'name': ""}),
    );

    if (response.statusCode == 200) {
      _email = email;
      // _name = name;
      _isLoggedIn = true;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('email', _email!);
      // await prefs.setString('email', _name!);

      notifyListeners();
    } else {
      throw Exception('Failed to signup: ${response.body}');
    }
  }

  Future<bool> refreshTokens() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refresh_token');

    if (refreshToken == null) {
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'];
        _refreshToken = data[
            'refresh_token']; // In case backend also refreshes the refresh token

        await prefs.setString('access_token', _accessToken!);
        await prefs.setString('refresh_token', _refreshToken!);

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Error refreshing token: $e');
      return false;
    }
  }

  Future<http.Response> authenticatedRequest(
    String url, {
    String method = 'GET',
    Map<String, String>? headers,
    Object? body,
  }) async {
    headers = headers ?? {};
    headers['Authorization'] = 'Bearer $_accessToken';

    http.Response response;

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

    response = await makeRequest();

    if (response.statusCode == 401) {
      final refreshed = await refreshTokens();
      if (refreshed) {
        headers['Authorization'] = 'Bearer $_accessToken';
        response = await makeRequest();
      }
    }

    return response;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');

    try {
      await googleSignIn.signOut();
    } catch (e) {
      print('Error signing out from Google: $e');
    }

    if (accessToken != null) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/api/user/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
        );

        if (response.statusCode == 200) {
          // Successfully logged out from server, now clear local data
          await prefs.remove('access_token');
          await prefs.remove('refresh_token');
          await prefs.remove('user_id');
          await prefs.remove('email');
          await prefs.remove('name');
          await prefs.remove('last_login');

          _accessToken = null;
          _refreshToken = null;
          _userId = null;
          _email = null;
          _isLoggedIn = false;

          notifyListeners();
        } else {
          // Handle server error
          print('Logout failed: ${response.body}');
          throw Exception('Failed to logout');
        }
      } catch (e) {
        // Handle network errors
        print('Network error during logout: $e');

        // Even if the server request fails, clear local data for security
        await prefs.remove('access_token');
        await prefs.remove('refresh_token');
        await prefs.remove('user_id');
        await prefs.remove('email');
        await prefs.remove('name');
        await prefs.remove('last_login');

        _accessToken = null;
        _refreshToken = null;
        _userId = null;
        _email = null;
        _isLoggedIn = false;

        notifyListeners();
        throw e;
      }
    } else {
      // No token found, just clear state
      _accessToken = null;
      _refreshToken = null;
      _userId = null;
      _email = null;
      _isLoggedIn = false;
      notifyListeners();
    }
  }

  // This method helps to refresh the auth state when the OverlayAuth changes it
  Future<void> refreshAuthState() async {
    await _loadAuthState();
  }
}
