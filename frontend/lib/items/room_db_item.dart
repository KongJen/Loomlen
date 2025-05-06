// ignore_for_file: non_constant_identifier_names, avoid_types_as_parameter_names

import 'package:flutter/material.dart';
import 'package:frontend/providers/roomdb_provider.dart';
import 'package:frontend/services/roomDB_dialog_service.dart';
import 'package:provider/provider.dart';
import 'base_item.dart';
import 'item_behaviors.dart';

class RoomDBItem extends BaseItem {
  final Color color;
  final bool is_favorite;
  final String originalId;
  final String role;
  final VoidCallback onToggleFavorite;

  final String updatedAt;

  const RoomDBItem({
    super.key,
    required super.id,
    required super.name,
    required super.createdDate,
    required this.originalId,
    required this.color,
    required this.is_favorite,
    required this.role,
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
                        color: widget.is_favorite
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

    await ItemRoomDialogService.showRoomOptionsOverlay(
      context: context,
      position: Offset(adjustedDx, adjustedDy),
      itemName: widget.name,
      onRename: () => _showRenameDialog(context),
      onDelete: () => _showDeleteConfirmationDialog(context),
      originalId: widget.originalId,
      role: widget.role,
    );
  }

  void _showRenameDialog(BuildContext context) {
    ItemRoomDialogService.showRenameDialog(
      context: context,
      currentName: widget.name,
      itemType: 'Room',
      onRename: (newName) => rename(context, widget.id, newName),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    ItemRoomDialogService.showDeleteConfirmationDialog(
      context: context,
      itemType: 'Room',
      itemName: widget.name,
      onConfirm: () => widget.role == "owner"
          ? delete(context, widget.id)
          : exitRoom(context, widget.id),
    );
  }

  @override
  void rename(dynamic context, String id, String newName) {
    print("Renaming room with ID: $id to new name: $newName");
    final roomDBProvider = Provider.of<RoomDBProvider>(context, listen: false);
    roomDBProvider.renameRoom(id, newName);
  }

  @override
  void delete(dynamic context, String id) {
    final roomDBProvider = Provider.of<RoomDBProvider>(context, listen: false);
    roomDBProvider.deleteRoom(id);
  }

  void exitRoom(BuildContext context, String id) {
    final roomDBProvider = Provider.of<RoomDBProvider>(context, listen: false);
    roomDBProvider.exitRoom(id);
  }

  void toggleFavorite(BuildContext context, String id, bool isFavorite) {
    widget.onToggleFavorite();
  }

  @override
  void favorite(BuildContext, String id, bool isFavorite) {
    final roomDBProvider = Provider.of<RoomDBProvider>(context, listen: false);
    roomDBProvider.toggleFavorite(id);
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
