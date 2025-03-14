// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf_render/pdf_render.dart';
import 'dart:io';
import 'package:image/image.dart' as img;
import '../model/provider.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:provider/provider.dart';
import '../widget/overlay_menu.dart';
import '../widget/overlay_create_folder.dart';
import '../OBJ/object.dart';
import '../widget/overlay_create_file.dart';
import '../paper_page.dart';
import 'package:path_provider/path_provider.dart';
import '../main.dart';
import '../widget/overlay_loading.dart';

class RoomDetailPage extends StatefulWidget {
  final Map<String, dynamic> room;
  final Function? onRoomUpdated;

  const RoomDetailPage({super.key, required this.room, this.onRoomUpdated});

  @override
  // ignore: library_private_types_in_public_api
  _RoomDetailPageState createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends State<RoomDetailPage> {
  late Map<String, dynamic> currentRoom;
  OverlayEntry? _overlayEntry;
  List<Map<String, dynamic>> navigationStack = [];
  Map<String, dynamic>? currentFolder;
  Map<String, dynamic>? currentFile;

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

  void showOverlaySelect(
    String parentId,
    BuildContext context,
    Offset position,
  ) {
    _toggleOverlay(
      OverlaySelect(
        overlayPosition: position,
        onCreateFolder: () {
          _toggleOverlay(null);
          showCreateFolderOverlay(parentId);
        },
        onCreateFile: () {
          _toggleOverlay(null);
          showCreateFileOverlay(parentId);
        },
        onImportPDF: () {
          _toggleOverlay(null);
          showImportPDF(parentId);
        },
        onClose: () => _toggleOverlay(null),
      ),
    );
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

  void showCreateFileOverlay(String parentId) {
    _toggleOverlay(
      OverlayCreateFile(
        parentId: currentFile != null ? currentFile!['id'] : parentId,
        isInFolder: currentFolder != null,
        onClose: () => _toggleOverlay(null),
      ),
    );
  }

  Future<void> showImportPDF(String parentId) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        String pdfPath = result.files.single.path!;
        String pdfName = result.files.single.name;
        debugPrint('Selected PDF: $pdfPath');

        PdfDocument pdfDoc = await PdfDocument.openFile(pdfPath);
        int pageCount = pdfDoc.pageCount;
        debugPrint('PDF has $pageCount pages');

        final fileProvider = Provider.of<FileProvider>(context, listen: false);
        final paperProvider = Provider.of<PaperProvider>(
          context,
          listen: false,
        );
        final roomProvider = Provider.of<RoomProvider>(context, listen: false);
        final folderProvider = Provider.of<FolderProvider>(
          context,
          listen: false,
        );

        String fileId = fileProvider.addFile(pdfName);
        List<String> paperIds = [];
        debugPrint('Created file ID: $fileId');

        final loadingOverlay = LoadingOverlay(
          context: context,
          message: 'Preparing to import PDF',
          subMessage: 'Please wait while we process your file',
        );

        loadingOverlay.show();

        for (int i = 1; i <= pageCount; i++) {
          PdfPage page = await pdfDoc.getPage(i);
          double pdfWidth = page.width; // Get PDF page width in points
          double pdfHeight = page.height; // Get PDF page height in points
          debugPrint('Page $i size: ${pdfWidth}x$pdfHeight');

          PdfPageImage? pageImage = await page.render(
            // Increase the resolution by applying a scale factor
            width: (page.width * 2).toInt(), // Double the resolution
            height: (page.height * 2).toInt(), // Double the resolution
          );

          // Convert raw pixels to PNG format
          final image = img.Image.fromBytes(
            width: pageImage.width,
            height: pageImage.height,
            bytes: pageImage.pixels.buffer,
            order: img.ChannelOrder.rgba,
          );
          final pngBytes = img.encodePng(image, level: 6);

          // Save the PNG to a file
          final directory = await getApplicationDocumentsDirectory();
          String imagePath = '${directory.path}/${pdfName}_page_$i.png';
          File imageFile = File(imagePath);
          await imageFile.writeAsBytes(pngBytes);
          debugPrint('Saved PNG for page $i at: $imagePath');
          debugPrint('Image exists: ${await imageFile.exists()}');

          // Pass the PDF size to addPaper
          String paperId = paperProvider.addPaper(
            PaperTemplate(
              id: 'plain',
              name: 'Plain Paper',
              templateType: TemplateType.plain,
              spacing: 30.0,
            ),
            i,
            null,
            imagePath,
            pdfWidth,
            pdfHeight,
          );

          debugPrint('Created paper ID: $paperId for page $i');

          paperIds.add(paperId);
          fileProvider.addPaperPageToFile(fileId, paperId);

          pageImage.dispose();
        }

        loadingOverlay.hide();

        pdfDoc.dispose();

        if (currentFolder != null) {
          folderProvider.addFileToFolder(currentFolder!['id'], fileId);
        } else {
          roomProvider.addFileToRoom(parentId, fileId);
        }

        setState(() {});
        debugPrint('Paper IDs for file $fileId: $paperIds');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF "$pdfName" imported as $pageCount pages'),
          ),
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => PaperPage(
                  name: pdfName,
                  fileId: fileId,
                  initialPageIds: paperIds,
                  onFileUpdated: () => setState(() {}),
                ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error importing PDF: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error importing PDF: $e')));
    }
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
    if (fullPath.length < 5) {
      return Row(
        children:
            fullPath.map((folder) {
              int index = fullPath.indexOf(folder);
              return Row(
                children: [
                  if (index == 0)
                    const Padding(
                      padding: EdgeInsets.only(left: 5),
                      child: Icon(Icons.home_filled, color: Colors.white),
                    ),
                  if (index > 0)
                    const Icon(Icons.chevron_right, color: Colors.white),
                  Text(
                    folder['name'],
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              );
            }).toList(),
      );
    } else {
      return Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 5),
            child: Icon(Icons.home_filled, color: Colors.white),
          ),
          Text(
            fullPath[0]['name'],
            style: const TextStyle(color: Colors.white),
          ),
          const Icon(Icons.chevron_right, color: Colors.white),
          Text('...', style: const TextStyle(color: Colors.white)),
          const Icon(Icons.chevron_right, color: Colors.white),
          Text(
            fullPath[fullPath.length - 1]['name'],
            style: const TextStyle(color: Colors.white),
          ),
        ],
      );
    }
  }

  int _getCrossAxisCount(double width) {
    if (width < 600) return 2;
    if (width < 900) return 3;
    if (width < 1200) return 4;
    if (width < 1500) return 5;
    return 6;
  }

  @override
  Widget build(BuildContext context) {
    final roomProvider = Provider.of<RoomProvider>(context);
    final folderProvider = Provider.of<FolderProvider>(context);
    final fileProvider = Provider.of<FileProvider>(context);
    final screenSize = MediaQuery.of(context).size;
    final crossAxisCount = _getCrossAxisCount(screenSize.width);

    final roomId = currentRoom['id'];
    final room = roomProvider.rooms.firstWhere(
      (room) => room['id'] == roomId,
      orElse: () => <String, dynamic>{},
    );

    final List<String> currentFolderIds =
        currentFolder != null
            ? (currentFolder!['subfolderIds'] ?? [])
            : (room['folderIds'] ?? []);

    final folders =
        folderProvider.folders
            .where((folder) => currentFolderIds.contains(folder['id']))
            .toList();

    final List<String> currentFileIds =
        currentFolder != null
            ? (currentFolder!['fileIds'] ?? [])
            : (room['fileIds'] ?? []);
    final files =
        fileProvider.files
            .where((file) => currentFileIds.contains(file['id']))
            .toList();

    final itemSize = screenSize.width < 600 ? 120.0 : 170.0;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed:
              currentFolder != null
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
              roomProvider.toggleFavorite(currentRoom['name']);
              setState(() {
                currentRoom['isFavorite'] = !currentRoom['isFavorite'];
              });
            },
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(screenSize.width / 10000),
        child: Column(
          children: [
            Expanded(
              child: GridView.builder(
                padding: EdgeInsets.all(screenSize.width / 10000),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 10.0,
                  mainAxisSpacing: 16.0,
                  childAspectRatio: 0.8,
                ),
                itemCount: folders.length + files.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return GestureDetector(
                      onTapDown:
                          (TapDownDetails details) => showOverlaySelect(
                            currentFolder != null
                                ? currentFolder!['id']
                                : currentRoom['id'],
                            context,
                            details.globalPosition,
                          ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: itemSize, // Match the height of room icons
                            child: Center(
                              child: DottedBorder(
                                borderType: BorderType.RRect,
                                radius: const Radius.circular(8.0),
                                dashPattern: const [8, 4],
                                color: Colors.blue,
                                strokeWidth: 2,
                                child: Container(
                                  width: itemSize * 0.65,
                                  height: itemSize * 0.65,
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.add,
                                    size: itemSize * 0.2,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "New",
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(
                            height: 12,
                          ), // Match spacing of room items
                        ],
                      ),
                    );
                  } else if (index <= folders.length) {
                    final folder = folders[index - 1];
                    return GestureDetector(
                      onTap: () => navigateToFolder(folder),
                      child: FolderItem(
                        id: folder['id'],
                        name: folder['name'],
                        createdDate: folder['createdDate'],
                        color:
                            (folder['color'] is int)
                                ? Color(folder['color'])
                                : folder['color'],
                        subfolderIds: folder['subfolderIds'] ?? [],
                        fileIds: folder['fileIds'] ?? [],
                      ),
                    );
                  } else {
                    final file = files[index - folders.length - 1];
                    return GestureDetector(
                      onTap: () {
                        MyApp.navMenuKey.currentState
                            ?.toggleBottomNavVisibility(false);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => PaperPage(
                                  name: file['name'],
                                  fileId: file['id'],
                                  onFileUpdated: () => setState(() {}),
                                ),
                          ),
                        ).then((_) {
                          MyApp.navMenuKey.currentState
                              ?.toggleBottomNavVisibility(true);
                        });
                      },
                      child: FileItem(
                        id: file['id'],
                        name: file['name'],
                        createdDate: file['createdDate'],
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
