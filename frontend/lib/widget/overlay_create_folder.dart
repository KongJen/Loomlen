import 'package:flutter/material.dart';
import 'package:frontend/providers/folder_provider.dart';
import 'package:frontend/providers/folderdb_provider.dart';
import 'package:provider/provider.dart';
import 'package:frontend/widget/colorPicker.dart';

class OverlayCreateFolder extends StatefulWidget {
  final String roomId;
  final String parentId;
  final bool isInFolder;
  final bool isCollab;
  final VoidCallback onClose;

  const OverlayCreateFolder(
      {super.key,
      required this.roomId,
      required this.onClose,
      required this.parentId,
      required this.isInFolder,
      required this.isCollab});

  @override
  // ignore: library_private_types_in_public_api
  _OverlayCreateFolderState createState() => _OverlayCreateFolderState();
}

class _OverlayCreateFolderState extends State<OverlayCreateFolder> {
  final TextEditingController nameController =
      TextEditingController(text: 'Folder');
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

    final folderProvider = Provider.of<FolderProvider>(context, listen: false);
    final folderDBProvider =
        Provider.of<FolderDBProvider>(context, listen: false);
    if (widget.isCollab == true) {
      if (widget.isInFolder == true) {
        folderDBProvider.addFolder(
          nameController.text.trim(),
          selectedColor,
          roomId: widget.roomId,
          parentFolderId: widget.parentId,
        );
      } else {
        print("nice");
        folderDBProvider.addFolder(
          nameController.text.trim(),
          selectedColor,
          roomId: widget.roomId,
          parentFolderId: 'Unknow',
        );
      }
    } else {
      if (widget.isInFolder == true) {
        folderProvider.addFolder(
          nameController.text.trim(),
          selectedColor,
          parentFolderId: widget.parentId,
        );
      } else {
        folderProvider.addFolder(
          nameController.text.trim(),
          selectedColor,
          roomId: widget.parentId,
        );
      }
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
                        ColorPickerWidget(
                          currentColor: selectedColor,
                          onColorChanged: (Color color) {
                            setState(() {
                              selectedColor = color;
                            });
                          },
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
