import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/services/overlay_service.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OverlayAuth extends StatefulWidget {
  final VoidCallback onClose;

  const OverlayAuth({super.key, required this.onClose});

  @override
  _OverlayAuthState createState() => _OverlayAuthState();
}

enum AuthState {
  login,
  signup,
  authenticated,
  loginSuccess,
  signupSuccess,
  logoutSuccess,
  signupFailed,
  loginFailed,
}

class _OverlayAuthState extends State<OverlayAuth> {
  bool isLogin = true;
  bool isAuthenticated = false; // Track login state
  String userEmail = ""; // Store logged-in email

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Future<void>? _stateTransitionTimer;

  AuthState currentState = AuthState.login;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  @override
  void dispose() {
    // Cancel any pending timers
    _stateTransitionTimer?.ignore();

    // Dispose controllers
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();

    super.dispose();
  }

  Future<void> authenticate() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      if (isLogin) {
        print('Attempting to login with email: ${emailController.text}');
        await authProvider.login(emailController.text, passwordController.text);

        print('Login attempt completed');
        print('AuthProvider isLoggedIn: ${authProvider.isLoggedIn}');
        print('AuthProvider email: ${authProvider.email}');

        if (!mounted) return;
        setState(() {
          isAuthenticated = authProvider.isLoggedIn;
          userEmail = authProvider.email ?? '';
          currentState = AuthState.loginSuccess;
        });

        print('AuthState email: ${currentState}');

        // Use a cancelable timer
        _stateTransitionTimer = Future.delayed(Duration(seconds: 4), () {
          if (!mounted) return;
          setState(() {
            currentState = AuthState.authenticated;
          });
        });
      } else {
        if (passwordController.text != confirmPasswordController.text) {
          throw Exception('Passwords do not match');
        }

        print('Attempting to signup with email: ${emailController.text}');
        await authProvider.signup(
            emailController.text, passwordController.text);

        print('Signup attempt completed');
        print('AuthProvider isLoggedIn: ${authProvider.isLoggedIn}');
        print('AuthProvider email: ${authProvider.email}');

        if (!mounted) return;
        setState(() {
          // isAuthenticated = authProvider.isLoggedIn;
          // userEmail = authProvider.email ?? '';
          currentState = AuthState.signupSuccess;
        });

        _stateTransitionTimer = Future.delayed(Duration(seconds: 2), () {
          OverlayService.hideOverlay();
        });
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print("Exception: $e");
        print("Stack trace: $stackTrace");
      }
      if (e.toString().contains("Email already registered")) {
        if (!mounted) return;
        setState(() {
          currentState = AuthState.signupFailed;
        });
      }
      _stateTransitionTimer = Future.delayed(Duration(seconds: 2), () {
        OverlayService.hideOverlay();
      });
      if (e.toString().contains("Wrong Password!") ||
          e.toString().contains("mongo: no documents in result")) {
        if (!mounted) return;
        setState(() {
          currentState = AuthState.loginFailed;
        });
      }
      _stateTransitionTimer = Future.delayed(Duration(seconds: 2), () {
        OverlayService.hideOverlay();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  Future<void> checkLoginStatus() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.refreshAuthState();

    if (!mounted) return;
    setState(() {
      isAuthenticated = authProvider.isLoggedIn;
      userEmail = authProvider.email ?? '';
      currentState =
          isAuthenticated ? AuthState.authenticated : AuthState.login;
    });
  }

  void logout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();

    if (!mounted) return;
    setState(() {
      isAuthenticated = false;
      userEmail = "";
      currentState = AuthState.logoutSuccess;
    });

    // Use a cancelable timer
    _stateTransitionTimer = Future.delayed(Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        currentState = AuthState.login;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: Container(color: Colors.black.withOpacity(0.5)),
          ),
        ),
        Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 350,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: buildCurrentView(),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildCurrentView() {
    print('Building View for State: $currentState');

    switch (currentState) {
      case AuthState.authenticated:
        return buildProfileView();
      case AuthState.loginSuccess:
        return buildSuccessView(
            'Login Successful!', Icons.check_circle, Colors.green);
      case AuthState.signupSuccess:
        return buildSuccessView(
            'Signup Successful!', Icons.person_add, Colors.blue);
      case AuthState.logoutSuccess:
        return buildSuccessView('Logout Successful!', Icons.logout, Colors.red);
      case AuthState.signupFailed:
        return buildSuccessView('Signup Failed! This Email already Signup',
            Icons.logout, Colors.red);
      case AuthState.loginFailed:
        return buildSuccessView('Login Failed! Email/Password not correct',
            Icons.logout, Colors.red);
      case AuthState.login:
      case AuthState.signup:
      default:
        return buildAuthView();
    }
  }

  Widget buildSuccessView(String message, IconData icon, Color color) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 80, color: color),
          SizedBox(height: 20),
          Text(
            message,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: color),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 10),
          Text(
            'You will be redirected shortly...',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget buildProfileView() {
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        var prefs = snapshot.data!;
        String name = prefs.getString("name") ?? "Unknown User";
        String email = prefs.getString("email") ?? "";
        String lastLogin = prefs.getString("last_login") ?? "Never";

        return Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_circle, size: 80, color: Colors.blue),
              SizedBox(height: 10),
              Text(
                name,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(email, style: TextStyle(fontSize: 16)),
              Text(
                "Last Login: $lastLogin",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: logout,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text("Logout", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildAuthView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  isLogin ? 'Login' : 'Signup',
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                ),
              ),
              Positioned(
                right: 0,
                top: -15,
                child: IconButton(
                  icon: Icon(Icons.close, color: Colors.black),
                  onPressed: widget.onClose,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  hintText: 'Enter your email',
                  prefixIcon: Icon(Icons.email_outlined, color: Colors.black),
                ),
              ),
              SizedBox(height: 10),
              SizedBox(height: 10),
              TextField(
                controller: passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: 'Enter your password',
                  prefixIcon: Icon(Icons.lock_outline, color: Colors.black),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.black,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),
              if (!isLogin) ...[
                SizedBox(height: 10),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    hintText: 'Confirm your password',
                    prefixIcon: Icon(Icons.lock_outline, color: Colors.black),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.black,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                ),
              ],
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: authenticate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    isLogin ? 'Login' : 'Signup',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isLogin
                        ? 'Don\'t have an account?'
                        : 'Already have an account?',
                    style: TextStyle(color: Colors.black87),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        isLogin = !isLogin;
                      });
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      isLogin ? 'Signup' : 'Login',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
