import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/navigation_menu.dart';
import 'package:frontend/model/provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => FolderProvider()),
        ChangeNotifierProvider(create: (context) => RoomProvider()),
        ChangeNotifierProvider(create: (context) => FileProvider()),
        ChangeNotifierProvider(create: (context) => PaperProvider()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notetaking App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const NavigationMenu(),
    );
  }
}
