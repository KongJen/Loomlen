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
      appBar: ReusableAppBar(title: 'My Room', showActionButtons: true),
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
    );
  }

  Widget _buildRoomGrid(
    BuildContext context,
    List<Map<String, dynamic>> rooms,
    RoomProvider roomProvider,
    double itemSize,
  ) {
    // Create room widgets list starting with the "New" button
    List<Widget> gridItems = [
      UIComponents.createAddButton(
        onPressed: showCreateRoomOverlay,
        itemSize: itemSize,
      ),
    ];

    // Add all room items
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
          ),
        ),
      ),
    );

    return ResponsiveGridLayout(children: gridItems);
  }

  void _navigateToRoomDetail(BuildContext context, Map<String, dynamic> room) {
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
  }
}
