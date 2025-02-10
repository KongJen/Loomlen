import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'components/folder.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dotted_border/dotted_border.dart';
import 'components/overlay_createFolder.dart';

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
  OverlayEntry? _overlayEntry;
  List<Map<String, dynamic>> folders = [];

  @override
  void initState() {
    super.initState();
    _loadFolders();
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

  void _loadFolders() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/folders.json');

    if (await file.exists()) {
      final data = jsonDecode(await file.readAsString());

      setState(() {
        folders = List<Map<String, dynamic>>.from(data).map((folder) {
          return {
            'name': folder['name'],
            'createdDate': folder['createdDate'],
            'color': (folder['color'] is int)
                ? Color(folder['color'])
                : folder['color'], // Convert int back to Color
            'isFavorite': folder['isFavorite'],
          };
        }).toList();
      });
    }
  }

  void _saveFolders() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/folders.json');

    List<Map<String, dynamic>> foldersToSave = folders.map((folder) {
      return {
        'name': folder['name'],
        'createdDate': folder['createdDate'],
        'color': (folder['color'] is Color)
            ? (folder['color'] as Color).value // Convert Color to int
            : folder['color'], // Already an int, no need to convert
        'isFavorite': folder['isFavorite'],
      };
    }).toList();

    await file.writeAsString(jsonEncode(foldersToSave));
  }

  void _createFolder() {
    setState(() {
      folders.add({
        'name': 'Room ${folders.length + 1}',
        'createdDate': DateTime.now().toString(),
        'color': Colors.primaries[folders.length % Colors.primaries.length]
            .value, // Store color as int
        'isFavorite': false,
      });
      _saveRooms();
    });
  }

  void toggleFavoriteFolder(int index) {
    setState(() {
      folders[index]['isFavorite'] = !folders[index]['isFavorite'];
      _saveFolders();
    });
  }

  void _showOverlay(BuildContext context, Widget overlayWidget) {
    _removeOverlay();
    OverlayState overlayState = Overlay.of(context)!;
    _overlayEntry = OverlayEntry(builder: (context) => overlayWidget);
    overlayState.insert(_overlayEntry!);
  }

  void showCreateFolderOverlay() {
    showDialog(
      context: context,
      builder: (context) => OverlayCreateFolder(
        onClose: () => Navigator.pop(context),
        onRoomCreated: () {
          // Reload the rooms list
          _loadFolders();
        },
      ),
    );
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
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
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(2.0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  crossAxisSpacing: 1.0,
                  mainAxisSpacing: 16.0,
                  childAspectRatio: 1,
                ),
                itemCount: folders.length + 1, // +1 for the extra "New" item
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // First item with dashed border
                    return GestureDetector(
                      onTap: showCreateFolderOverlay, // Call overlay function
                      child: Column(
                        children: [
                          // Fixed size container with dashed border
                          Container(
                            margin: const EdgeInsets.only(top: 50.0),
                            child: DottedBorder(
                              borderType: BorderType.RRect,
                              radius: Radius.circular(8.0),
                              dashPattern: [
                                8,
                                4
                              ], // Dashes with 8px length and 4px spacing
                              color: Colors.blue,
                              strokeWidth: 2,
                              child: Container(
                                width: 100.0, // Set width
                                height: 100.0, // Set height
                                alignment: Alignment.center,
                                child: const Icon(Icons.add,
                                    size: 32, color: Colors.blue),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text("New",
                              style: TextStyle(color: Colors.blue)),
                        ],
                      ),
                    );
                  } else {
                    // Normal room items
                    final folder = folders[index -
                        1]; // Adjust index since we added one extra item
                    return GestureDetector(
                      onTap: () {},
                      child: FolderItem(
                        name: folder['name'],
                        createdDate: folder['createdDate'],
                        color: folder['color'],
                        isFavorite: folder['isFavorite'],
                        onToggleFavorite: () => toggleFavoriteFolder(index - 1),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
