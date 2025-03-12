import 'package:flutter/material.dart';

class DeleteConfirmationDialog extends StatelessWidget {
  final String itemType; // "Room", "Folder", or "File"
  final String itemName;
  final VoidCallback onConfirm;

  const DeleteConfirmationDialog({
    Key? key,
    required this.itemType,
    required this.itemName,
    required this.onConfirm,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Delete $itemType'),
      content: Text(
        'Are you sure you want to delete "$itemName"? This action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            onConfirm();
            Navigator.of(context).pop();
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
