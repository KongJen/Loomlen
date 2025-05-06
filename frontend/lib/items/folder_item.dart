import 'package:flutter/material.dart';
import 'package:frontend/providers/file_provider.dart';
import 'package:frontend/providers/folder_provider.dart';
import 'package:frontend/providers/folderdb_provider.dart';
import 'package:frontend/providers/paper_provider.dart';
import 'package:provider/provider.dart';
import 'base_item.dart';
import 'item_behaviors.dart';
import '../services/item_dialog_service.dart';

class FolderItem extends BaseItem {
  final String? roomId;
  final String? originalId;
  final String? parentFolderId;
  final String? role;
  final Color color;

  const FolderItem({
    super.key,
    required super.id,
    required super.name,
    required super.createdDate,
    this.roomId,
    this.originalId,
    this.parentFolderId,
    this.role,
    required this.color,
  });

  @override
  State<FolderItem> createState() => _FolderItemState();
}

class _FolderItemState extends State<FolderItem> with Renamable, Deletable {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final iconSize = screenWidth < 600 ? 120.0 : 170.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: iconSize,
            child: Center(
              child: Icon(
                Icons.folder_open,
                size: iconSize,
                color: widget.color,
              ),
            ),
          ),
          const SizedBox(height: 4),
          _buildItemNameRow(context, screenWidth),
          const SizedBox(height: 2.0),
          Text(
            widget.createdDate,
            style: TextStyle(
              fontSize: screenWidth < 600 ? 8 : 10,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemNameRow(BuildContext context, double screenWidth) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(width: screenWidth < 600 ? 12 : 22),
        Flexible(
          child: Text(
            widget.name,
            style: TextStyle(
              fontSize: screenWidth < 600 ? 12 : 15,
              fontWeight: FontWeight.w400,
              color: Colors.blueAccent,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 5),
        if (widget.role == 'owner' ||
            widget.role == 'write' ||
            widget.originalId == null)
          InkWell(
            onTap: () => _showOptionsOverlay(context),
            child: Icon(
              Icons.keyboard_control_key,
              size: screenWidth < 600 ? 17 : 22,
              color: Colors.blueAccent,
            ),
          ),
      ],
    );
  }

  void _showOptionsOverlay(BuildContext context) async {
    final Size screenSize = MediaQuery.of(context).size;

    // Get the icon's position
    final iconButtonRenderBox = context.findRenderObject() as RenderBox;
    final iconPosition = iconButtonRenderBox.localToGlobal(Offset.zero);

    // Set overlay dimensions
    const double overlayWidth = 350;
    const double overlayHeight =
        100; // Increased slightly to ensure all options fit
    const double margin = 10;

    // Calculate the position to display the overlay
    // Start with the position of the clicked icon
    double adjustedDx = iconPosition.dx;
    double adjustedDy = iconPosition.dy;

    // Adjust horizontal position if needed to stay on screen
    if (adjustedDx + overlayWidth > screenSize.width) {
      adjustedDx = screenSize.width - overlayWidth - margin;
    }

    // Adjust vertical position if needed to stay on screen
    if (adjustedDy + overlayHeight > screenSize.height) {
      adjustedDy = screenSize.height - overlayHeight - margin;
    }

    await ItemDialogService.showOptionsOverlay(
      context: context,
      position: Offset(adjustedDx, adjustedDy),
      itemName: widget.name,
      onRename: () => _showRenameDialog(context),
      onDelete: () => _showDeleteConfirmationDialog(context),
    );
  }

  void _showRenameDialog(BuildContext context) {
    ItemDialogService.showRenameDialog(
      context: context,
      currentName: widget.name,
      itemType: 'Folder',
      onRename: (newName) => {
        if (widget.originalId != null)
          renameDB(context, widget.id, newName)
        else
          rename(context, widget.id, newName)
      },
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    ItemDialogService.showDeleteConfirmationDialog(
      context: context,
      itemType: 'Folder',
      itemName: widget.name,
      onConfirm: () => {
        if (widget.originalId != null)
          {deleteDB(context, widget.id)}
        else
          {delete(context, widget.id)}
      },
    );
  }

  @override
  void rename(dynamic context, String id, String newName) {
    final folderProvider = Provider.of<FolderProvider>(context, listen: false);
    folderProvider.renameFolder(id, newName);
  }

  void renameDB(dynamic context, String id, String newName) {
    final folderDBProvider =
        Provider.of<FolderDBProvider>(context, listen: false);
    folderDBProvider.renameFolder(id, newName);
  }

  @override
  void delete(dynamic context, String id) {
    final folderProvider = Provider.of<FolderProvider>(context, listen: false);

    folderProvider.deleteFolder(
      id,
      Provider.of<FolderProvider>(context, listen: false),
      Provider.of<FileProvider>(context, listen: false),
      Provider.of<PaperProvider>(context, listen: false),
    );
  }

  void deleteDB(dynamic context, String id) {
    final folderDBProvider =
        Provider.of<FolderDBProvider>(context, listen: false);
    folderDBProvider.deleteFolder(id);
  }
}
