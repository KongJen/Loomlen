import 'package:flutter/material.dart';

class DrawingPoint {
  int id;
  List<Offset> offsets;
  Color color;
  double width;
  final bool isEraser;

  DrawingPoint({
    this.id = -1,
    this.offsets = const [],
    this.color = Colors.black,
    this.width = 2,
    this.isEraser = false,
  });

  // Override the toString method for better logging
  @override
  String toString() {
    return 'DrawingPoint(id: $id, offsets: $offsets, color: $color, width: $width, isEraser: $isEraser)';
  }

  DrawingPoint copyWith({
    List<Offset>? offsets,
    bool? isEraser,
    Color? color,
    double? width,
  }) {
    return DrawingPoint(
      id: id,
      color: color ?? this.color,
      width: width ?? this.width,
      offsets: offsets ?? this.offsets,
      isEraser: isEraser ?? this.isEraser,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'offsets':
          offsets.map((offset) => {'x': offset.dx, 'y': offset.dy}).toList(),
      // ignore: deprecated_member_use
      'color': color.value,
      'width': width,
      'isEraser': isEraser,
    };
  }

  // Create from JSON
  static DrawingPoint fromJson(Map<String, dynamic> json) {
    List<Offset> offsetsList = [];

    // Make sure to properly parse all offsets
    if (json['offsets'] != null) {
      final offsetsData = json['offsets'] as List;
      offsetsList =
          offsetsData
              .map<Offset>(
                (point) => Offset(point['x'].toDouble(), point['y'].toDouble()),
              )
              .toList();
    }

    return DrawingPoint(
      id: json['id'] ?? -1, // Provide a default ID if null
      offsets: offsetsList,
      color:
          json['color'] != null
              ? Color(json['color'])
              : Colors.black, // Default to black if null
      width: json['width'] ?? 2.0, // Default width if null
      isEraser: json['isEraser'] ?? false, // Default to false
    );
  }
}
