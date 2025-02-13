import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import '../widget/filedialog.dart';
import '../widget/fileitem.dart';
import 'file_detail_page.dart';

class MyFilePage extends StatefulWidget {
  @override
  State<MyFilePage> createState() => _MyFilePageState();
}

class _MyFilePageState extends State<MyFilePage> {
  OverlayEntry? _overlayEntry;
  List<Map<String, dynamic>> files = [];

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  void _loadFiles() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/files.json');

    if (await file.exists()) {
      final data = jsonDecode(await file.readAsString());

      setState(() {
        files = List<Map<String, dynamic>>.from(data).map((file) {
          return {
            'name': file['name'],
            'content': file['content'],
            'createDate': file['createDate'],
          };
        }).toList();
      });
    }
  }

  void _saveFiles() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/files.json');

    List<Map<String, dynamic>> filesToSave = files.map((file) {
      return {
        'name': file['name'],
        'content': file['content'],
        'createDate': file['createDate'],
      };
    }).toList();

    await file.writeAsString(jsonEncode(filesToSave));
  }

  void _createFile(String name, String content) {
    setState(() {
      files.add({
        'name': name,
        'content': content,
        'createDate': DateTime.now().toIso8601String(),
      });
      _saveFiles();
    });
  }

  void _updateFile(int index, String name, String content) {
    setState(() {
      files[index]['name'] = name;
      files[index]['content'] = content;
      _saveFiles();
    });
  }

  void _deleteFile(int index) {
    setState(() {
      files.removeAt(index);
      _saveFiles();
    });
  }

  void _showOverlay(BuildContext context, Widget overlayWidget) {
    _removeOverlay();
    OverlayState overlayState = Overlay.of(context)!;
    _overlayEntry = OverlayEntry(builder: (context) => overlayWidget);
    overlayState.insert(_overlayEntry!);
  }

  void showCreateFileOverlay() {
    showDialog(
      context: context,
      builder: (context) => CreateFileDialog(
        onClose: () => Navigator.pop(context),
        onFileCreated: (String name, String content) {
          _createFile(name, content);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(100.0),
        child: AppBar(
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey, width: 1),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top,
                left: 60,
                right: 16,
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 35,
                    left: 0,
                    child: Text(
                      'My Files',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(2.0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  crossAxisSpacing: 1.0,
                  mainAxisSpacing: 16.0,
                  childAspectRatio: 1,
                ),
                itemCount: files.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return GestureDetector(
                      onTap: showCreateFileOverlay,
                      child: Column(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 50.0),
                            child: DottedBorder(
                              borderType: BorderType.RRect,
                              radius: Radius.circular(8.0),
                              dashPattern: [8, 4],
                              color: Colors.blue,
                              strokeWidth: 2,
                              child: Container(
                                width: 100.0,
                                height: 100.0,
                                alignment: Alignment.center,
                                child: const Icon(Icons.add,
                                    size: 32, color: Colors.blue),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text("New File",
                              style: TextStyle(color: Colors.blue)),
                        ],
                      ),
                    );
                  } else {
                    final file = files[index - 1];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FileDetailPage(
                              file: file,
                              onFileUpdated: (String name, String content) {
                                _updateFile(index - 1, name, content);
                              },
                              onFileDeleted: () {
                                _deleteFile(index - 1);
                              },
                            ),
                          ),
                        );
                      },
                      child: FileItem(
                        name: file['name'],
                        createDate: file['createDate'],
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
