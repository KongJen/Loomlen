import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class OverlayAuth extends StatefulWidget {
  final VoidCallback onClose;

  const OverlayAuth({super.key, required this.onClose});

  @override
  // ignore: library_private_types_in_public_api
  _OverlayAuthState createState() => _OverlayAuthState();
}

class _OverlayAuthState extends State<OverlayAuth> {
  bool isLogin = true;
  bool isAuthenticated = false; // Track login state
  String userEmail = ""; // Store logged-in email

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  Future<void> authenticate() async {
    String url =
        isLogin
            ? "http://10.0.2.2:8080/api/user/login"
            : "http://10.0.2.2:8080/api/user/signup";

    // print("Sending request to: $url");
    // print(
    //     "Email: ${emailController.text}, Password: ${passwordController.text}");

    try {
      var response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": emailController.text,
          "password": passwordController.text,
        }),
      );

      // print("Response Status: ${response.statusCode}");
      // print("Response Body: ${response.body}");

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);

        if (data.containsKey("token") && data.containsKey("user")) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString("token", data["token"]);
          await prefs.setString("email", data["user"]["email"]);
          await prefs.setString("name", data["user"]["name"]);
          await prefs.setString("created_at", data["user"]["created_at"]);
          await prefs.setString("last_login", data["user"]["last_login"]);

          setState(() {
            isAuthenticated = true;
            userEmail = data["user"]["email"];
          });

          if (kDebugMode) {
            print("Login successful!");
          }
        }
      } else {
        if (kDebugMode) {
          print("Error: ${response.body}");
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Exception: $e");
      }
    }
  }

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  Future<void> checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("token");
    String? email = prefs.getString("email");

    if (token != null && email != null) {
      setState(() {
        isAuthenticated = true;
        userEmail = email;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            // ignore: deprecated_member_use
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
              child: isAuthenticated ? buildProfileView() : buildAuthView(),
            ),
          ),
        ),
      ],
    );
  }

  void logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    setState(() {
      isAuthenticated = false;
      userEmail = "";
    });
  }

  /// 🔹 **Profile View (After Successful Login)**
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

  /// 🔹 **Login/Signup View**
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
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Enter your password',
                  prefixIcon: Icon(Icons.lock_outline, color: Colors.black),
                ),
              ),
              if (!isLogin) ...[
                SizedBox(height: 10),
                TextField(
                  obscureText: true,
                  controller: confirmPasswordController,
                  decoration: InputDecoration(
                    hintText: 'Confirm your password',
                    prefixIcon: Icon(Icons.lock_outline, color: Colors.black),
                  ),
                ),
              ],
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // print("Login button pressed");
                    authenticate();
                  },
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
