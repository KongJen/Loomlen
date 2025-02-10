import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dotted_border/dotted_border.dart';
import 'components/Room/room.dart';
import 'components/overlay_setting.dart';
import 'components/overlay_auth.dart';
import 'components/overlay_createRoom.dart';
import 'components/Room/room_provider.dart';
import 'room_page.dart';

class MyRoomPage extends StatefulWidget {
  @override
  State<MyRoomPage> createState() => _MyRoomPageState();
}

class _MyRoomPageState extends State<MyRoomPage> {
  OverlayEntry? _overlayEntry;

  void _toggleOverlay(Widget? overlayWidget) {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    } else if (overlayWidget != null) {
      OverlayState overlayState = Overlay.of(context);
      _overlayEntry = OverlayEntry(builder: (context) => overlayWidget);
      overlayState.insert(_overlayEntry!);
    }
  }

  void showCreateRoomOverlay() {
    _toggleOverlay(
      OverlayCreateRoom(
        onClose: () => _toggleOverlay(null),
        onRoomCreated: () =>
            setState(() {}), // Refresh the page when a new room is added
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomProvider = Provider.of<RoomProvider>(context);
    final rooms = roomProvider.rooms;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(100.0),
        child: AppBar(
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey, width: 1)),
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
                            _toggleOverlay(OverlaySettings(
                                onClose: () => _toggleOverlay(null)));
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.person, color: Colors.black),
                          onPressed: () {
                            _toggleOverlay(OverlayAuth(
                                onClose: () => _toggleOverlay(null)));
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
                itemCount: rooms.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return GestureDetector(
                      onTap: showCreateRoomOverlay,
                      child: Column(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 50.0),
                            child: DottedBorder(
                              borderType: BorderType.RRect,
                              radius: Radius.circular(8.0),
                              dashPattern: [8, 4],
                              color: Colors.blue,
                              strokeWidth: 2,
                              child: Container(
                                width: 100.0,
                                height: 100.0,
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
                    final room = rooms[index - 1];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RoomDetailPage(
                              room: room,
                              onRoomUpdated: () =>
                                  setState(() {}), // Refresh UI
                            ),
                          ),
                        );
                      },
                      child: RoomItem(
                        name: room['name'],
                        createdDate: room['createdDate'],
                        color: (room['color'] is int)
                            ? Color(room['color'])
                            : room['color'],
                        isFavorite: room['isFavorite'],
                        onToggleFavorite: () =>
                            roomProvider.toggleFavorite(room['name']),
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
