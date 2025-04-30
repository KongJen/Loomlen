import 'package:flutter/material.dart';
import 'package:frontend/widget/overlay_option.dart';
import 'package:frontend/widget/delete_dialog.dart';
import 'package:frontend/widget/rename_dialog.dart';

class ItemDialogService {
  static Future<void> showOptionsOverlay({
    required BuildContext context,
    required Offset position,
    required String itemName,
    required VoidCallback onRename,
    required VoidCallback onDelete,
  }) async {
    await showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (BuildContext context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(color: Colors.transparent),
              ),
            ),
            OverlayOptions(
              position: position,
              itemName: itemName,
              onRename: onRename,
              onDelete: onDelete,
            ),
          ],
        );
      },
    );
  }

  static void showRenameDialog({
    required BuildContext context,
    required String currentName,
    required String itemType,
    required Function(String) onRename,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return RenameDialog(
          currentName: currentName,
          itemType: itemType,
          onRename: onRename,
        );
      },
    );
  }

  static void showDeleteConfirmationDialog({
    required BuildContext context,
    required String itemType,
    required String itemName,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return DeleteConfirmationDialog(
          itemType: itemType,
          itemName: itemName,
          onConfirm: onConfirm,
        );
      },
    );
  }
}
