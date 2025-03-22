import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/global.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  final String baseUrl = baseurl;
  bool _isLoggedIn = false;
  String? _email;
  String? _token;

  bool get isLoggedIn => _isLoggedIn;
  String? get email => _email;
  String? get token => _token;

  AuthProvider() {
    // Load authentication state from SharedPreferences
    _loadAuthState();
  }

  Future<void> _loadAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    _email = prefs.getString('email');
    _isLoggedIn = _token != null && _email != null;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/user/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _token = data['token'];
      _email = email;
      _isLoggedIn = true;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', _token!);
      await prefs.setString('email', _email!);

      notifyListeners();
    } else {
      throw Exception('Failed to login: ${response.body}');
    }
  }

  Future<void> signup(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/user/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _token = data['token'];
      _email = email;
      _isLoggedIn = true;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', _token!);
      await prefs.setString('email', _email!);

      notifyListeners();
    } else {
      throw Exception('Failed to signup: ${response.body}');
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _isLoggedIn = false;
    _email = null;
    _token = null;
    notifyListeners();
  }

  // This method helps to refresh the auth state when the OverlayAuth changes it
  Future<void> refreshAuthState() async {
    await _loadAuthState();
  }
}
