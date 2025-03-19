import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/navigation_menu.dart';
import 'package:frontend/providers/folder_provider.dart';
import 'package:frontend/providers/room_provider.dart';
import 'package:frontend/providers/file_provider.dart';
import 'package:frontend/providers/paper_provider.dart';
import 'package:frontend/providers/auth_provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => FolderProvider()),
        ChangeNotifierProvider(create: (context) => RoomProvider()),
        ChangeNotifierProvider(create: (context) => FileProvider()),
        ChangeNotifierProvider(create: (context) => PaperProvider()),
        ChangeNotifierProvider(create: (context) => AuthProvider()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  static final GlobalKey<BottomNavigationMenuState> navMenuKey =
      GlobalKey<BottomNavigationMenuState>();

  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notetaking App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: FutureBuilder(
        // Just perform the initial load of auth state
        future:
            Provider.of<AuthProvider>(
              context,
              listen: false,
            ).refreshAuthState(),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          // Always return NavigationMenu, it will handle showing the login overlay
          return NavigationMenu(key: navMenuKey);
        },
      ),
    );
  }
}
