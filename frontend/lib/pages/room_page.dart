import 'package:flutter/material.dart';
import 'package:frontend/api/socketService.dart';
import 'package:frontend/providers/roomdb_provider.dart';
import 'package:frontend/services/PDF_import_service.dart';
import 'package:frontend/services/folder_navigation_service.dart';
import 'package:frontend/widget/grid_layout.dart';
import 'package:frontend/widget/ui_component.dart';
import 'package:provider/provider.dart';
import '../providers/folder_provider.dart';
import '../providers/file_provider.dart';
import '../providers/room_provider.dart';
import '../providers/paper_provider.dart';
import '../services/overlay_service.dart';
import '../items/folder_item.dart';
import '../items/file_item.dart';
import '../widget/overlay_menu.dart';
import '../widget/overlay_create_folder.dart';
import '../widget/overlay_create_file.dart';
import 'paper_page.dart';
import '../main.dart';
import '../widget/shareroom_dialog.dart';

class RoomDetailPage extends StatefulWidget {
  final Map<String, dynamic> room;
  final Function? onRoomUpdated;

  const RoomDetailPage({super.key, required this.room, this.onRoomUpdated});

  @override
  // ignore: library_private_types_in_public_api
  _RoomDetailPageState createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends State<RoomDetailPage> {
  late FolderNavigationService _navigationService;
  late SocketService _socketService;
  bool isCollab = false;
  bool isConnected = false;

  @override
  void initState() {
    super.initState();
    _checkisCollab();
    _navigationService = FolderNavigationService(widget.room);
    if (isCollab == true) {
      _socketService = SocketService();
      _connectToSocket();
    }
  }

  void _checkisCollab() {
    if (widget.room['isFavorite'] == null) {
      isCollab = true;
    }
  }

  void _connectToSocket() {
    _socketService.initializeSocket(widget.room['id'], (success, error) {
      if (success) {
        setState(() {
          isConnected = true;
        });
        print("Successfully connected to room: ${widget.room['id']}");
      } else {
        print("Socket connection error: $error");
      }
    });
  }

  @override
  void dispose() {
    _socketService.closeSocket();
    super.dispose();
  }

  void showOverlaySelect(BuildContext context, Offset position) {
    OverlayService.showOverlay(
      context,
      OverlaySelect(
        overlayPosition: position,
        onCreateFolder: () {
          OverlayService.hideOverlay();
          _showCreateFolderOverlay();
        },
        onCreateFile: () {
          OverlayService.hideOverlay();
          _showCreateFileOverlay();
        },
        onImportPDF: () {
          OverlayService.hideOverlay();
          _importPDF();
        },
        onClose: OverlayService.hideOverlay,
      ),
    );
  }

  void _showCreateFolderOverlay() {
    OverlayService.showOverlay(
      context,
      OverlayCreateFolder(
        parentId: _navigationService.currentParentId,
        isInFolder: _navigationService.isInFolder,
        onClose: OverlayService.hideOverlay,
      ),
    );
  }

  void _showCreateFileOverlay() {
    OverlayService.showOverlay(
      context,
      OverlayCreateFile(
        parentId: _navigationService.currentParentId,
        isInFolder: _navigationService.isInFolder,
        onClose: OverlayService.hideOverlay,
      ),
    );
  }

  void _importPDF() {
    final fileProvider = Provider.of<FileProvider>(context, listen: false);
    final paperProvider = Provider.of<PaperProvider>(context, listen: false);

    PdfService(
      showError: (message) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message))),
      showSuccess: (message) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message))),
      onImportComplete: (fileId, name) {
        _navigateToPaperPage(name, fileId);
      },
      showLoading: () => _showLoadingOverlay(),
      hideLoading: () => OverlayService.hideOverlay(),
    ).importPDF(
      parentId: _navigationService.currentParentId,
      isInFolder: _navigationService.isInFolder,
      addFile: fileProvider.addFile,
      addPaper: paperProvider.addPaper,
    );
  }

  void _showLoadingOverlay() {
    OverlayService.showOverlay(
      context,
      LoadingOverlay(
        message: 'Preparing to import PDF',
        subMessage: 'Please wait while we process your file',
      ),
    );
  }

  void _navigateToPaperPage(String name, String fileId) {
    MyApp.navMenuKey.currentState?.toggleBottomNavVisibility(false);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaperPage(
          name: name,
          fileId: fileId,
          onFileUpdated: () => setState(() {}),
        ),
      ),
    ).then((_) {
      MyApp.navMenuKey.currentState?.toggleBottomNavVisibility(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _navigationService,
      builder: (context, _) {
        return Scaffold(
          appBar: _buildAppBar(context),
          body: _buildBody(context),
        );
      },
    );
  }

  PreferredSize _buildAppBar(BuildContext context) {
    final roomProvider = Provider.of<RoomProvider>(context, listen: false);
    final roomDBProvider = Provider.of<RoomDBProvider>(context, listen: false);
    print("navigation: ${_navigationService.currentRoom['isFavorite']}");
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (!_navigationService.navigateBack()) {
              Navigator.pop(context);
            }
          },
        ),
        title: _buildBreadcrumb(),
        backgroundColor: _navigationService.currentColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_navigationService.currentRoom['isFavorite'] == null)
            IconButton(
              icon: Icon(
                _navigationService.currentRoom['is_favorite']
                    ? Icons.star
                    : Icons.star_border,
                color: Colors.white,
              ),
              onPressed: () {
                roomDBProvider.toggleFavorite(
                  _navigationService.currentRoom['id'],
                );
                setState(() {
                  _navigationService.currentRoom['is_favorite'] =
                      !_navigationService.currentRoom['is_favorite'];
                });
              },
            )
          else
            IconButton(
              icon: Icon(
                _navigationService.currentRoom['isFavorite']
                    ? Icons.star
                    : Icons.star_border,
                color: Colors.white,
              ),
              onPressed: () {
                roomProvider.toggleFavorite(
                  _navigationService.currentRoom['id'],
                );
                setState(() {
                  _navigationService.currentRoom['isFavorite'] =
                      !_navigationService.currentRoom['isFavorite'];
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share this room',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => ShareDialog(
                  roomId: _navigationService.currentRoom['id'],
                  roomName: _navigationService.currentRoom['name'],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumb() {
    List<Map<String, dynamic>> fullPath =
        _navigationService.getBreadcrumbPath();

    if (fullPath.length < 5) {
      return Row(
        children: fullPath.map((folder) {
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
      // Simplified breadcrumb for deep paths
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
          const Text('...', style: TextStyle(color: Colors.white)),
          const Icon(Icons.chevron_right, color: Colors.white),
          Text(
            fullPath.last['name'],
            style: const TextStyle(color: Colors.white),
          ),
        ],
      );
    }
  }

  Widget _buildBody(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final itemSize = screenSize.width < 600 ? 120.0 : 170.0;

    return Padding(
      padding: EdgeInsets.all(screenSize.width / 10000),
      child: Column(
        children: [Expanded(child: _buildContentGrid(context, itemSize))],
      ),
    );
  }

  Widget _buildContentGrid(BuildContext context, double itemSize) {
    final folderProvider = Provider.of<FolderProvider>(context);
    final fileProvider = Provider.of<FileProvider>(context);
    final String currentParentId = _navigationService.currentParentId;
    final bool isInFolder = _navigationService.isInFolder;

    // Fetch folders for current location
    final folders = isInFolder
        ? folderProvider.folders
            .where((folder) => folder['parentFolderId'] == currentParentId)
            .toList()
        : folderProvider.folders
            .where((folder) => folder['roomId'] == currentParentId)
            .toList();

    // Fetch files for current location
    final files = isInFolder
        ? fileProvider.files
            .where((file) => file['parentFolderId'] == currentParentId)
            .toList()
        : fileProvider.files
            .where((file) => file['roomId'] == currentParentId)
            .toList();

    // Create list of items for the grid
    List<Widget> gridItems = [
      // Add the "New" button
      GestureDetector(
        onTapDown: (TapDownDetails details) =>
            showOverlaySelect(context, details.globalPosition),
        child: UIComponents.createAddButton(
          onPressed: () {}, // Handled by onTapDown instead
          itemSize: itemSize,
        ),
      ),

      // Add folder items
      ...folders.map(
        (folder) => GestureDetector(
          onTap: () => _navigationService.navigateToFolder(folder),
          child: FolderItem(
            id: folder['id'],
            name: folder['name'],
            createdDate: folder['createdDate'],
            color: (folder['color'] is int)
                ? Color(folder['color'])
                : folder['color'],
          ),
        ),
      ),

      // Add file items
      ...files.map(
        (file) => GestureDetector(
          onTap: () => _navigateToPaperPage(file['name'], file['id']),
          child: FileItem(
            id: file['id'],
            name: file['name'],
            createdDate: file['createdDate'],
          ),
        ),
      ),
    ];

    return ResponsiveGridLayout(children: gridItems);
  }
}

class LoadingOverlay extends StatelessWidget {
  final String message;
  final String subMessage;

  const LoadingOverlay({
    super.key,
    required this.message,
    required this.subMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(subMessage),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
