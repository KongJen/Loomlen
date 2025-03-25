import 'package:flutter/material.dart';
import 'package:frontend/items/room_db_item.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/roomdb_provider.dart';
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';
import '../items/room_item.dart';
import 'room_page.dart';
import '../widget/grid_layout.dart';
import '../widget/ui_component.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage>
    with AutomaticKeepAliveClientMixin, RouteAware {
  RouteObserver<PageRoute>? routeObserver;

  Future<void> _loadRooms() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.refreshAuthState();

    final roomDBProvider = Provider.of<RoomDBProvider>(context, listen: false);
    await roomDBProvider.loadRoomsDB();
  }

  //load room when login
  bool _initialLoadComplete = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver?.unsubscribe(this);
    routeObserver?.subscribe(this, ModalRoute.of(context) as PageRoute);

    final authProvider = Provider.of<AuthProvider>(context);

    // Only load rooms if authenticated and not already loaded
    if (authProvider.isLoggedIn && !_initialLoadComplete) {
      _initialLoadComplete = true;
      _loadRooms();
    }
  }

  @override
  void dispose() {
    routeObserver?.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    setState(() {}); // Refresh page when returning
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final roomDBProvider = Provider.of<RoomDBProvider>(context);
    final roomProvider = Provider.of<RoomProvider>(context);

    // Get favorite rooms from both providers
    final favoriteDBRooms =
        roomDBProvider.rooms.where((room) => room['is_favorite'] == true).map((
          room,
        ) {
          // Normalize the room data structure
          return {
            'id': room['id'],
            'name': room['name'],
            'color': room['color'],
            'createdDate':
                room['created_at'] ??
                room['createdAt'] ??
                DateTime.now().toString(),
            'isFavorite': true, // It's in the favorites list
            'isFromDB': true, // Flag to identify source
          };
        }).toList();

    final favoriteRooms =
        roomProvider.rooms.where((room) => room['isFavorite'] == true).map((
          room,
        ) {
          return {
            'id': room['id'],
            'name': room['name'],
            'color': room['color'],
            'createdDate':
                room['createdDate'] ??
                room['created_at'] ??
                DateTime.now().toString(),
            'isFavorite': true,
            'isFromDB': false,
          };
        }).toList();

    // Combine both lists
    final allFavoriteRooms = [...favoriteDBRooms, ...favoriteRooms];

    // Remove duplicates (if a room exists in both providers)
    final Map<String, Map<String, dynamic>> uniqueRooms = {};
    for (var room in allFavoriteRooms) {
      uniqueRooms[room['id']] = room;
    }

    final List<Map<String, dynamic>> combinedFavoriteRooms =
        uniqueRooms.values.toList();

    return Scaffold(
      appBar: UIComponents.createTitleAppBar(
        context: context,
        title: 'Favorites',
      ),
      body:
          combinedFavoriteRooms.isEmpty
              ? const Center(child: Text('No favorite rooms yet'))
              : Padding(
                padding: EdgeInsets.all(
                  MediaQuery.of(context).size.width / 10000,
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: _buildRoomGrid(
                        context,
                        combinedFavoriteRooms,
                        roomProvider,
                        roomDBProvider,
                      ),
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
    RoomDBProvider roomDBProvider,
  ) {
    final List<Widget> roomWidgets =
        rooms.map((room) {
          final roomColor =
              (room['color'] is String)
                  ? parseColor(room['color'])
                  : (room['color'] is int)
                  ? Color(room['color'])
                  : room['color'] ?? Colors.grey;

          return GestureDetector(
            onTap: () => _navigateToRoomDetail(context, room),
            child: RoomItem(
              id: room['id'],
              name: room['name'],
              createdDate: room['createdDate'],
              color: roomColor,
              isFavorite: room['isFavorite'],
              onToggleFavorite: () {
                // Call the appropriate provider based on the source
                if (room['isFromDB'] == true) {
                  roomDBProvider.toggleFavorite(room['id']);
                } else {
                  roomProvider.toggleFavorite(room['id']);
                }
                // Update the UI immediately
                setState(() {
                  room['isFavorite'] = !room['isFavorite'];
                });
              },
            ),
          );
        }).toList();

    return ResponsiveGridLayout(children: roomWidgets);
  }

  void _navigateToRoomDetail(BuildContext context, Map<String, dynamic> room) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => RoomDetailPage(
              room: room,
              onRoomUpdated: () {
                setState(() {}); // Refresh page after update
              },
            ),
      ),
    );
  }
}
