import 'package:flutter/material.dart';
import 'sample_data.dart';
import 'components/room.dart';

class FavoritesPage extends StatefulWidget {
  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  void toggleFavorite(String roomName) {
    setState(() {
      final roomIndex =
          sampleData.indexWhere((room) => room['name'] == roomName);

      if (roomIndex != -1) {
        sampleData[roomIndex]['isFavorite'] =
            !sampleData[roomIndex]['isFavorite'];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Filter the data to include only favorite rooms
    final favoriteRooms =
        sampleData.where((room) => room['isFavorite'] == true).toList();

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
                      color: Colors.black, // Add text color
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
                  crossAxisCount: 6, // Number of columns
                  crossAxisSpacing: 1.0, // Space between columns
                  mainAxisSpacing: 16.0, // Space between rows
                  childAspectRatio: 1, // Aspect ratio for each item
                ),
                itemCount: favoriteRooms.length, // Number of favorite items
                itemBuilder: (context, index) {
                  final room = favoriteRooms[index];
                  return RoomItem(
                    name: room['name'],
                    createdDate: room['createdDate'],
                    color: room['color'],
                    isFavorite: room['isFavorite'],
                    onToggleFavorite: () => toggleFavorite(room['name']),
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
