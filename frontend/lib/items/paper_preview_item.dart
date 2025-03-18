import 'dart:io';
import 'package:flutter/material.dart';
import 'package:frontend/items/template_item.dart';
import 'package:frontend/providers/paper_provider.dart';
import 'package:provider/provider.dart';

class PaperPreviewItem extends StatelessWidget {
  final String fileId;
  final double maxWidth; // Max preview width
  final double maxHeight; // Max preview height

  const PaperPreviewItem({
    super.key,
    required this.fileId,
    this.maxWidth = 120, // Adjusted max preview size
    this.maxHeight = 150, // Adjusted max preview size
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

    final firstPaper = papers.first;

    double originalWidth = firstPaper['width'] as double? ?? 595.0;
    double originalHeight = firstPaper['height'] as double? ?? 842.0;

    // Maintain the fixed maxHeight and scale width to maintain the aspect ratio
    double scaleFactor = maxHeight / originalHeight;
    double previewHeight = maxHeight;
    double previewWidth = originalWidth * scaleFactor;

    // If the width exceeds maxWidth, adjust it
    if (previewWidth > maxWidth) {
      scaleFactor = maxWidth / originalWidth;
      previewWidth = maxWidth;
      previewHeight = originalHeight * scaleFactor;
    }

    final template = PaperTemplateFactory.getTemplate(
      firstPaper['templateId'],
      TemplateType.values.firstWhere(
        (e) => e.toString() == firstPaper['templateType'],
        orElse: () => TemplateType.plain,
      ),
    );

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
            // Template background
            CustomPaint(
              painter: TemplatePainter(template: template),
              size: Size(previewWidth, previewHeight),
            ),
            // PDF background if available
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
          ],
        ),
      ),
    );
  }
}
