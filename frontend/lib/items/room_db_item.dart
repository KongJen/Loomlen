// ignore_for_file: non_constant_identifier_names, avoid_types_as_parameter_names

import 'package:flutter/material.dart';
import 'package:frontend/providers/file_provider.dart';
import 'package:frontend/providers/folder_provider.dart';
import 'package:frontend/providers/paper_provider.dart';
import 'package:frontend/providers/room_provider.dart';
import 'package:provider/provider.dart';
import 'base_item.dart';
import 'item_behaviors.dart';
import '../services/item_dialog_service.dart';

class RoomDBItem extends BaseItem {
  final Color color;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final String updatedAt;

  const RoomDBItem({
    super.key,
    required super.id,
    required super.name,
    required super.createdDate,
    required this.color,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.updatedAt,
  });

  @override
  State<RoomDBItem> createState() => _RoomDBItemState();
}

class _RoomDBItemState extends State<RoomDBItem>
    with Renamable, Deletable, Favoritable {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final iconSize = screenWidth < 600 ? 120.0 : 170.0;
    final starIconSize = iconSize * 0.3;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: iconSize,
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.home_filled, size: iconSize, color: widget.color),
                  Positioned(
                    right: iconSize * 0.09,
                    top: iconSize * 0.09,
                    child: IconButton(
                      icon: Icon(
                        Icons.star_rate_rounded,
                        size: starIconSize,
                        color:
                            widget.isFavorite
                                ? Colors.red
                                : const Color.fromARGB(255, 212, 212, 212),
                        shadows: const [
                          BoxShadow(
                            color: Colors.black,
                            blurRadius: 2,
                            offset: Offset(-0.5, 0.5),
                          ),
                        ],
                      ),
                      onPressed: widget.onToggleFavorite,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          _buildItemNameRow(context, screenWidth),
          Text(
            'Created At: ${widget.createdDate}',
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
      itemType: 'Room',
      onRename: (newName) => rename(context, widget.id, newName),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    ItemDialogService.showDeleteConfirmationDialog(
      context: context,
      itemType: 'Room',
      itemName: widget.name,
      onConfirm: () => delete(context, widget.id),
    );
  }

  @override
  void rename(dynamic context, String id, String newName) {
    final roomProvider = Provider.of<RoomProvider>(context, listen: false);
    roomProvider.renameRoom(id, newName);
  }

  @override
  void delete(dynamic context, String id) {
    final roomProvider = Provider.of<RoomProvider>(context, listen: false);
    roomProvider.deleteRoom(
      id,
      Provider.of<FolderProvider>(context, listen: false),
      Provider.of<FileProvider>(context, listen: false),
      Provider.of<PaperProvider>(context, listen: false),
    );
  }

  void toggleFavorite(BuildContext context, String id, bool isFavorite) {
    widget.onToggleFavorite();
  }

  @override
  void favorite(BuildContext, String id, bool isFavorite) {
    final roomProvider = Provider.of<RoomProvider>(context, listen: false);
    roomProvider.toggleFavorite(id);
  }
}

Color parseColor(String? colorString) {
  if (colorString == null || colorString.isEmpty) {
    return Colors.grey; // Default color if the color string is empty or null
  }

  // Remove the leading '#' if present
  if (colorString.startsWith('#')) {
    colorString = colorString.substring(1);
  }

  // Parse the color string to an integer
  int colorValue;
  try {
    colorValue = int.parse(colorString, radix: 16);
  } catch (e) {
    return Colors.grey; // Default color if parsing fails
  }

  // If the color string is in the format #RRGGBB, add the alpha value
  if (colorString.length == 6) {
    colorValue = 0xFF000000 | colorValue;
  }

  return Color(colorValue);
}
