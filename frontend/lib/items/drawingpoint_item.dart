import 'package:flutter/material.dart';

class DrawingPoint {
  int id;
  List<Offset> offsets;
  Color color;
  double width;
  String tool;
  String? userId; // Added userId field

  DrawingPoint({
    this.id = -1,
    this.offsets = const [],
    this.color = Colors.black,
    this.width = 2,
    this.tool = 'pencil',
    this.userId, // Added to constructor
  });

  // Override the toString method for better logging
  @override
  String toString() {
    return 'DrawingPoint(id: $id, offsets: $offsets, color: $color, width: $width, tool: $tool, userId: $userId)';
  }

  DrawingPoint copyWith({
    List<Offset>? offsets,
    bool? isEraser,
    String? tool,
    Color? color,
    double? width,
    String? userId,
  }) {
    return DrawingPoint(
      id: id,
      color: color ?? this.color,
      tool: tool ?? this.tool,
      width: width ?? this.width,
      offsets: offsets ?? this.offsets,
      userId: userId ?? this.userId,
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
      'tool': tool,
      'userId': userId,
    };
  }

  // Create from JSON
  static DrawingPoint fromJson(Map<String, dynamic> json) {
    List<Offset> offsetsList = [];

    // Make sure to properly parse all offsets
    if (json['offsets'] != null) {
      final offsetsData = json['offsets'] as List;
      offsetsList = offsetsData
          .map<Offset>(
            (point) => Offset(point['x'].toDouble(), point['y'].toDouble()),
          )
          .toList();
    }

    return DrawingPoint(
      id: json['id'] ?? -1, // Provide a default ID if null
      offsets: offsetsList,
      color: json['color'] != null
          ? Color(json['color'])
          : Colors.black, // Default to black if null
      width: json['width'] != null
          ? (json['width'] as num).toDouble() // 👈 FIX: cast to double
          : 2.0, // Default width if null
      tool: json['tool'] ?? 'pencil',
      userId: json['userId'], // Parse userId from JSON
    );
  }
}
