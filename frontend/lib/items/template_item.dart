// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

enum TemplateType { plain, lined, grid, dotted }

class PaperTemplate {
  final String id;
  final String name;
  final Color backgroundColor;
  final Color lineColor;
  final double lineWidth;
  final double spacing;

  const PaperTemplate({
    required this.id,
    required this.name,
    this.backgroundColor = Colors.white,
    this.lineColor = const Color(0xFFCCCCCC),
    this.lineWidth = 1.0,
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
    switch (id) {
      case 'plain':
        // Plain paper has just the background
        break;
      case 'lined':
        _drawLinedPaper(canvas, size, linePaint);
        break;
      case 'grid':
        _drawGridPaper(canvas, size, linePaint);
        break;
      case 'dotted':
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

// Factory for creating templates
class PaperTemplateFactory {
  static final Map<String, PaperTemplate> _templates = {
    'plain': const PaperTemplate(id: 'plain', name: 'Plain'),
    'lined': const PaperTemplate(id: 'lined', name: 'Lined'),
    'grid': const PaperTemplate(id: 'grid', name: 'Grid'),
    'dotted': const PaperTemplate(id: 'dotted', name: 'Dotted'),
  };

  static PaperTemplate getTemplate(String templateId) {
    return _templates[templateId] ?? _templates['plain']!;
  }

  static List<PaperTemplate> getAllTemplates() {
    return _templates.values.toList();
  }
}

// Custom painters
class TemplatePainter extends CustomPainter {
  final PaperTemplate template;

  TemplatePainter({required this.template});

  @override
  void paint(Canvas canvas, Size size) {
    template.paintTemplate(canvas, size);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TemplateThumbnailPainter extends CustomPainter {
  final PaperTemplate template;
  final double scaleFactor; // Scaling factor for preview

  TemplateThumbnailPainter({required this.template, required this.scaleFactor});

  @override
  void paint(Canvas canvas, Size size) {
    // Reduce spacing according to scaleFactor
    final PaperTemplate scaledTemplate = PaperTemplate(
      id: template.id,
      name: template.name,
      backgroundColor: template.backgroundColor,
      lineColor: template.lineColor.withOpacity(0.3),
      lineWidth: template.lineWidth,
      spacing: template.spacing * scaleFactor, // Scale the spacing
    );

    scaledTemplate.paintTemplate(canvas, size);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
