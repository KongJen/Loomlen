import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:frontend/api/socketService.dart';
import 'package:frontend/items/template_item.dart';
import 'package:frontend/pages/paperDB_page.dart';
import 'package:frontend/pages/paper_page.dart';
import 'package:frontend/providers/file_provider.dart';
import 'package:frontend/providers/filedb_provider.dart';
import 'package:frontend/providers/paper_provider.dart';
import 'package:frontend/providers/paperdb_provider.dart';
import 'package:provider/provider.dart';
import '../main.dart';

class OverlayCreateFile extends StatefulWidget {
  final String roomId;
  final String parentId;
  final bool isInFolder;
  final bool isCollab;
  final String role;
  final SocketService? socketService;
  final VoidCallback onClose;

  const OverlayCreateFile({
    super.key,
    required this.roomId,
    required this.onClose,
    required this.parentId,
    required this.isInFolder,
    required this.isCollab,
    required this.role,
    this.socketService,
  });

  @override
  // ignore: library_private_types_in_public_api
  _OverlayCreateFileState createState() => _OverlayCreateFileState();
}

class _OverlayCreateFileState extends State<OverlayCreateFile> {
  late SocketService _socketService;
  final TextEditingController nameController = TextEditingController();
  late PaperTemplate selectedTemplate;
  List<PaperTemplate> availableTemplates = [
    const PaperTemplate(id: 'plain', name: 'Plain Paper'),
    const PaperTemplate(id: 'lined', name: 'Lined Paper', spacing: 30.0),
    const PaperTemplate(id: 'grid', name: 'Grid Paper', spacing: 30.0),
    const PaperTemplate(id: 'dotted', name: 'Dotted Paper', spacing: 30.0),
  ];

  void createFile() async {
    if (nameController.text.trim().isEmpty) return;
    try {
      final fileProvider = Provider.of<FileProvider>(context, listen: false);
      final paperProvider = Provider.of<PaperProvider>(context, listen: false);

      final fileDBProvider =
          Provider.of<FileDBProvider>(context, listen: false);
      final paperDBProvider =
          Provider.of<PaperDBProvider>(context, listen: false);

      String fileId;
      String fileName = '';

      if (widget.isCollab == true) {
        if (widget.isInFolder == true) {
          final result = await fileDBProvider.addFile(
            nameController.text.trim(),
            roomId: widget.roomId,
            parentFolderId: widget.parentId,
          );
          fileId = result['id']!;
          fileName = result['name']!;

          paperDBProvider.addPaper(
              selectedTemplate, 1, 595, 842, fileId, widget.roomId, '');
        } else {
          final result = await fileDBProvider.addFile(
            nameController.text.trim(),
            roomId: widget.roomId,
            parentFolderId: 'Unknow',
          );
          fileId = result['id']!;
          fileName = result['name']!;

          paperDBProvider.addPaper(
              selectedTemplate, 1, 595, 842, fileId, widget.roomId, '');
        }
      } else {
        if (widget.isInFolder == true) {
          final result = fileProvider.addFile(
            nameController.text.trim(),
            parentFolderId: widget.parentId,
          );
          fileId = result['id']!;
          fileName = result['name']!;

          paperProvider.addPaper(
            selectedTemplate,
            1,
            null,
            null,
            595,
            842,
            fileId,
          );
        } else {
          final result = fileProvider.addFile(
            nameController.text.trim(),
            roomId: widget.parentId,
          );
          fileId = result['id']!;
          fileName = result['name']!;

          paperProvider.addPaper(
            selectedTemplate,
            1,
            null,
            null,
            595,
            842,
            fileId,
          );
        }
      }

      MyApp.navMenuKey.currentState?.toggleBottomNavVisibility(false);
      if (widget.isCollab) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaperDBPage(
              collab: widget.isCollab,
              name: nameController.text.trim(),
              fileId: fileId,
              roomId: widget.roomId,
              role: widget.role,
              onFileUpdated: () => setState(() {}),
              socket: widget.socketService,
            ),
          ),
        ).then((_) {
          MyApp.navMenuKey.currentState?.toggleBottomNavVisibility(true);
        });
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaperPage(
              name: fileName,
              fileId: fileId,
              onFileUpdated: () => setState(() {}),
              roomId: widget.roomId,
            ),
          ),
        ).then((_) {
          MyApp.navMenuKey.currentState?.toggleBottomNavVisibility(true);
        });
      }
      widget.onClose();
    } catch (e) {
      if (kDebugMode) {
        print("Error creating file: $e");
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error creating file: $e')));
    }
  }

  @override
  void initState() {
    super.initState();
    selectedTemplate = availableTemplates[0];
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
                            'Create File',
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
                            hintText: 'Enter File name',
                            prefixIcon: Icon(
                              Icons.folder_outlined,
                              color: Colors.black,
                            ),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Select Paper Template',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),

                        // Template Selection Container
                        SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: availableTemplates.length,
                            itemBuilder: (context, index) {
                              final template = availableTemplates[index];
                              final isSelected =
                                  template.id == selectedTemplate.id;

                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedTemplate = template;
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  width: 80,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.blue
                                          : Colors.grey.shade300,
                                      width: isSelected ? 2.0 : 1.0,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius:
                                              const BorderRadius.vertical(
                                            top: Radius.circular(8),
                                          ),
                                          child: CustomPaint(
                                            painter: TemplateThumbnailPainter(
                                              template: template,
                                            ),
                                            size: const Size(80, 60),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4.0,
                                        ),
                                        child: Text(
                                          template.name,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(height: 20),
                        // Create File Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: createFile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              'Create File',
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

class TemplateThumbnailPainter extends CustomPainter {
  final PaperTemplate template;

  TemplateThumbnailPainter({required this.template});

  @override
  void paint(Canvas canvas, Size size) {
    template.paintTemplate(canvas, size);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
