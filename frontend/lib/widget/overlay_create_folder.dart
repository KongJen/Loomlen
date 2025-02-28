import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model/provider.dart';

class OverlayCreateFolder extends StatefulWidget {
  final String parentId;
  final bool isInFolder;
  final VoidCallback onClose;

  const OverlayCreateFolder({
    super.key,
    required this.onClose,
    required this.parentId,
    required this.isInFolder,
  });

  @override
  // ignore: library_private_types_in_public_api
  _OverlayCreateFolderState createState() => _OverlayCreateFolderState();
}

class _OverlayCreateFolderState extends State<OverlayCreateFolder> {
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

  void createFolder() {
    if (nameController.text.trim().isEmpty) return;

    final roomProvider = Provider.of<RoomProvider>(context, listen: false);
    final folderProvider = Provider.of<FolderProvider>(context, listen: false);

    final folderId = folderProvider.addFolder(
      nameController.text.trim(),
      selectedColor,
    );

    if (widget.isInFolder == true) {
      folderProvider.addFolderToFolder(widget.parentId, folderId);
    } else {
      roomProvider.addFolderToRoom(widget.parentId, folderId);
    }

    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("Room Name: ${widget.parentId}");
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            // ignore: deprecated_member_use
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
                  // Title Bar
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(10),
                      ),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            'Create Folder',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                            ),
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
                  // Input Fields
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            hintText: 'Enter Folder name',
                            prefixIcon: Icon(
                              Icons.folder_outlined,
                              color: Colors.black,
                            ),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Select Folder Color',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        // Color Picker
                        SizedBox(
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
                        // Create Folder Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: createFolder,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              'Create Folder',
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
