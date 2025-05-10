import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';

class UIComponents {
  static Widget createAddButton({
    required double itemSize,
    String label = "New",
    bool isListView = false,
  }) {
    if (isListView) {
      // 📋 Custom list-style layout with large icon
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Row(
          children: [
            DottedBorder(
              borderType: BorderType.RRect,
              radius: const Radius.circular(8.0),
              dashPattern: const [4, 3],
              color: Colors.blue,
              strokeWidth: 2,
              child: Container(
                width: 70,
                height: 70,
                alignment: Alignment.center,
                child: const Icon(Icons.add, size: 30, color: Colors.blue),
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.blue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 🟦 Grid-style Add button (default)
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: itemSize,
          child: Center(
            child: DottedBorder(
              borderType: BorderType.RRect,
              radius: const Radius.circular(8.0),
              dashPattern: const [8, 4],
              color: Colors.blue,
              strokeWidth: 2,
              child: Container(
                width: itemSize * 0.65,
                height: itemSize * 0.65,
                alignment: Alignment.center,
                child: Icon(
                  Icons.add,
                  size: itemSize * 0.2,
                  color: Colors.blue,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
