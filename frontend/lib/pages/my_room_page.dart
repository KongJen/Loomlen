import 'package:flutter/material.dart';
import 'package:frontend/widget/app_bar.dart';
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';
import '../widget/grid_layout.dart';
import '../widget/ui_component.dart';
import '../services/overlay_service.dart';
import '../items/room_item.dart';
import '../widget/overlay_create_room.dart';
import 'room_page.dart';

class MyRoomPage extends StatefulWidget {
  const MyRoomPage({super.key});

  @override
  State<MyRoomPage> createState() => _MyRoomPageState();
}

class _MyRoomPageState extends State<MyRoomPage> {
  bool _isListView = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= 600 && _isListView) {
      _isListView = false; // Default to grid view on wider screens
    }
  }

  void _toggleView() {
    setState(() {
      _isListView = !_isListView;
    });
  }

  void showCreateRoomOverlay() {
    OverlayService.showOverlay(
      context,
      OverlayCreateRoom(onClose: OverlayService.hideOverlay),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomProvider = Provider.of<RoomProvider>(context);
    final rooms = roomProvider.rooms;
    final screenSize = MediaQuery.of(context).size;
    final itemSize = screenSize.width < 600 ? 120.0 : 170.0;

    return Scaffold(
      appBar: ReusableAppBar(
        title: 'My Room',
        isListView: _isListView,
        onToggleView: _toggleView,
      ),
      body: Padding(
        padding: EdgeInsets.all(screenSize.width / 10000),
        child: Column(
          children: [
            Expanded(
              child: _buildRoomGrid(context, rooms, roomProvider, itemSize),
            ),
          ],
        ),
      ),
      floatingActionButton: (MediaQuery.of(context).size.width <= 600)
          ? FloatingActionButton(
              onPressed: showCreateRoomOverlay,
              backgroundColor: Colors.blue,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildRoomGrid(
    BuildContext context,
    List<Map<String, dynamic>> rooms,
    RoomProvider roomProvider,
    double itemSize,
  ) {
    final isSmallScreen = MediaQuery.of(context).size.width <= 600;

    List<Widget> gridItems = [];

    // Only show the add button inside the grid if it's a wide screen (no FAB)
    if (!isSmallScreen) {
      gridItems.add(
        GestureDetector(
          onTapDown: (TapDownDetails details) => showCreateRoomOverlay(),
          child: UIComponents.createAddButton(
            itemSize: itemSize,
            isListView: _isListView,
          ),
        ),
      );
    }

    gridItems.addAll(
      rooms.map(
        (room) => GestureDetector(
          onTap: () => _navigateToRoomDetail(context, room),
          child: RoomItem(
            id: room['id'],
            name: room['name'],
            createdDate: room['createdDate'],
            color:
                (room['color'] is int) ? Color(room['color']) : room['color'],
            isFavorite: room['isFavorite'],
            onToggleFavorite: () => roomProvider.toggleFavorite(room['id']),
            isListView: _isListView, // ✅ Pass current view mode
          ),
        ),
      ),
    );

    return _isListView
        ? ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: gridItems.length,
            itemBuilder: (context, index) => gridItems[index],
            separatorBuilder: (context, index) => const SizedBox(height: 10),
          )
        : ResponsiveGridLayout(children: gridItems);
  }

  void _navigateToRoomDetail(BuildContext context, Map<String, dynamic> room) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoomDetailPage(
          room: room,
          onRoomUpdated: () => setState(() {}),
        ),
      ),
    );
  }
}
