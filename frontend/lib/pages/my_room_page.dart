import 'package:flutter/material.dart';
import 'components/room.dart';
import 'sample_data.dart';
import 'components/overlay_setting.dart';
import 'components/overlay_auth.dart';

class MyRoomPage extends StatefulWidget {
  @override
  State<MyRoomPage> createState() => _MyRoomPageState();
}

class _MyRoomPageState extends State<MyRoomPage> {
  OverlayEntry? _overlayEntry;

  void toggleFavorite(int index) {
    setState(() {
      sampleData[index]['isFavorite'] = !sampleData[index]['isFavorite'];
    });
  }

  void _showOverlay(BuildContext context, Widget overlayWidget) {
    _removeOverlay(); // Remove existing overlay if open

    OverlayState overlayState = Overlay.of(context)!;
    _overlayEntry = OverlayEntry(builder: (context) => overlayWidget);

    overlayState.insert(_overlayEntry!);
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
                            print("Profile clicked");
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
                itemCount: sampleData.length,
                itemBuilder: (context, index) {
                  final room = sampleData[index];
                  return RoomItem(
                    name: room['name'],
                    createdDate: room['createdDate'],
                    color: room['color'],
                    isFavorite: room['isFavorite'],
                    onToggleFavorite: () => toggleFavorite(index),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
