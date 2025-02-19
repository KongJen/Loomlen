import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../OBJ/object.dart';
import '../OBJ/provider.dart';
import 'room_page.dart';

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
    routeObserver = RouteObserver<PageRoute>();
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

    final favoriteRooms = Provider.of<RoomProvider>(context)
        .rooms
        .where((room) => room['isFavorite'])
        .toList();

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
                top: MediaQuery.of(context).padding.top + 35,
                left: 60,
                right: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Favorites',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
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
                itemCount: favoriteRooms.length,
                itemBuilder: (context, index) {
                  final room = favoriteRooms[index];

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RoomDetailPage(
                            room: room,
                            onRoomUpdated: () {
                              setState(() {}); // Refresh page after update
                            },
                          ),
                        ),
                      );
                    },
                    child: RoomItem(
                      id: room['id'],
                      name: room['name'],
                      createdDate: room['createdDate'],
                      color: (room['color'] is int)
                          ? Color(room['color'])
                          : room['color'],
                      isFavorite: room['isFavorite'],
                      folderIds: room['folderIds'] ?? [],
                      fileIds: room['fileIds'] ?? [],
                      onToggleFavorite: () {
                        Provider.of<RoomProvider>(context, listen: false)
                            .toggleFavorite(room['name']);
                      },
                    ),
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
