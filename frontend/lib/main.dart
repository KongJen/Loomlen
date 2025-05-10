import 'package:flutter/material.dart';
import 'package:frontend/providers/filedb_provider.dart';
import 'package:frontend/providers/folderdb_provider.dart';
import 'package:frontend/providers/paperdb_provider.dart';
import 'package:frontend/providers/roomdb_provider.dart';
import 'package:provider/provider.dart';
import 'package:frontend/navigation_menu.dart';
import 'package:frontend/providers/folder_provider.dart';
import 'package:frontend/providers/room_provider.dart';
import 'package:frontend/providers/file_provider.dart';
import 'package:frontend/providers/paper_provider.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/global.dart';
import 'package:frontend/api/discoverBackend.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  BackendDiscovery backendDiscovery = BackendDiscovery();
  baseurl = await backendDiscovery.getBackendUrl();

  print("Initial baseurl is: $baseurl");

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => FolderProvider()),
        ChangeNotifierProvider(create: (context) => RoomProvider()),
        ChangeNotifierProvider(create: (context) => RoomDBProvider()),
        ChangeNotifierProvider(create: (context) => FolderDBProvider()),
        ChangeNotifierProvider(create: (context) => FileProvider()),
        ChangeNotifierProvider(create: (context) => FileDBProvider()),
        ChangeNotifierProvider(create: (context) => PaperProvider()),
        ChangeNotifierProvider(create: (context) => PaperDBProvider()),
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
        future: Provider.of<AuthProvider>(
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
