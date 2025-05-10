// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:frontend/items/paperDb_preview_item.dart';
import 'package:frontend/providers/filedb_provider.dart';
import 'package:provider/provider.dart';
import 'base_item.dart';
import 'item_behaviors.dart';
import '../services/item_dialog_service.dart';

class FileDbItem extends BaseItem {
  final String? roomId;
  final String? originalId;
  final String? role;
  final String? parentFolderId;
  final String? pdfPath;
  final bool isListView;

  const FileDbItem({
    super.key,
    required super.id,
    required super.name,
    required super.createdDate,
    this.roomId,
    this.originalId,
    this.role,
    this.parentFolderId,
    this.pdfPath,
    this.isListView = false, // 👈 add default
  });

  @override
  State<FileDbItem> createState() => _FileItemState();
}

class _FileItemState extends State<FileDbItem> with Renamable, Deletable {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (widget.isListView) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 60,
              height: 80,
              child: PaperDBPreviewItem(
                fileId: widget.id,
                maxWidth: 60,
                maxHeight: 80,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueAccent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(widget.createdDate),
                      style: TextStyle(
                        fontSize: screenWidth < 600 ? 10 : 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.role == 'owner' || widget.role == 'write')
              IconButton(
                icon: const Icon(Icons.keyboard_control_key,
                    color: Colors.blueAccent),
                onPressed: () => _showOptionsOverlay(context),
              ),
          ],
        ),
      );
    }

    // 🟦 Grid layout (default)
    final containerWidth = screenWidth < 600 ? 90.0 : 120.0;
    final containerHeight = screenWidth < 600 ? 110.0 : 150.0;

    return SizedBox(
      width: containerWidth,
      height: containerHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildFilePreview(containerWidth, containerHeight),
            const SizedBox(height: 34),
            _buildItemNameRow(context, screenWidth),
            const SizedBox(height: 2.0),
            Text(
              _formatDate(widget.createdDate),
              style: TextStyle(
                fontSize: screenWidth < 600 ? 10 : 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String rawDate) {
    try {
      final date = DateTime.parse(rawDate);
      return "${_monthName(date.month)} ${date.day}, ${date.year}";
    } catch (_) {
      return rawDate; // fallback for invalid date
    }
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  Widget _buildFilePreview(double width, double height) {
    return Center(
      child: SizedBox(
        height: 140, // Set the fixed height you want
        width: width, // Use the dynamic width passed as parameter
        child: PaperDBPreviewItem(
          fileId: widget.id,
          maxWidth: width,
          maxHeight: height,
        ),
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
        if (widget.role == 'owner' || widget.role == 'write')
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
      itemType: 'File',
      onRename: (newName) => rename(context, widget.id, newName),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    ItemDialogService.showDeleteConfirmationDialog(
      context: context,
      itemType: 'File',
      itemName: widget.name,
      onConfirm: () => delete(context, widget.id),
    );
  }

  @override
  void rename(dynamic context, String id, String newName) {
    final fileDBProvider = Provider.of<FileDBProvider>(context, listen: false);
    fileDBProvider.renameFile(id, newName);
  }

  @override
  void delete(dynamic context, String id) {
    final fileDBProvider = Provider.of<FileDBProvider>(context, listen: false);
    fileDBProvider.deleteFile(id);
  }
}
