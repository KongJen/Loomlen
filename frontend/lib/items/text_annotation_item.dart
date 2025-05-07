// text_element.dart
import 'package:flutter/material.dart';

// Enhanced TextAnnotation class for text_annotation_item.dart

class TextAnnotation {
  final String id;
  final String text;
  final Offset position;
  final Color color;
  final double fontSize;
  final bool isEditing;
  final bool isSelected;
  final bool isBold;
  final bool isItalic;
  final bool isBubble;

  TextAnnotation({
    required this.id,
    required this.text,
    required this.position,
    required this.color,
    this.fontSize = 16.0,
    this.isEditing = false,
    this.isSelected = false,
    this.isBold = false,
    this.isItalic = false,
    this.isBubble = false,
  });

  // Copy with method to create a new instance with updated properties
  TextAnnotation copyWith({
    String? text,
    Offset? position,
    Color? color,
    double? fontSize,
    bool? isEditing,
    bool? isSelected,
    TextAlign? textAlign,
    bool? isBold,
    bool? isItalic,
    bool? isBubble,
  }) {
    return TextAnnotation(
      id: this.id,
      text: text ?? this.text,
      position: position ?? this.position,
      color: color ?? this.color,
      fontSize: fontSize ?? this.fontSize,
      isEditing: isEditing ?? this.isEditing,
      isSelected: isSelected ?? this.isSelected,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      isBubble: isBubble ?? this.isBubble,
    );
  }

  // Create from JSON
  factory TextAnnotation.fromJson(Map<String, dynamic> json) {
    return TextAnnotation(
      id: json['id'] as String,
      text: json['text'] as String,
      position: Offset(
        json['position']['dx'] as double,
        json['position']['dy'] as double,
      ),
      color: Color(json['color'] as int),
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16.0,
      isEditing: false,
      isSelected: false,
      isBold: json['isBold'] as bool? ?? false,
      isItalic: json['isItalic'] as bool? ?? false,
      isBubble: json['isBubble'] as bool? ?? false,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'position': {
        'dx': position.dx,
        'dy': position.dy,
      },
      'color': color.value,
      'fontSize': fontSize,
      'isBold': isBold,
      'isItalic': isItalic,
      'isBubble': isBubble,
    };
  }
}
