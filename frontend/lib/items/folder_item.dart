import 'package:flutter/material.dart';
import 'package:frontend/providers/file_provider.dart';
import 'package:frontend/providers/folder_provider.dart';
import 'package:frontend/providers/paper_provider.dart';
import 'package:provider/provider.dart';
import 'base_item.dart';
import 'item_behaviors.dart';
import '../services/item_dialog_service.dart';

class FolderItem extends BaseItem {
  final String? roomId;
  final String? parentFolderId;
  final Color color;

  const FolderItem({
    super.key,
    required super.id,
    required super.name,
    required super.createdDate,
    this.roomId,
    this.parentFolderId,
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
        InkWell(
          onTap: () => _showOptionsOverlay(context),
          child: Icon(
            Icons.keyboard_control_key,
            size: screenWidth < 600 ? 12 : 15,
            color: Colors.blueAccent,
          ),
        ),
      ],
    );
  }

  void _showOptionsOverlay(BuildContext context) async {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset position = renderBox.localToGlobal(Offset.zero);

    await ItemDialogService.showOptionsOverlay(
      context: context,
      position: position,
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
      onRename: (newName) => rename(context, widget.id, newName),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    ItemDialogService.showDeleteConfirmationDialog(
      context: context,
      itemType: 'Folder',
      itemName: widget.name,
      onConfirm: () => delete(context, widget.id),
    );
  }

  @override
  void rename(dynamic context, String id, String newName) {
    final folderProvider = Provider.of<FolderProvider>(context, listen: false);
    folderProvider.renameFolder(id, newName);
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
}
