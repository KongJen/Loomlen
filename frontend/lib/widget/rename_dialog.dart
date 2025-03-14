import 'package:flutter/material.dart';

class RenameDialog extends StatefulWidget {
  final String currentName;
  final String itemType; // "Room", "Folder", or "File"
  final Function(String) onRename;

  const RenameDialog({
    super.key,
    required this.currentName,
    required this.itemType,
    required this.onRename,
  });

  @override
  State<RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<RenameDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Rename ${widget.itemType}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: '${widget.itemType} Name',
                hintText: 'Enter new name',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    if (_controller.text.trim().isNotEmpty) {
                      widget.onRename(_controller.text.trim());
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Rename'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
