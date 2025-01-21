import 'package:flutter/material.dart';
import 'components/room.dart';
import 'sample_data.dart';

class MyRoomPage extends StatefulWidget {
  @override
  State<MyRoomPage> createState() => _MyRoomPageState();
}

class _MyRoomPageState extends State<MyRoomPage> {
  void toggleFavorite(int index) {
    setState(() {
      sampleData[index]['isFavorite'] = !sampleData[index]['isFavorite'];
    });
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
                top: MediaQuery.of(context).padding.top + 35,
                left: 60,
                right: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Room',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.black, // Add text color
                    ),
                  ),
                  // You can add more widgets here if needed
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
                  crossAxisCount: 6, // Set number of columns
                  crossAxisSpacing: 1.0, // Space between columns
                  mainAxisSpacing: 16.0, // Space between rows
                  childAspectRatio: 1, // Aspect ratio for each item
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
