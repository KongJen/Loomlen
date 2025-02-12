import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';

class FileDetailPage extends StatefulWidget {
  final Map<String, dynamic> file;
  final Function(String name, String content) onFileUpdated;
  final Function() onFileDeleted;

  const FileDetailPage({
    required this.file,
    required this.onFileUpdated,
    required this.onFileDeleted,
  });

  @override
  State<FileDetailPage> createState() => _FileDetailPageState();
}

class _FileDetailPageState extends State<FileDetailPage> {
  late TextEditingController nameController;
  late TextEditingController contentController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.file['name']);
    contentController = TextEditingController(text: widget.file['content']);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit File'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () {
              widget.onFileDeleted();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: 'File Name'),
            ),
            SizedBox(height: 16),
            TextField(
              controller: contentController,
              decoration: InputDecoration(labelText: 'Content'),
              maxLines: 10,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                widget.onFileUpdated(
                  nameController.text,
                  contentController.text,
                );
                Navigator.pop(context);
              },
              child: Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
