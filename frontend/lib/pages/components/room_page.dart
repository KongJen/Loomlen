import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class RoomDetailPage extends StatefulWidget {
  final Map<String, dynamic> room;
  final Function? onRoomUpdated;

  const RoomDetailPage({
    Key? key,
    required this.room,
    this.onRoomUpdated,
  }) : super(key: key);

  @override
  _RoomDetailPageState createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends State<RoomDetailPage> {
  late Map<String, dynamic> currentRoom;

  @override
  void initState() {
    super.initState();
    // Create a copy of the room data and ensure color is stored as int
    currentRoom = Map<String, dynamic>.from(widget.room);
    if (currentRoom['color'] is Color) {
      currentRoom['color'] = (currentRoom['color'] as Color).value;
    }
  }

  Future<void> _saveRooms() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/rooms.json');

    List<Map<String, dynamic>> rooms = [];

    if (await file.exists()) {
      final data = jsonDecode(await file.readAsString());
      rooms = List<Map<String, dynamic>>.from(data);

      // Find and update the current room in the list
      final index = rooms.indexWhere((room) =>
          room['name'] == currentRoom['name'] &&
          room['createdDate'] == currentRoom['createdDate']);

      if (index != -1) {
        // Ensure color is stored as int before saving
        Map<String, dynamic> roomToSave =
            Map<String, dynamic>.from(currentRoom);
        if (roomToSave['color'] is Color) {
          roomToSave['color'] = (roomToSave['color'] as Color).value;
        }
        rooms[index] = roomToSave;
      }
    }

    await file.writeAsString(jsonEncode(rooms));
    widget.onRoomUpdated?.call(); // Notify parent to update
  }

  Future<void> toggleFavorite() async {
    setState(() {
      currentRoom['isFavorite'] = !currentRoom['isFavorite'];
    });
    await _saveRooms();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          currentRoom['name'],
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: currentRoom['color'] is int
            ? Color(currentRoom['color'])
            : currentRoom['color'],
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
              currentRoom['isFavorite'] ? Icons.star : Icons.star_border,
              color: Colors.white,
            ),
            onPressed: toggleFavorite,
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              switch (value) {
                case 'rename':
                  // Handle rename
                  break;
                case 'delete':
                  // Handle delete
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(
                value: 'rename',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 20),
                    SizedBox(width: 8),
                    Text('Rename'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 20),
                    SizedBox(width: 8),
                    Text('Delete'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Created on: ${DateTime.parse(currentRoom['createdDate']).toString().split('.')[0]}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 16),
                // Add your room content here
              ],
            ),
          ),
        ],
      ),
    );
  }
}
