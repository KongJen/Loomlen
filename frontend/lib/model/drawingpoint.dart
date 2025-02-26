import 'package:flutter/material.dart';

class DrawingPoint {
  int id;
  List<Offset> offsets;
  Color color;
  double width;

  DrawingPoint({
    this.id = -1,
    this.offsets = const [],
    this.color = Colors.black,
    this.width = 2,
  });

  DrawingPoint copyWith({List<Offset>? offsets}) {
    return DrawingPoint(
      id: id,
      color: color,
      width: width,
      offsets: offsets ?? this.offsets,
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
      id: json['id'],
      offsets: offsetsList,
      color: Color(json['color']),
      width: json['width'],
    );
  }
}
