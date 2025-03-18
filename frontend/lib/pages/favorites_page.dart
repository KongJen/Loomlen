import 'package:flutter/material.dart';
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

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver?.unsubscribe(this);
    routeObserver?.subscribe(this, ModalRoute.of(context) as PageRoute);
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

    final roomProvider = Provider.of<RoomProvider>(context);
    final favoriteRooms =
        roomProvider.rooms.where((room) => room['isFavorite']).toList();

    return Scaffold(
      appBar: UIComponents.createTitleAppBar(
        context: context,
        title: 'Favorites',
      ),
      body: Padding(
        padding: EdgeInsets.all(MediaQuery.of(context).size.width / 10000),
        child: Column(
          children: [
            Expanded(
              child: _buildRoomGrid(context, favoriteRooms, roomProvider),
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
  ) {
    final List<Widget> roomWidgets =
        rooms.map((room) {
          final roomColor =
              (room['color'] is int)
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
              onToggleFavorite: () => roomProvider.toggleFavorite(room['id']),
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
