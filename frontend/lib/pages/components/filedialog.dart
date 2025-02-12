import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';

class CreateFileDialog extends StatefulWidget {
  final Function() onClose;
  final Function(String name, String content) onFileCreated;

  const CreateFileDialog({
    required this.onClose,
    required this.onFileCreated,
  });

  @override
  State<CreateFileDialog> createState() => _CreateFileDialogState();
}

class _CreateFileDialogState extends State<CreateFileDialog> {
  final nameController = TextEditingController();
  final contentController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Create New File'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: InputDecoration(labelText: 'File Name'),
          ),
          SizedBox(height: 16),
          TextField(
            controller: contentController,
            decoration: InputDecoration(labelText: 'Content'),
            maxLines: 5,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.onClose,
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onFileCreated(
              nameController.text,
              contentController.text,
            );
          },
          child: Text('Create'),
        ),
      ],
    );
  }
}
