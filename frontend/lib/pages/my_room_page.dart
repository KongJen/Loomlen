import 'package:flutter/material.dart';
import 'components/room.dart';
import 'sample_data.dart';

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

  void _showOverlay(BuildContext context) {
    // Remove any existing overlay before adding a new one
    _removeOverlay();

    OverlayState overlayState = Overlay.of(context)!;
    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Background dimming effect
          Positioned.fill(
            child: GestureDetector(
              onTap: _removeOverlay, // Close overlay when tapping outside
              child: Container(
                color: Colors.black.withOpacity(0.5),
              ),
            ),
          ),
          // Centered overlay content
          Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 300,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(10)),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Text(
                              'Settings',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Positioned(
                            top: -17,
                            right: -10,
                            child: IconButton(
                              icon: Icon(Icons.close, color: Colors.black),
                              onPressed: _removeOverlay,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(),
                    ListTile(
                      leading: Icon(Icons.settings),
                      title: Text('General Settings'),
                      onTap: _removeOverlay,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

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
                            _showOverlay(context);
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.person, color: Colors.black),
                          onPressed: () {
                            print("Profile clicked");
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
