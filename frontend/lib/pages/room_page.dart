import 'package:flutter/material.dart';
import '../OBJ/provider.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:provider/provider.dart';
import '../widget/overlay_createFolder.dart';
import '../OBJ/object.dart';

class RoomDetailPage extends StatefulWidget {
  final Map<String, dynamic> room;
  final Function? onRoomUpdated;

  const RoomDetailPage({
    Key? key,
    required this.room,
    this.onRoomUpdated,
  }) : super(key: key);

  @override
  _RoomDetailPageState createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends State<RoomDetailPage> {
  late Map<String, dynamic> currentRoom;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    currentRoom = Map<String, dynamic>.from(widget.room); // Create a local copy
  }

  void _toggleOverlay(Widget? overlayWidget) {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    } else if (overlayWidget != null) {
      OverlayState overlayState = Overlay.of(context);
      _overlayEntry = OverlayEntry(builder: (context) => overlayWidget);
      overlayState.insert(_overlayEntry!);
    }
  }

  void showCreateFolderOverlay(String roomId) {
    _toggleOverlay(
      OverlayCreateFolder(
        roomId: roomId,
        onClose: () => _toggleOverlay(null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final folderProvider = Provider.of<FolderProvider>(context);
    // Safely handle null folderIds by defaulting to an empty list if null
    final folderIds =
        currentRoom['folderIds'] ?? []; // Default to empty list if null

    // Filter folders based on 'folderIds' of the current room
    final folders = folderProvider.folders
        .where((folder) => folderIds.contains(folder['id']))
        .toList();

    // Print all data from the filtered folders
    folders.forEach((folder) {
      print("Folder ID: ${folder['id']}");
      print("Folder Name: ${folder['name']}");
      print("Folder Created Date: ${folder['createdDate']}");
      print("Folder Color: ${folder['color']}");
      print("Folder IsFavorite: ${folder['isFavorite']}");
    });

    print("folderIds from currentRoom: $folderIds");
    print("folderName: ${currentRoom['folderIds']}");
    return Scaffold(
      appBar: AppBar(
        title: Text(
          currentRoom['name'],
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: currentRoom['color'] is int
            ? Color(currentRoom['color'])
            : currentRoom['color'],
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
              currentRoom['isFavorite'] ? Icons.star : Icons.star_border,
              color: Colors.white,
            ),
            onPressed: () {
              final roomProvider =
                  Provider.of<RoomProvider>(context, listen: false);
              roomProvider
                  .toggleFavorite(currentRoom['name']); // ✅ Call the function
              setState(() {
                currentRoom['isFavorite'] =
                    !currentRoom['isFavorite']; // ✅ Update UI instantly
              });
            },
          ),
        ],
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
                itemCount: folders.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return GestureDetector(
                      onTap: () => showCreateFolderOverlay(currentRoom['id']),
                      child: Column(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 50.0),
                            child: DottedBorder(
                              borderType: BorderType.RRect,
                              radius: const Radius.circular(8.0),
                              dashPattern: const [8, 4],
                              color: Colors.blue,
                              strokeWidth: 2,
                              child: Container(
                                width: 100.0,
                                height: 100.0,
                                alignment: Alignment.center,
                                child: const Icon(Icons.add,
                                    size: 32, color: Colors.blue),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text("New",
                              style: TextStyle(color: Colors.blue)),
                        ],
                      ),
                    );
                  } else {
                    final folder = folders[index - 1];
                    return GestureDetector(
                      onTap: () {},
                      child: FolderItem(
                        id: folder['id'],
                        name: folder['name'],
                        createdDate: folder['createdDate'],
                        color: (folder['color'] is int)
                            ? Color(folder['color'])
                            : folder['color'],
                        isFavorite: folder['isFavorite'],
                        subfolders: [], // Ensure no undefined errors
                        onToggleFavorite: () =>
                            folderProvider.toggleFavoriteFolder(folder['id']),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
