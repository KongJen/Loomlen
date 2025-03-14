import 'package:flutter/material.dart';
import 'package:frontend/model/provider.dart';
import 'package:frontend/widget/overlay_option.dart';
import 'package:frontend/widget/delete_dialog.dart';
import 'package:frontend/widget/rename_dialog.dart';
import 'dart:ui' as ui;

import 'package:provider/provider.dart';

/*--------------RoomItem--------------------*/
class RoomItem extends StatefulWidget {
  final String id;
  final String name;
  final String createdDate;
  final Color color;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final List<String> folderIds;
  final List<String> fileIds;

  const RoomItem({
    super.key,
    required this.id,
    required this.name,
    required this.createdDate,
    required this.color,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.folderIds,
    required this.fileIds,
  });

  @override
  State<RoomItem> createState() => _RoomItemState();
}

class _RoomItemState extends State<RoomItem> {
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
              // Center the icon
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
          Row(
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
                onTap: () {
                  _showOptionsOverlay(context);
                },
                child: Icon(
                  Icons.keyboard_control_key,
                  size: screenWidth < 600 ? 12 : 15,
                  color: Colors.blueAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2.0),
          Text(
            widget.createdDate,
            style: TextStyle(
              fontSize: screenWidth < 600 ? 8 : 10,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  void _showOptionsOverlay(BuildContext context) async {
    // Get the position of the icon
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset position = renderBox.localToGlobal(Offset.zero);

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
              itemName: widget.name,
              onRename: () {
                _showRenameDialog(context);
              },
              onDelete: () {
                _showDeleteConfirmationDialog(context);
              },
            ),
          ],
        );
      },
    );
  }

  void _showRenameDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return RenameDialog(
          currentName: widget.name,
          itemType: 'Room',
          onRename: (newName) {
            final roomProvider = Provider.of<RoomProvider>(
              context,
              listen: false,
            );
            roomProvider.renameRoom(widget.id, newName);
          },
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return DeleteConfirmationDialog(
          itemType: 'Room',
          itemName: widget.name,
          onConfirm: () {
            final roomProvider = Provider.of<RoomProvider>(
              context,
              listen: false,
            );
            roomProvider.deleteRoom(widget.id);
          },
        );
      },
    );
  }
}

/*--------------FolderItem--------------------*/

class FolderItem extends StatefulWidget {
  final String id;
  final String name;
  final String createdDate;
  final Color color;
  final List<String> subfolderIds;
  final List<String> fileIds;

  const FolderItem({
    super.key,
    required this.id,
    required this.name,
    required this.createdDate,
    required this.color,
    required this.subfolderIds,
    required this.fileIds,
  });

  @override
  State<FolderItem> createState() => _FolderItemState();
}

class _FolderItemState extends State<FolderItem> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final iconSize = screenWidth < 600 ? 120.0 : 170.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: iconSize,
            child: Center(
              child: Icon(
                Icons.folder_open,
                size: iconSize,
                color: widget.color,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
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
                onTap: () {
                  _showOptionsOverlay(context);
                },
                child: Icon(
                  Icons.keyboard_control_key,
                  size: screenWidth < 600 ? 12 : 15,
                  color: Colors.blueAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2.0),
          Text(
            widget.createdDate,
            style: TextStyle(
              fontSize: screenWidth < 600 ? 8 : 10,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  void _showOptionsOverlay(BuildContext context) async {
    // Get the position of the icon
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset position = renderBox.localToGlobal(Offset.zero);

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
              itemName: widget.name,
              onRename: () {
                _showRenameDialog(context);
              },
              onDelete: () {
                _showDeleteConfirmationDialog(context);
              },
            ),
          ],
        );
      },
    );
  }

  void _showRenameDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return RenameDialog(
          currentName: widget.name,
          itemType: 'Folder',
          onRename: (newName) {
            // Add folder rename function to your provider
            final folderProvider = Provider.of<FolderProvider>(
              context,
              listen: false,
            );
            // Implement renameFolder in your FolderProvider
            folderProvider.renameFolder(widget.id, newName);
          },
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return DeleteConfirmationDialog(
          itemType: 'Folder',
          itemName: widget.name,
          onConfirm: () {
            final folderProvider = Provider.of<FolderProvider>(
              context,
              listen: false,
            );
            folderProvider.deleteFolder(widget.id);
          },
        );
      },
    );
  }
}

/*--------------FileItem--------------------*/

class FileItem extends StatefulWidget {
  final String id;
  final String name;
  final String createdDate;
  final String? pdfPath;
  final List<String>? pageIds;

