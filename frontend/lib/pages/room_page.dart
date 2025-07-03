import 'package:flutter/material.dart';
import 'package:frontend/api/socketService.dart';
import 'package:frontend/items/filedb_item.dart';
import 'package:frontend/pages/paperDB_page.dart';
import 'package:frontend/providers/filedb_provider.dart';
import 'package:frontend/providers/folderdb_provider.dart';
import 'package:frontend/providers/paperdb_provider.dart';
import 'package:frontend/providers/roomdb_provider.dart';
import 'package:frontend/services/PDF_DB_import_service.dart';
import 'package:frontend/services/PDF_import_service.dart';
import 'package:frontend/services/folder_navigation_service.dart';
import 'package:frontend/widget/grid_layout.dart';
import 'package:frontend/widget/settings_member_dialog.dart';
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
  String role = 'viewer';
  bool _isListView = true; // Default to list view

  late RoomDBProvider _roomDBProvider;

  VoidCallback? _roleUpdateListener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize the provider reference safely here
    _roomDBProvider = Provider.of<RoomDBProvider>(context, listen: false);

    // Set default view mode based on screen size
    final screenWidth = MediaQuery.of(context).size.width;
    setState(() {
      _isListView =
          screenWidth < 600; // Default to list view on smaller screens
    });
  }

  @override
  void initState() {
    super.initState();
    _checkisCollab();
    _checkRole();
    _navigationService = FolderNavigationService(widget.room);

    print("NavigateID : ${widget.room['id']}");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final folderDBProvider =
          Provider.of<FolderDBProvider>(context, listen: false);

      // Load folders for the specific room
      folderDBProvider.loadFoldersDB(widget.room['id']);
      final fileDBProvider =
          Provider.of<FileDBProvider>(context, listen: false);

      // Load folders for the specific room
      fileDBProvider.loadFilesDB(widget.room['id']);

      final paperDBProvider =
          Provider.of<PaperDBProvider>(context, listen: false);

      // Load folders for the specific room
      paperDBProvider.loadPapers(widget.room['id']);

      _subscribeToRoleChanges();
    });
    if (isCollab == true) {
      _socketService = SocketService();
      _connectToSocket();
    }
  }

  void _checkisCollab() {
    // Look for more reliable indicators of a collaborative room
    if (widget.room['original_id'] != null &&
        widget.room['original_id'].toString().isNotEmpty) {
      // Rooms with original_id are likely shared/collaborative rooms
      setState(() {
        isCollab = true;
      });
    } else if (widget.room['is_favorite'] != null) {
      // Rooms from database usually have is_favorite (snake_case)
      setState(() {
        isCollab = true;
      });
    } else if (widget.room['room_type'] == 'collaborative' ||
        widget.room['isCollaborative'] == true) {
      // Direct indicators if available
      setState(() {
        isCollab = true;
      });
    } else {
      // Default to non-collaborative
      setState(() {
        isCollab = false;
      });
    }

    print("Room collaboration status: $isCollab");
  }

  void _toggleViewMode() {
    setState(() {
      _isListView = !_isListView;
    });
  }

  void _checkRole() {
    // Check the role of the user in the room
    if (widget.room['role_id'] != null) {
      setState(() {
        role = widget.room['role_id'];
      });
    } else {
      setState(() {
        role = 'viewer'; // Default to viewer if no role is specified
      });
    }
    print("User role in room: $role");
  }

  void _subscribeToRoleChanges() {
    // Define the update function
    void updateRoleFromProvider() {
      if (!mounted) {
        return; // Add this check to prevent setState on unmounted widget
      }

      final updatedRoom = _roomDBProvider.rooms.firstWhere(
        (r) => r['id'] == widget.room['id'],
        orElse: () => widget.room,
      );

      if (updatedRoom['role_id'] != role) {
        if (mounted) {
          // Double-check we're still mounted
          setState(() {
            role = updatedRoom['role_id'] ?? 'viewer';
          });
          print("Role updated to: $role");
        }
      }
    }

    // Store reference to our listener so we can remove it later
    _roleUpdateListener = updateRoleFromProvider;

    // Initial check
    updateRoleFromProvider();

    // Setup a listener for future changes
    _roomDBProvider.addListener(updateRoleFromProvider);
  }

  void _connectToSocket() {
    _socketService
        .initializeSocket(widget.room['id'], context, // Pass the context
            (success, error) {
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
    if (_roleUpdateListener != null) {
      _roomDBProvider.removeListener(_roleUpdateListener!);
    }
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
        roomId: widget.room['id'],
        parentId: _navigationService.currentParentId,
        isInFolder: _navigationService.isInFolder,
        isCollab: isCollab,
        onClose: OverlayService.hideOverlay,
      ),
    );
  }

  void _showCreateFileOverlay() {
    if (isCollab) {
      OverlayService.showOverlay(
        context,
        OverlayCreateFile(
          roomId: widget.room['id'],
          parentId: _navigationService.currentParentId,
          isInFolder: _navigationService.isInFolder,
          isCollab: isCollab,
          role: role,
          socketService: _socketService,
          onClose: OverlayService.hideOverlay,
        ),
      );
    } else {
      OverlayService.showOverlay(
        context,
        OverlayCreateFile(
          roomId: widget.room['id'],
          parentId: _navigationService.currentParentId,
          isInFolder: _navigationService.isInFolder,
          isCollab: isCollab,
          role: role,
          socketService: null,
          onClose: OverlayService.hideOverlay,
        ),
      );
    }
  }

  void _importPDF() {
    final fileProvider = Provider.of<FileProvider>(context, listen: false);
    final paperProvider = Provider.of<PaperProvider>(context, listen: false);
    final fileDBProvider = Provider.of<FileDBProvider>(context, listen: false);
    final paperDBProvider =
        Provider.of<PaperDBProvider>(context, listen: false);

    if (isCollab) {
      PdfDBService(
        showError: (message) => ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message))),
        showSuccess: (message) => ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message))),
        onImportComplete: (fileId, name) {
          _navigateToPaperDBPage(name, fileId, isCollab, role);
        },
        showLoading: () => _showLoadingOverlay(),
        hideLoading: () => OverlayService.hideOverlay(),
      ).importPDFDB(
        parentId: _navigationService.currentParentId,
        isInFolder: _navigationService.isInFolder,
        roomId: widget.room['id'],
        addFile: fileDBProvider.addFile,
        addPaper: paperDBProvider.addPaper,
      );
    } else {
      PdfService(
        showError: (message) => ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message))),
        showSuccess: (message) => ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message))),
        onImportComplete: (fileId, name) {
          _navigateToPaperPage(name, fileId, isCollab);
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

  void _navigateToPaperPage(String name, String fileId, bool isCollab) {
    MyApp.navMenuKey.currentState?.toggleBottomNavVisibility(false);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaperPage(
          name: name,
          fileId: fileId,
          onFileUpdated: () => setState(() {}),
          roomId: widget.room['id'],
        ),
      ),
    ).then((_) {
      MyApp.navMenuKey.currentState?.toggleBottomNavVisibility(true);
    });
  }

  void _navigateToPaperDBPage(
      String name, String fileId, bool isCollab, String isRole) {
    MyApp.navMenuKey.currentState?.toggleBottomNavVisibility(false);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaperDBPage(
          socket: _socketService,
          collab: isCollab,
          name: name,
          fileId: fileId,
          roomId: widget.room['id'],
          role: isRole,
          onFileUpdated: () => setState(() {}),
        ),
      ),
    ).then((_) {
      MyApp.navMenuKey.currentState?.toggleBottomNavVisibility(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RoomDBProvider>(
      builder: (context, roomDBProvider, _) {
        return ListenableBuilder(
          listenable: _navigationService,
          builder: (context, _) {
            return Scaffold(
              appBar: _buildAppBar(context),
              body: _buildBody(context),
              floatingActionButton: (MediaQuery.of(context).size.width <= 600 &&
                      (role == 'owner' || role == 'write' || isCollab == false))
                  ? FloatingActionButton(
                      onPressed: () => showOverlaySelect(context,
                          Offset(MediaQuery.of(context).size.width / 2, 200)),
                      backgroundColor: Colors.blue,
                      child: const Icon(Icons.add, color: Colors.white),
                    )
                  : null,
            );
          },
        );
      },
    );
  }

  PreferredSize _buildAppBar(BuildContext context) {
    final roomProvider = Provider.of<RoomProvider>(context, listen: false);
    final roomDBProvider = Provider.of<RoomDBProvider>(context, listen: false);
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
          // View toggle button
          IconButton(
            icon: Icon(
              _isListView ? Icons.grid_view : Icons.view_list,
              color: Colors.white,
            ),
            tooltip:
                _isListView ? 'Switch to grid view' : 'Switch to list view',
            onPressed: _toggleViewMode,
          ),
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
                  !_navigationService.currentRoom['isFavorite'];
                });
              },
            ),
          if (role == 'owner' || role == 'write' || isCollab == false)
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Share this room',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => ShareDialog(
                    roomId: _navigationService.currentRoom['id'],
                    roomName: _navigationService.currentRoom['name'],
                    isCollab: isCollab,
                  ),
                );
              },
            ),
          if (role == 'owner')
            IconButton(
              icon: const Icon(Icons.group),
              tooltip: 'Settings Permissions',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => SettingsMember(
                    roomId: _navigationService.currentRoom['id'],
                    originalId: _navigationService.currentRoom['original_id'],
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
    double screenWidth = MediaQuery.of(context).size.width;

    // For phones, simplify the breadcrumb and add scroll for overflow
    if (screenWidth < 600) {
      // Adjust this threshold as needed for phones
      if (fullPath.length < 5) {
        return SingleChildScrollView(
          // Allow scrolling if there's overflow
          scrollDirection: Axis.horizontal,
          child: Row(
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
          ),
        );
      } else {
        // Simplified breadcrumb for deep paths (phone)
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
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
          ),
        );
      }
    } else {
      // For tablets or larger screens, show the full breadcrumb
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
        // Simplified breadcrumb for deep paths (tablet)
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
  }

  Widget _buildBody(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final itemSize = screenSize.width < 600 ? 120.0 : 170.0;

    return Padding(
      padding: EdgeInsets.all(screenSize.width / 10000),
      child: Column(
        children: [Expanded(child: _buildContentView(context, itemSize))],
      ),
    );
  }

  Widget _buildContentView(BuildContext context, double itemSize) {
    if (_isListView) {
      return _buildListView(context);
    } else {
      return _buildGridView(context, itemSize);
    }
  }

  Widget _buildListView(BuildContext context) {
    final folderProvider = Provider.of<FolderProvider>(context);
    final folderDBProvider = Provider.of<FolderDBProvider>(context);
    final fileProvider = Provider.of<FileProvider>(context);
    final fileDBProvider = Provider.of<FileDBProvider>(context);
    final String currentParentId = _navigationService.currentParentId;
    final bool isInFolder = _navigationService.isInFolder;
    final folderDBs = folderDBProvider.folders;
    final fileDBs = fileDBProvider.files;
    final String room_id = widget.room['id'];

    final List<Map<String, dynamic>> folders;
    final List<Map<String, dynamic>> files;

    if (isCollab == true) {
      folders = isInFolder
          ? folderDBs
              .where((folder) => folder['sub_folder_id'] == currentParentId)
              .toList()
          : folderDBs.where((folder) {
              String folderRoomId = folder['room_id'].toString().trim();
              String currentRoomId = room_id.toString().trim();
              String subFolderId = folder['sub_folder_id'].toString().trim();
              bool roomMatch = folderRoomId == currentRoomId;
              bool subfolderMatch =
                  subFolderId == 'Unknow' || subFolderId == '';
              return roomMatch && subfolderMatch;
            }).toList();

      files = isInFolder
          ? fileDBs
              .where((file) => file['sub_folder_id'] == currentParentId)
              .toList()
          : fileDBs.where((file) {
              String folderRoomId = file['room_id'].toString().trim();
              String currentRoomId = room_id.toString().trim();
              String subFolderId = file['sub_folder_id'].toString().trim();
              bool roomMatch = folderRoomId == currentRoomId;
              bool subfolderMatch =
                  subFolderId == 'Unknow' || subFolderId == '';
              return roomMatch && subfolderMatch;
            }).toList();
    } else {
      folders = isInFolder
          ? folderProvider.folders
              .where((folder) => folder['parentFolderId'] == currentParentId)
              .toList()
          : folderProvider.folders
              .where((folder) => folder['roomId'] == currentParentId)
              .toList();

      files = isInFolder
          ? fileProvider.files
              .where((file) => file['parentFolderId'] == currentParentId)
              .toList()
          : fileProvider.files
              .where((file) => file['roomId'] == currentParentId)
              .toList();
    }

    return ListView(
      children: [
        // Folders
        ...folders.map(
          (folder) => GestureDetector(
            onTap: () => _navigationService.navigateToFolder(folder),
            child: FolderItem(
              id: folder['id'],
              name: folder['name'],
              createdDate: folder['createdDate'] ?? folder['createdAt'],
              roomId: folder['room_id'],
              originalId: folder['original_id'],
              role: role,
              color: (folder['color'] is int)
                  ? Color(folder['color'])
                  : folder['color'],
              isListView: true, // Use list view style
            ),
          ),
        ),

        // Files
        if (isCollab)
          ...files.map(
            (file) => GestureDetector(
              onTap: () => _navigateToPaperDBPage(
                  file['name'], file['id'], isCollab, role),
              child: FileDbItem(
                id: file['id'],
                name: file['name'],
                originalId: file['original_id'],
                role: role,
                createdDate: file['createdDate'] ?? file['createdAt'],
                isListView: true, // Use list view style
              ),
            ),
          )
        else
          ...files.map(
            (file) => GestureDetector(
              onTap: () =>
                  _navigateToPaperPage(file['name'], file['id'], isCollab),
              child: FileItem(
                id: file['id'],
                name: file['name'],
                createdDate: file['createdDate'] ?? file['createdAt'],
                isListView: true, // Use list view style
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGridView(BuildContext context, double itemSize) {
    final folderProvider = Provider.of<FolderProvider>(context);
    final folderDBProvider = Provider.of<FolderDBProvider>(context);
    final fileProvider = Provider.of<FileProvider>(context);
    final fileDBProvider = Provider.of<FileDBProvider>(context);
    final String currentParentId = _navigationService.currentParentId;
    final bool isInFolder = _navigationService.isInFolder;
    final folderDBs = folderDBProvider.folders;
    final fileDBs = fileDBProvider.files;
    final String room_id = widget.room['id'];

    final List<Map<String, dynamic>> folders;
    final List<Map<String, dynamic>> files;

    if (isCollab == true) {
      folders = isInFolder
          ? folderDBs
              .where((folder) => folder['sub_folder_id'] == currentParentId)
              .toList()
          : folderDBs.where((folder) {
              String folderRoomId = folder['room_id'].toString().trim();
              String currentRoomId = room_id.toString().trim();
              String subFolderId = folder['sub_folder_id'].toString().trim();
              bool roomMatch = folderRoomId == currentRoomId;
              bool subfolderMatch =
                  subFolderId == 'Unknow' || subFolderId == '';
              return roomMatch && subfolderMatch;
            }).toList();

      files = isInFolder
          ? fileDBs
              .where((file) => file['sub_folder_id'] == currentParentId)
              .toList()
          : fileDBs.where((file) {
              String folderRoomId = file['room_id'].toString().trim();
              String currentRoomId = room_id.toString().trim();
              String subFolderId = file['sub_folder_id'].toString().trim();
              bool roomMatch = folderRoomId == currentRoomId;
              bool subfolderMatch =
                  subFolderId == 'Unknow' || subFolderId == '';
              return roomMatch && subfolderMatch;
            }).toList();
    } else {
      folders = isInFolder
          ? folderProvider.folders
              .where((folder) => folder['parentFolderId'] == currentParentId)
              .toList()
          : folderProvider.folders
              .where((folder) => folder['roomId'] == currentParentId)
              .toList();

      files = isInFolder
          ? fileProvider.files
              .where((file) => file['parentFolderId'] == currentParentId)
              .toList()
          : fileProvider.files
              .where((file) => file['roomId'] == currentParentId)
              .toList();
    }

    // Create list of items for the grid
    List<Widget> gridItems = [
      // Add the "New" button
      if (role == 'owner' || role == 'write' || isCollab == false)
        GestureDetector(
          onTapDown: (TapDownDetails details) =>
              showOverlaySelect(context, details.globalPosition),
          child: UIComponents.createAddButton(
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
            createdDate: folder['createdDate'] ?? folder['createdAt'],
            roomId: folder['room_id'],
            originalId: folder['original_id'],
            role: role,
            color: (folder['color'] is int)
                ? Color(folder['color'])
                : folder['color'],
            isListView: false, // Use grid view style
          ),
        ),
      ),

      if (isCollab)
        ...files.map(
          (file) => GestureDetector(
            onTap: () => _navigateToPaperDBPage(
                file['name'], file['id'], isCollab, role),
            child: FileDbItem(
              id: file['id'],
              name: file['name'],
              originalId: file['original_id'],
              role: role,
              createdDate: file['createdDate'] ?? file['createdAt'],
              isListView: false, // Use grid view style
            ),
          ),
        )
      else
        ...files.map(
          (file) => GestureDetector(
            onTap: () =>
                _navigateToPaperPage(file['name'], file['id'], isCollab),
            child: FileItem(
              id: file['id'],
              name: file['name'],
              createdDate: file['createdDate'] ?? file['createdAt'],
              isListView: false, // Use grid view style
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
