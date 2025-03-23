import 'package:flutter/material.dart';
import 'package:frontend/api/apiService.dart';
import 'package:frontend/items/room_db_item.dart';
import 'package:frontend/items/room_item.dart';
import 'package:frontend/pages/room_page.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/roomdb_provider.dart';
import 'package:frontend/widget/app_bar.dart';
import 'package:frontend/widget/grid_layout.dart';
import 'package:provider/provider.dart';

class SharePage extends StatefulWidget {
  const SharePage({super.key});

  @override
  State<SharePage> createState() => _SharePageState();
}

class _SharePageState extends State<SharePage> {
  // @override
  // void initState() {
  //   super.initState();
  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     if (mounted) {
  //       final authProvider = Provider.of<AuthProvider>(context, listen: false);
  //       if (authProvider.isLoggedIn) {
  //         Provider.of<RoomDBProvider>(context, listen: false).loadRoomsDB();
  //       }
  //     }
  //   });
  // }

  bool _initialLoadComplete = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = Provider.of<AuthProvider>(context);

    // Only load rooms if authenticated and not already loaded
    if (authProvider.isLoggedIn && !_initialLoadComplete) {
      _initialLoadComplete = true;
      Provider.of<RoomDBProvider>(context, listen: false).loadRoomsDB();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final roomDBProvider = Provider.of<RoomDBProvider>(context);
    final isLoggedIn = authProvider.isLoggedIn;
    final rooms = roomDBProvider.rooms;
    final screenSize = MediaQuery.of(context).size;
    final itemSize = screenSize.width < 600 ? 120.0 : 170.0;

    return Scaffold(
      appBar: ReusableAppBar(title: 'My Room', showActionButtons: true),
      body: Padding(
        padding: EdgeInsets.all(screenSize.width / 10000),
        child:
            isLoggedIn
                ? rooms.isEmpty
                    ? Center(child: Text('No rooms available'))
                    : _buildRoomGrid(context, rooms, itemSize)
                : Center(child: Text('Please log in to view your rooms')),
      ),
    );
  }

  Widget _buildRoomGrid(
    BuildContext context,
    List<Map<String, dynamic>> rooms,
    double itemSize,
  ) {
    // Create room widgets list
    List<Widget> gridItems = [];

    // Add all room items
    gridItems.addAll(
      rooms.map(
        (room) => GestureDetector(
          onTap: () => _navigateToRoomDetail(context, room),
          child: RoomDBItem(
            id: room['id'],
            name: room['name'],
            color: parseColor(room['color']),
            isFavorite: room['is_favorite'] ?? false,
            onToggleFavorite: () => null,
            createdDate: room['createdAt'] ?? 'Unknown',
            updatedAt: room['updatedAt'] ?? 'Unknown',
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
