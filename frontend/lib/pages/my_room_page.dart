import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'components/room.dart';
import 'package:dotted_border/dotted_border.dart';
import 'components/overlay_setting.dart';
import 'components/overlay_auth.dart';
import 'components/overlay_createRoom.dart';
import 'components/room_page.dart';

class MyRoomPage extends StatefulWidget {
  @override
  State<MyRoomPage> createState() => _MyRoomPageState();
}

class _MyRoomPageState extends State<MyRoomPage> {
  OverlayEntry? _overlayEntry;
  List<Map<String, dynamic>> rooms = [];

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  void _loadRooms() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/rooms.json');

    if (await file.exists()) {
      final data = jsonDecode(await file.readAsString());

      setState(() {
        rooms = List<Map<String, dynamic>>.from(data).map((room) {
          return {
            'name': room['name'],
            'createdDate': room['createdDate'],
            'color': (room['color'] is int)
                ? Color(room['color'])
                : room['color'], // Convert int back to Color
            'isFavorite': room['isFavorite'],
          };
        }).toList();
      });
    }
  }

  void _saveRooms() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/rooms.json');

    List<Map<String, dynamic>> roomsToSave = rooms.map((room) {
      return {
        'name': room['name'],
        'createdDate': room['createdDate'],
        'color': (room['color'] is Color)
            ? (room['color'] as Color).value // Convert Color to int
            : room['color'], // Already an int, no need to convert
        'isFavorite': room['isFavorite'],
      };
    }).toList();

    await file.writeAsString(jsonEncode(roomsToSave));
  }

  void _createRoom() {
    setState(() {
      rooms.add({
        'name': 'Room ${rooms.length + 1}',
        'createdDate': DateTime.now().toString(),
        'color': Colors.primaries[rooms.length % Colors.primaries.length]
            .value, // Store color as int
        'isFavorite': false,
      });
      _saveRooms();
    });
  }

  void toggleFavorite(int index) {
    setState(() {
      rooms[index]['isFavorite'] = !rooms[index]['isFavorite'];
      _saveRooms();
    });
  }

  void _showOverlay(BuildContext context, Widget overlayWidget) {
    _removeOverlay();
    OverlayState overlayState = Overlay.of(context)!;
    _overlayEntry = OverlayEntry(builder: (context) => overlayWidget);
    overlayState.insert(_overlayEntry!);
  }

  void showCreateRoomOverlay() {
    showDialog(
      context: context,
      builder: (context) => OverlayCreateRoom(
        onClose: () => Navigator.pop(context),
        onRoomCreated: () {
          // Reload the rooms list
          _loadRooms();
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
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(100.0),
        child: AppBar(
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey, width: 1),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top,
                left: 60,
                right: 16,
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 35,
                    left: 0,
                    child: Text(
                      'My Room',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 16,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.select_all, color: Colors.black),
                          onPressed: () {
                            print("Select clicked");
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.settings, color: Colors.black),
                          onPressed: () {
                            _showOverlay(context,
                                OverlaySettings(onClose: _removeOverlay));
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.person, color: Colors.black),
                          onPressed: () {
                            _showOverlay(
                                context, OverlayAuth(onClose: _removeOverlay));
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
                itemCount: rooms.length + 1, // +1 for the extra "New" item
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // First item with dashed border
                    return GestureDetector(
                      onTap: showCreateRoomOverlay, // Call overlay function
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
                    final room = rooms[index -
                        1]; // Adjust index since we added one extra item
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RoomDetailPage(
                              room: room,
                              onRoomUpdated: () {
                                _loadRooms();
                              },
                            ),
                          ),
                        );
                      },
                      child: RoomItem(
                        name: room['name'],
                        createdDate: room['createdDate'],
                        color: room['color'],
                        isFavorite: room['isFavorite'],
                        onToggleFavorite: () => toggleFavorite(index - 1),
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
