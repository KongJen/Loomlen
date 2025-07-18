import 'package:flutter/material.dart';
import 'package:frontend/items/room_db_item.dart';
import 'package:frontend/pages/room_page.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/roomdb_provider.dart';
import 'package:frontend/widget/app_bar.dart';
import 'package:frontend/widget/grid_layout.dart';
import 'package:provider/provider.dart';
import 'dart:async';

class SharePage extends StatefulWidget {
  const SharePage({super.key});

  @override
  State<SharePage> createState() => _SharePageState();
}

class _SharePageState extends State<SharePage> {
  bool _isLoading = true;

  Timer? _pollingTimer;
  bool _isListView = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= 600 && _isListView) {
      _isListView = false; // default to grid on wider screens
    }
  }

  void _toggleView() {
    setState(() {
      _isListView = !_isListView;
    });
  }

  @override
  void initState() {
    super.initState();
    // _loadRooms();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final roomDBProvider =
          Provider.of<RoomDBProvider>(context, listen: false);

      // Load folders for the specific room
      roomDBProvider.loadRoomsDB();

      _pollingTimer = Timer.periodic(Duration(seconds: 5), (timer) {
        roomDBProvider.loadRoomsDB();
      });
    });
  }

  Future<void> _loadRooms() async {
    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.refreshAuthState();

    final roomDBProvider = Provider.of<RoomDBProvider>(context, listen: false);
    await roomDBProvider.loadRoomsDB();

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final roomDBProvider = Provider.of<RoomDBProvider>(context);
    final isLoggedIn = authProvider.isLoggedIn;
    final rooms = roomDBProvider.rooms;
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      appBar: ReusableAppBar(
        title: 'Shared Room',
        isListView: _isListView,
        onToggleView: _toggleView,
      ),
      body: RefreshIndicator(
        onRefresh: _loadRooms,
        child: Padding(
          padding: EdgeInsets.all(screenSize.width / 10000),
          child:
              // _isLoading
              //     ? Center(child: CircularProgressIndicator())
              isLoggedIn
                  ? rooms.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('No rooms available'),
                              SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadRooms,
                                child: Text('Refresh'),
                              ),
                            ],
                          ),
                        )
                      : _buildRoomGrid(context, rooms, roomDBProvider)
                  : Center(child: Text('Please log in to view your rooms')),
        ),
      ),
    );
  }

  Widget _buildRoomGrid(
    BuildContext context,
    List<Map<String, dynamic>> rooms,
    RoomDBProvider roomDBProvider,
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
            color: Color(room['color']),
            is_favorite: room['is_favorite'],
            role: room['role_id'],
            originalId: room['original_id'],
            onToggleFavorite: () => roomDBProvider.toggleFavorite(room['id']),
            createdDate: room['createdAt'] ?? 'Unknown',
            updatedAt: room['updatedAt'] ?? 'Unknown',
            isListView: _isListView,
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

  void _navigateToRoomDetail(
    BuildContext context,
    Map<String, dynamic> room,
  ) async {
    // Wait for the navigation to return before refreshing rooms
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoomDetailPage(
          room: room,
          onRoomUpdated: () {
            // This callback will be called when room is updated
            Provider.of<RoomDBProvider>(
              context,
              listen: false,
            ).refreshRooms();
          },
        ),
      ),
    );

    // Refresh rooms when returning from the detail page
    if (mounted) {
      _loadRooms();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
