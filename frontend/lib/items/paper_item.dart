import 'package:flutter/material.dart';
import 'package:frontend/items/template_item.dart';

class PaperItem extends StatefulWidget {
  final String fileId;
  final String id;
  final String? pdfPath;
  final String? recognizedText;
  final String templateId;
  final int pageNumber; // fixed camelCase naming
  final double? width; // fixed typo
  final double? height;

  const PaperItem({
    super.key,
    required this.fileId,
    required this.id,
    this.pdfPath,
    this.recognizedText,
    this.templateId = 'plain',
    required this.pageNumber,
    this.width,
    this.height,
  });

  @override
  State<PaperItem> createState() => _PaperItemState();
}

class _PaperItemState extends State<PaperItem> {
  @override
  Widget build(BuildContext context) {
    // Implementation for paper item display
    return Container(
      width: widget.width ?? 200,
      height: widget.height ?? 280,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: CustomPaint(
          painter: TemplatePainter(
            template: PaperTemplateFactory.getTemplate(widget.templateId),
          ),
          size: Size(widget.width ?? 200, widget.height ?? 280),
        ),
      ),
    );
  }
}
