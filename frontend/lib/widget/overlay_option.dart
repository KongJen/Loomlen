import 'package:flutter/material.dart';

class OverlayOptions extends StatelessWidget {
  final Offset position;
  final String itemName;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final List<Widget>? additionalOptions;

  const OverlayOptions({
    Key? key,
    required this.position,
    required this.itemName,
    required this.onRename,
    required this.onDelete,
    this.additionalOptions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx - 100, // Adjust position as needed
      top: position.dy + 20,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 160,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with item name
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                ),
                child: Text(
                  itemName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Options
              ListTile(
                dense: true,
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('Rename'),
                onTap: () {
                  Navigator.of(context).pop();
                  onRename();
                },
              ),
              const Divider(height: 1),
              ListTile(
                dense: true,
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete'),
                onTap: () {
                  Navigator.of(context).pop();
                  onDelete();
                },
              ),
              // Additional options if provided
              if (additionalOptions != null) ...additionalOptions!,
            ],
          ),
        ),
      ),
    );
  }
}
