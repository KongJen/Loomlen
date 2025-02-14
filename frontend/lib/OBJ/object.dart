import 'dart:convert';

import 'package:flutter/material.dart';
import 'dart:ui' as ui;

/*--------------RoomItem--------------------*/
class RoomItem extends StatefulWidget {
  final String id;
  final String name;
  final String createdDate;
  final Color color;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final List<String> folderIds;

  const RoomItem({
    Key? key,
    required this.id,
    required this.name,
    required this.createdDate,
    required this.color,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.folderIds,
  }) : super(key: key);

  @override
  State<RoomItem> createState() => _RoomItemState();
}

class _RoomItemState extends State<RoomItem> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            children: [
              Icon(
                Icons.home_filled,
                size: 170,
                color: widget.color,
              ),
              Positioned(
                right: 15,
                top: 15,
                child: IconButton(
                  icon: Icon(Icons.star_rate_rounded,
                      size: 50,
                      color: widget.isFavorite
                          ? Colors.red // Show red if favorite
                          : const Color.fromARGB(255, 212, 212, 212),
                      shadows: [
                        BoxShadow(
                          color: Colors.black,
                          blurRadius: 2,
                          offset: Offset(-0.5, 0.5),
                        )
                      ]),
                  onPressed:
                      widget.onToggleFavorite, // Trigger the toggle callback
                ),
              ),
            ],
          ),
          Text(
            widget.name,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Colors.blueAccent,
            ),
          ),
          SizedBox(height: 2.0),
          Text(
            widget.createdDate,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

/*--------------FolderItem--------------------*/
class FolderItem extends StatefulWidget {
  final String id;
  final String name;
  final String createdDate;
  final Color color;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final List<String> subfolderIds;
  final List<String> fileIds;

  const FolderItem({
    Key? key,
    required this.id,
    required this.name,
    required this.createdDate,
    required this.color,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.subfolderIds,
    required this.fileIds,
  }) : super(key: key);

  @override
  State<FolderItem> createState() => _FolderItemState();
}

class _FolderItemState extends State<FolderItem> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            children: [
              Icon(
                Icons.folder_open,
                size: 170,
                color: widget.color,
              ),
              Positioned(
                right: 15,
                top: 15,
                child: IconButton(
                  icon: Icon(Icons.star_rate_rounded,
                      size: 50,
                      color: widget.isFavorite
                          ? Colors.red // Show red if favorite
                          : const Color.fromARGB(255, 212, 212, 212),
                      shadows: [
                        BoxShadow(
                          color: Colors.black,
                          blurRadius: 2,
                          offset: Offset(-0.5, 0.5),
                        )
                      ]),
                  onPressed: widget.onToggleFavorite,
                ),
              ),
            ],
          ),
          Text(
            widget.name,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Colors.blueAccent,
            ),
          ),
          SizedBox(height: 2.0),
          Text(
            widget.createdDate,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

/*--------------FileItem--------------------*/

class FileItem extends StatefulWidget {
  final String id;
  final String name;
  final String createdDate;
  final String template;
  // final List<DrawingState> history;
  final int currentHistoryIndex;
  final String? recognizedText;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  const FileItem({
    Key? key,
    required this.id,
    required this.name,
    required this.createdDate,
    this.template = 'blank',
    // required this.history,
    this.currentHistoryIndex = -1,
    this.recognizedText,
    required this.isFavorite,
    required this.onToggleFavorite,
  }) : super(key: key);

  @override
  State<FileItem> createState() => _FileItemState();
}

class _FileItemState extends State<FileItem> {
  ui.Image? backgroundImage;

  @override
  void initState() {
    super.initState();
    // _loadPreview();
  }

  // Future<void> _loadPreview() async {
  //   if (widget.history.isNotEmpty && widget.currentHistoryIndex >= 0) {
  //     final currentState = widget.history[widget.currentHistoryIndex];
  //     if (currentState.imageData != null) {
  //       await _loadBackgroundImage(currentState.imageData!);
  //     }
  //   }
  // }

  Future<void> _loadBackgroundImage(String base64Image) async {
    try {
      final bytes = base64Decode(base64Image);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          backgroundImage = frame.image;
        });
      }
    } catch (e) {
      print('Error loading preview: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            children: [
              Container(
                width: 170,
                height: 170,
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
                  child: Stack(
                    children: [
                      // Template or background
                      if (backgroundImage != null)
                        SizedBox(
                          width: 170,
                          height: 170,
                          child: CustomPaint(
                            painter: NotePainter(
                              // points: widget
                              //     .history[widget.currentHistoryIndex].points,
                              backgroundImage: backgroundImage,
                              scale: 170 / backgroundImage!.width,
                            ),
                          ),
                        )
                      else
                        // Show template preview if no background
                        _buildTemplatePreview(),

                      // Show recognized text preview if available
                      if (widget.recognizedText != null &&
                          widget.recognizedText!.isNotEmpty)
                        Positioned(
                          bottom: 5,
                          left: 5,
                          right: 5,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.recognizedText!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Favorite button
              Positioned(
                right: 15,
                top: 15,
                child: IconButton(
                  icon: Icon(
                    Icons.star_rate_rounded,
                    size: 50,
                    color: widget.isFavorite
                        ? Colors.red
                        : const Color.fromARGB(255, 212, 212, 212),
                    shadows: const [
                      BoxShadow(
                        color: Colors.black,
                        blurRadius: 2,
                        offset: Offset(-0.5, 0.5),
                      )
                    ],
                  ),
                  onPressed: widget.onToggleFavorite,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.name,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Colors.blueAccent,
            ),
          ),
          const SizedBox(height: 2.0),
          Text(
            widget.createdDate,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplatePreview() {
    switch (widget.template) {
      case 'grid':
        return CustomPaint(
          painter: GridPainter(),
          size: const Size(170, 170),
        );
      case 'lined':
        return CustomPaint(
          painter: LinedPaperPainter(),
          size: const Size(170, 170),
        );
      case 'todo':
        return CustomPaint(
          painter: TodoTemplatePainter(),
          size: const Size(170, 170),
        );
      default:
        return Container(color: Colors.white);
    }
  }
}

// Custom painter for scaled note preview
class NotePainter extends CustomPainter {
  // final List<DrawingPoint> points;
  final ui.Image? backgroundImage;
  final double scale;

  NotePainter({
    // required this.points,
    this.backgroundImage,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Scale the canvas for preview
    canvas.scale(scale);

    // Draw background if exists
    if (backgroundImage != null) {
      canvas.drawImage(
        backgroundImage!,
        Offset.zero,
        Paint(),
      );
    }

    // Draw points
    // for (var point in points) {
    //   final paint = Paint()
    //     ..color = point.color
    //     ..strokeWidth = point.width
    //     ..strokeCap = StrokeCap.round;

    //   for (var i = 0; i < point.offsets.length - 1; i++) {
    //     canvas.drawLine(
    //       point.offsets[i],
    //       point.offsets[i + 1],
    //       paint,
    //     );
    //   }
    // }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Template painters
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 0.5;

    // Draw grid lines
    for (double i = 0; i <= size.width; i += 20) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i <= size.height; i += 20) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LinedPaperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..strokeWidth = 0.5;

    // Draw horizontal lines
    for (double i = 20; i <= size.height; i += 20) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TodoTemplatePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.5)
      ..strokeWidth = 0.5;

    // Draw checkbox outlines
    for (int i = 0; i < 5; i++) {
      final top = 30.0 + (i * 30);
      canvas.drawRect(
        Rect.fromLTWH(20, top, 15, 15),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
