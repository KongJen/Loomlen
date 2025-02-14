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
  List<Map<String, dynamic>> navigationStack = [];
  Map<String, dynamic>? currentFolder;

  @override
  void initState() {
    super.initState();
    currentRoom = Map<String, dynamic>.from(widget.room);
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

  void showCreateFolderOverlay(String parentId) {
    _toggleOverlay(
      OverlayCreateFolder(
        parentId: currentFolder != null ? currentFolder!['id'] : parentId,
        isInFolder: currentFolder != null,
        onClose: () => _toggleOverlay(null),
      ),
    );
  }

  void navigateToFolder(Map<String, dynamic> folder) {
    setState(() {
      if (currentFolder != null) {
        navigationStack.add(currentFolder!);
      }
      currentFolder = folder;
    });
  }

  void navigateBack() {
    if (navigationStack.isNotEmpty) {
      setState(() {
        currentFolder = navigationStack.removeLast();
      });
    } else {
      setState(() {
        currentFolder = null;
      });
    }
  }

  Widget buildBreadcrumb() {
    List<Map<String, dynamic>> fullPath = [currentRoom];
    if (navigationStack.isNotEmpty) {
      fullPath.addAll(navigationStack);
    }
    if (currentFolder != null) {
      fullPath.add(currentFolder!);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: fullPath.map((folder) {
          int index = fullPath.indexOf(folder);
          return Row(
            children: [
              if (index > 0)
                const Icon(Icons.chevron_right, color: Colors.white),
              Text(
                folder['name'],
                style: const TextStyle(color: Colors.white),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final folderProvider = Provider.of<FolderProvider>(context);
    final List<String> currentFolderIds = currentFolder != null
        ? (currentFolder!['subfolderIds'] ?? [])
        : (currentRoom['folderIds'] ?? []);

    final folders = folderProvider.folders
        .where((folder) => currentFolderIds.contains(folder['id']))
        .toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: currentFolder != null
              ? navigateBack
              : () => Navigator.pop(context),
        ),
        title: buildBreadcrumb(),
        backgroundColor:
            (currentFolder != null && currentFolder!['color'] != null)
                ? (currentFolder!['color'] is int
                    ? Color(currentFolder!['color'])
                    : currentFolder!['color'])
                : (currentRoom['color'] is int
                    ? Color(currentRoom['color'])
                    : currentRoom['color']),
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
              roomProvider.toggleFavorite(currentRoom['name']);
              setState(() {
                currentRoom['isFavorite'] = !currentRoom['isFavorite'];
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
                      onTap: () => showCreateFolderOverlay(currentFolder != null
                          ? currentFolder!['id']
                          : currentRoom['id']),
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
                      onTap: () => navigateToFolder(folder),
                      child: FolderItem(
                        id: folder['id'],
                        name: folder['name'],
                        createdDate: folder['createdDate'],
                        color: (folder['color'] is int)
                            ? Color(folder['color'])
                            : folder['color'],
                        isFavorite: folder['isFavorite'],
                        subfolderIds: folder['subfolderIds'] ?? [],
                        fileIds: folder['fileIds'] ?? [],
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
