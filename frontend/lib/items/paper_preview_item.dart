// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:frontend/items/drawingpoint_item.dart';
import 'dart:io';
import 'package:frontend/items/template_item.dart';
import 'package:frontend/widget/drawing_point_preview.dart';
import 'package:frontend/providers/paper_provider.dart';
import 'package:provider/provider.dart';
import 'package:frontend/services/textRecognition.dart';

class PaperPreviewItem extends StatelessWidget {
  final String fileId;
  final double maxWidth;
  final double maxHeight;

  const PaperPreviewItem({
    super.key,
    required this.fileId,
    this.maxWidth = 120,
    this.maxHeight = 150,
  });

  @override
  Widget build(BuildContext context) {
    final paperProvider = Provider.of<PaperProvider>(context);
    final papers =
        paperProvider.papers.where((p) => p['fileId'] == fileId).toList();

    if (papers.isEmpty) {
      return const Center(
        child: Icon(Icons.insert_drive_file, size: 48, color: Colors.grey),
      );
    }

    final firstPaper = papers.firstWhere((p) => p['PageNumber'] == 1);

    double originalWidth = firstPaper['width'] as double? ?? 595.0;
    double originalHeight = firstPaper['height'] as double? ?? 842.0;

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
    final template = PaperTemplateFactory.getTemplate(firstPaper['templateId']);

    // Load drawing points
    final List<DrawingPoint> drawingPoints =
        paperProvider.getDrawingPointsForPage(firstPaper['id']);

    final List<Map<String, dynamic>> recognizedTextsData =
        paperProvider.getRecognizedTextsForPage(firstPaper['id']);

    final List<TextRecognitionResult> recognizedTexts =
        recognizedTextsData.map((textData) {
      return TextRecognitionResult.fromJson(textData);
    }).toList();

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
            if (firstPaper['pdfPath'] != null)
              Image.file(
                File(firstPaper['pdfPath']!),
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
            ...recognizedTexts.map((textResult) {
              return Positioned(
                left: textResult.position.dx * scaleFactor -
                    (textResult.text.length *
                        textResult.fontSize *
                        0.25 *
                        scaleFactor),
                top: textResult.position.dy * scaleFactor -
                    (textResult.fontSize * 0.5 * scaleFactor),
                child: Text(
                  textResult.text,
                  style: TextStyle(
                    color: textResult.color,
                    fontSize: textResult.fontSize * scaleFactor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
