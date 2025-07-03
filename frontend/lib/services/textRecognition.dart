import 'package:flutter/material.dart';

class TextRecognitionResult {
  final String text;
  final Offset position;
  final Color color;
  final double fontSize;

  TextRecognitionResult({
    required this.text,
    required this.position,
    required this.color,
    required this.fontSize,
  });

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'positionX': position.dx,
      'positionY': position.dy,
      'colorValue': color.value,
      'fontSize': fontSize,
    };
  }

  factory TextRecognitionResult.fromJson(Map<String, dynamic> json) {
    return TextRecognitionResult(
      text: json['text'],
      position: Offset(json['positionX'], json['positionY']),
      color: Color(json['colorValue']),
      fontSize: json['fontSize'],
    );
  }
}