  const FileItem({
    super.key,
    required this.id,
    required this.name,
    required this.createdDate,
    this.pdfPath,
    this.pageIds,
  });

  @override
  State<FileItem> createState() => _FileItemState();
}

class _FileItemState extends State<FileItem> {
  ui.Image? backgroundImage;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
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
            Stack(
              children: [
                Container(
                  width: containerWidth,
                  height: containerHeight,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: const Stack(
                      children: [
                        // Show either PDF thumbnail or template
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 34),
            Row(
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
                  onTap: () {
                    _showOptionsOverlay(context);
                  },
                  child: Icon(
                    Icons.keyboard_control_key,
                    size: screenWidth < 600 ? 12 : 15,
                    color: Colors.blueAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2.0),
            Text(
              widget.createdDate,
              style: TextStyle(
                fontSize: screenWidth < 600 ? 8 : 10,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptionsOverlay(BuildContext context) async {
    // Get the position of the icon
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset position = renderBox.localToGlobal(Offset.zero);

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
              itemName: widget.name,
              onRename: () {
                _showRenameDialog(context);
              },
              onDelete: () {
                _showDeleteConfirmationDialog(context);
              },
            ),
          ],
        );
      },
    );
  }

  void _showRenameDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return RenameDialog(
          currentName: widget.name,
          itemType: 'File',
          onRename: (newName) {
            final fileProvider = Provider.of<FileProvider>(
              context,
              listen: false,
            );
            fileProvider.renameFile(widget.id, newName);
          },
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return DeleteConfirmationDialog(
          itemType: 'File',
          itemName: widget.name,
          onConfirm: () {
            final fileProvider = Provider.of<FileProvider>(
              context,
              listen: false,
            );
            fileProvider.deleteFile(widget.id);
          },
        );
      },
    );
  }
}

//--------------- Paper Pages -----------------------//

class PaperItem extends StatefulWidget {
  final String id;
  final String? pdfPath;
  final String? recognizedText;
  final String templateId; // Changed from template string to templateId
  final TemplateType templateType; // Added template type
  // ignore: non_constant_identifier_names
  final int PageNumber;
  final double? widht;
  final double? height;

  const PaperItem({
    super.key,
    required this.id,
    this.pdfPath,
    this.recognizedText,
    this.templateId = 'plain',
    this.templateType = TemplateType.plain,
    // ignore: non_constant_identifier_names
    required this.PageNumber,
    this.height,
    this.widht,
  });

  @override
  State<PaperItem> createState() => _PaperState();
}

class _PaperState extends State<PaperItem> {
  @override
  Widget build(BuildContext context) {
    return Container(); // Implement your widget build logic here
  }
}

//--------------- Paper Template -----------------------//

class PaperTemplate {
  final String id;
  final String name;
  final Color backgroundColor;
  final Color lineColor;
  final double lineWidth;
  final TemplateType templateType;
  final double spacing;

  const PaperTemplate({
    required this.id,
    required this.name,
    this.backgroundColor = Colors.white,
    this.lineColor = const Color(0xFFCCCCCC),
    this.lineWidth = 1.0,
    this.templateType = TemplateType.plain,
    this.spacing = 30.0,
  });

  void paintTemplate(Canvas canvas, Size size) {
    // Fill the background
    final Paint backgroundPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    final Paint linePaint =
        Paint()
          ..color = lineColor
          ..strokeWidth = lineWidth
          ..style = PaintingStyle.stroke;

    // Draw template based on type
    switch (templateType) {
      case TemplateType.plain:
        // Plain paper has just the background
        break;
      case TemplateType.lined:
        _drawLinedPaper(canvas, size, linePaint);
        break;
      case TemplateType.grid:
        _drawGridPaper(canvas, size, linePaint);
        break;
      case TemplateType.dotted:
        _drawDottedPaper(canvas, size, linePaint);
        break;
    }
  }

  void _drawLinedPaper(Canvas canvas, Size size, Paint paint) {
    for (double y = spacing; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawGridPaper(Canvas canvas, Size size, Paint paint) {
    // Draw horizontal lines
    for (double y = spacing; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw vertical lines
    for (double x = spacing; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  void _drawDottedPaper(Canvas canvas, Size size, Paint paint) {
    final radius = 1.0;

    paint.style = PaintingStyle.fill;

    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }
}

enum TemplateType { plain, lined, grid, dotted }

class TemplateThumbnailPainter extends CustomPainter {
  final PaperTemplate template;

  TemplateThumbnailPainter({required this.template});

  @override
  void paint(Canvas canvas, Size size) {
    template.paintTemplate(canvas, size);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

//---------------------------------------------------------//
