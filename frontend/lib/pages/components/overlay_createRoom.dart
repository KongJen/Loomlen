import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class OverlayCreateRoom extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback? onRoomCreated;

  const OverlayCreateRoom({
    Key? key,
    required this.onClose,
    this.onRoomCreated,
  }) : super(key: key);

  @override
  _OverlayCreateRoomState createState() => _OverlayCreateRoomState();
}

class _OverlayCreateRoomState extends State<OverlayCreateRoom> {
  final TextEditingController nameController = TextEditingController();
  Color selectedColor = Colors.blue;

  final List<Color> colorOptions = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.yellow,
    Colors.purple,
    Colors.orange,
    Colors.teal,
    Colors.pink,
  ];

  Future<void> createRoom() async {
    if (nameController.text.trim().isEmpty) return;

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/rooms.json');

    List<Map<String, dynamic>> rooms = [];

    if (await file.exists()) {
      final data = jsonDecode(await file.readAsString());
      rooms = List<Map<String, dynamic>>.from(data);
    }

    // Add new room
    rooms.add({
      'name': nameController.text.trim(),
      'createdDate': DateTime.now().toString(),
      'color': selectedColor.value, // Store color as int
      'isFavorite': false,
    });

    // Save updated rooms list
    await file.writeAsString(jsonEncode(rooms));

    // Notify parent and close overlay
    widget.onRoomCreated?.call();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: Container(color: Colors.black.withOpacity(0.5)),
          ),
        ),
        Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 350,
              decoration: BoxDecoration(
                color: Colors.grey[200],
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
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(10)),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            'Create Room',
                            style: TextStyle(
                                fontSize: 25, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: -15,
                          child: IconButton(
                            icon: Icon(Icons.close, color: Colors.black),
                            onPressed: widget.onClose,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            hintText: 'Enter room name',
                            prefixIcon: Icon(Icons.folder_outlined,
                                color: Colors.black),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Select Room Color',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          height: 50,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: colorOptions.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      selectedColor = colorOptions[index];
                                    });
                                  },
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: colorOptions[index],
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color:
                                            selectedColor == colorOptions[index]
                                                ? Colors.white
                                                : Colors.transparent,
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        if (selectedColor ==
                                            colorOptions[index])
                                          BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 4,
                                            spreadRadius: 1,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: createRoom,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              'Create Room',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
