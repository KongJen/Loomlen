import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
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
