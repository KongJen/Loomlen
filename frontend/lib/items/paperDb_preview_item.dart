// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:frontend/items/drawingpoint_item.dart';
import 'dart:io';
import 'package:frontend/items/template_item.dart';
import 'package:frontend/providers/paperdb_provider.dart';
import 'package:frontend/widget/drawing_point_preview.dart';
import 'package:provider/provider.dart';

class PaperDBPreviewItem extends StatelessWidget {
  final String fileId;
  final double maxWidth;
  final double maxHeight;

  const PaperDBPreviewItem({
    super.key,
    required this.fileId,
    this.maxWidth = 120,
    this.maxHeight = 150,
  });

  @override
  Widget build(BuildContext context) {
    final paperProvider = Provider.of<PaperDBProvider>(context);
    final paper = paperProvider.papers.firstWhere(
      (p) => p['file_id'] == fileId && p['page_number'] == 1,
      orElse: () => {},
    );
    if (paper.isEmpty) {
      return const Center(
        child: Icon(Icons.insert_drive_file, size: 48, color: Colors.grey),
      );
    }

    double originalWidth = (paper['width'] as num?)?.toDouble() ?? 595.0;
    double originalHeight = (paper['height'] as num?)?.toDouble() ?? 842.0;

    // Maintain aspect ratio
    double scaleFactor = maxHeight / originalHeight;
    double previewHeight = maxHeight;
    double previewWidth = originalWidth * scaleFactor;

    if (previewWidth > maxWidth) {
      scaleFactor = maxWidth / originalWidth;
      previewWidth = maxWidth;
      previewHeight = originalHeight * scaleFactor;
    }

    // Get template
    final template = PaperTemplateFactory.getTemplate(paper['template_id']);

    // Load drawing points
    final List<DrawingPoint> drawingPoints =
        paperProvider.getDrawingPointsForPage(paper['id']);

    return Center(
      child: Container(
        width: previewWidth,
        height: previewHeight,
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
        child: Stack(
          children: [
            // Draw template
            CustomPaint(
              painter: TemplateThumbnailPainter(
                template: template,
                scaleFactor: scaleFactor,
              ),
              size: Size(previewWidth, previewHeight),
            ),

            // PDF preview if exists
            if (paper['pdfPath'] != null)
              Image.file(
                File(paper['pdfPath']!),
                width: previewWidth,
                height: previewHeight,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(Icons.broken_image, color: Colors.red),
                  );
                },
              ),
            // Draw stored drawing
            CustomPaint(
              painter: DrawingThumbnailPainter(
                drawingPoints: drawingPoints,
                scaleFactor: scaleFactor,
              ),
              size: Size(previewWidth, previewHeight),
            ),
          ],
        ),
      ),
    );
  }
}
