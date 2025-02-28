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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            children: [
              Icon(Icons.home_filled, size: 170, color: widget.color),
              Positioned(
                right: 15,
                top: 15,
                child: IconButton(
                  icon: Icon(
                    Icons.star_rate_rounded,
                    size: 50,
                    color:
                        widget.isFavorite
                            ? Colors
                                .red // Show red if favorite
                            : const Color.fromARGB(255, 212, 212, 212),
                    shadows: [
                      BoxShadow(
                        color: Colors.black,
                        blurRadius: 2,
                        offset: Offset(-0.5, 0.5),
                      ),
                    ],
                  ),
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
            style: TextStyle(fontSize: 10, color: Colors.grey),
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
    super.key,
    required this.id,
    required this.name,
    required this.createdDate,
    required this.color,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.subfolderIds,
    required this.fileIds,
  });

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
              Icon(Icons.folder_open, size: 170, color: widget.color),
              Positioned(
                right: 15,
                top: 15,
                child: IconButton(
                  icon: Icon(
                    Icons.star_rate_rounded,
                    size: 50,
                    color:
                        widget.isFavorite
                            ? Colors
                                .red // Show red if favorite
                            : const Color.fromARGB(255, 212, 212, 212),
                    shadows: [
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
            style: TextStyle(fontSize: 10, color: Colors.grey),
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
  // final List<DrawingState> history;
  final int currentHistoryIndex;
  final String? recognizedText;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final String templateId; // Changed from template string to templateId
  final TemplateType templateType; // Added template type
  final double spacing; // Added spacing

  const FileItem({
    super.key,
    required this.id,
    required this.name,
    required this.createdDate,
    this.templateId = 'plain',
    this.templateType = TemplateType.plain,
    this.spacing = 30.0,
    // required this.history,
    this.currentHistoryIndex = -1,
    this.recognizedText,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

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

  @override
  Widget build(BuildContext context) {
    final template = PaperTemplate(
      id: widget.templateId,
      name: _getTemplateName(),
      templateType: widget.templateType,
      spacing: widget.spacing,
    );
    return SizedBox(
      // Added a SizedBox to constrain the overall size
      width: 190,
      height: 210,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 8.0,
        ), // Reduced horizontal padding
        child: Column(
          mainAxisSize: MainAxisSize.min, // Changed to min to prevent expansion
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
                        // ignore: deprecated_member_use
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
                        CustomPaint(
                          painter: TemplateThumbnailPainter(template: template),
                          size: const Size(80, 60),
                        ),
                        if (widget.recognizedText != null &&
                            widget.recognizedText!.isNotEmpty)
                          Positioned(
                            bottom: 5,
                            left: 5,
                            right: 5,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                // ignore: deprecated_member_use
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
                Positioned(
                  right: 15,
                  top: 15,
                  child: IconButton(
                    icon: Icon(
                      Icons.star_rate_rounded,
                      size: 50,
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
            const SizedBox(height: 4), // Reduced vertical spacing
            Flexible(
              // Added Flexible to allow text to shrink if needed
              child: Text(
                widget.name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: Colors.blueAccent,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 4.0),
            Flexible(
              // Added Flexible to allow text to shrink if needed
              child: Text(
                widget.createdDate,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTemplateName() {
    switch (widget.templateType) {
      case TemplateType.plain:
        return 'Plain Paper';
      case TemplateType.lined:
        return 'Lined Paper';
      case TemplateType.grid:
        return 'Grid Paper';
      case TemplateType.dotted:
        return 'Dotted Paper';
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
      canvas.drawImage(backgroundImage!, Offset.zero, Paint());
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
    final paint =
        Paint()
          // ignore: deprecated_member_use
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
    final paint =
        Paint()
          // ignore: deprecated_member_use
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
    final paint =
        Paint()
          // ignore: deprecated_member_use
          ..color = Colors.grey.withOpacity(0.5)
          ..strokeWidth = 0.5;

    // Draw checkbox outlines
    for (int i = 0; i < 5; i++) {
      final top = 30.0 + (i * 30);
      canvas.drawRect(Rect.fromLTWH(20, top, 15, 15), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
