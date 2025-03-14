import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dotted_border/dotted_border.dart';
import '../OBJ/object.dart';
import '../widget/overlay_setting.dart';
import '../widget/overlay_auth.dart';
import '../widget/overlay_create_room.dart';
import '../model/provider.dart';
import 'room_page.dart';

class MyRoomPage extends StatefulWidget {
  const MyRoomPage({super.key});

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
    _toggleOverlay(OverlayCreateRoom(onClose: () => _toggleOverlay(null)));
  }

  // Get the appropriate number of grid columns based on screen width
  int _getCrossAxisCount(double width) {
    if (width < 600) return 2;
    if (width < 900) return 3;
    if (width < 1200) return 4;
    if (width < 1500) return 5;
    return 6;
  }

  @override
  Widget build(BuildContext context) {
    final roomProvider = Provider.of<RoomProvider>(context);
    final rooms = roomProvider.rooms;
    final screenSize = MediaQuery.of(context).size;
    final crossAxisCount = _getCrossAxisCount(screenSize.width);

    // Calculate consistent sizes for all items
    final itemSize = screenSize.width < 600 ? 120.0 : 170.0;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(screenSize.height * 0.12),
        child: AppBar(
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey, width: 1)),
            ),
            child: Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top,
                left: screenSize.width * 0.05,
                right: 16,
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: screenSize.height * 0.04,
                    left: 0,
                    child: Text(
                      'My Room',
                      style: TextStyle(
                        fontSize: screenSize.width < 600 ? 30 : 40,
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
                          icon: const Icon(
                            Icons.select_all,
                            color: Colors.black,
                          ),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings, color: Colors.black),
                          onPressed: () {
                            _toggleOverlay(
                              OverlaySettings(
                                onClose: () => _toggleOverlay(null),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.person, color: Colors.black),
                          onPressed: () {
                            _toggleOverlay(
                              OverlayAuth(onClose: () => _toggleOverlay(null)),
                            );
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
        padding: EdgeInsets.all(screenSize.width / 10000),
        child: Column(
          children: [
            Expanded(
              child: GridView.builder(
                padding: EdgeInsets.all(screenSize.width / 10000),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 10.0,
                  mainAxisSpacing: 16.0,
                  childAspectRatio: 0.8,
                ),
                itemCount: rooms.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // Create Room button - with consistent height and alignment
                    return GestureDetector(
                      onTap: showCreateRoomOverlay,
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center, // Center vertically
                        children: [
                          SizedBox(
                            height: itemSize, // Match the height of room icons
                            child: Center(
                              child: DottedBorder(
                                borderType: BorderType.RRect,
                                radius: const Radius.circular(8.0),
                                dashPattern: const [8, 4],
                                color: Colors.blue,
                                strokeWidth: 2,
                                child: Container(
                                  width: itemSize * 0.65,
                                  height: itemSize * 0.65,
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.add,
                                    size: itemSize * 0.2,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "New",
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(
                            height: 12,
                          ), // Match spacing of room items
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
                            builder:
                                (context) => RoomDetailPage(
                                  room: room,
                                  onRoomUpdated: () => setState(() {}),
                                ),
                          ),
                        );
                      },
                      child: RoomItem(
                        id: room['id'],
                        name: room['name'],
                        createdDate: room['createdDate'],
                        color:
                            (room['color'] is int)
                                ? Color(room['color'])
                                : room['color'],
                        isFavorite: room['isFavorite'],
                        folderIds: room['folderIds'] ?? [],
                        fileIds: room['fileIds'] ?? [],
                        onToggleFavorite:
                            () => roomProvider.toggleFavorite(room['name']),
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
