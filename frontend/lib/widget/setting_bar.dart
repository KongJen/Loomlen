import 'package:flutter/material.dart';
import 'package:frontend/paper.dart'; // Import for EraserMode enum

// Builds the pencil settings bar widget
Widget buildPencilSettingsBar({
  required double selectedWidth,
  required Color selectedColor,
  required List<Color> availableColors,
  required ValueChanged<double> onWidthChanged,
  required ValueChanged<Color> onColorChanged,
}) {
  return Container(
    padding: const EdgeInsets.all(8.0),
    color: Colors.grey.shade200,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Size: ', style: TextStyle(fontSize: 16)),
            Expanded(
              child: Slider(
                value: selectedWidth,
                min: 1.0,
                max: 20.0,
                divisions: 19,
                label: selectedWidth.round().toString(),
                onChanged: onWidthChanged,
              ),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children:
              availableColors
                  .map(
                    (color) => GestureDetector(
                      onTap: () => onColorChanged(color),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4.0),
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                selectedColor == color
                                    ? Colors.white
                                    : Colors.transparent,
                            width: 2.0,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
        ),
      ],
    ),
  );
}

// Builds the eraser settings bar widget
Widget buildEraserSettingsBar({
  required double eraserWidth,
  required EraserMode eraserMode,
  required ValueChanged<double> onWidthChanged,
  required ValueChanged<EraserMode> onModeChanged,
}) {
  return Container(
    padding: const EdgeInsets.all(8.0),
    color: Colors.grey.shade200,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Eraser Size: ', style: TextStyle(fontSize: 16)),
            Expanded(
              child: Slider(
                value: eraserWidth,
                min: 5.0,
                max: 50.0,
                divisions: 45,
                label: eraserWidth.round().toString(),
                onChanged: onWidthChanged,
              ),
            ),
          ],
        ),
        Row(
          children: [
            const Text('Mode: ', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            ToggleButtons(
              borderRadius: BorderRadius.circular(8),
              selectedColor: Colors.white,
              fillColor: Colors.blue,
              constraints: const BoxConstraints(minHeight: 36, minWidth: 80),
              isSelected: [
                eraserMode == EraserMode.stroke,
                eraserMode == EraserMode.point,
              ],
              children: const [Text('Stroke'), Text('Point')],
              onPressed:
                  (index) => onModeChanged(
                    index == 0 ? EraserMode.stroke : EraserMode.point,
                  ),
            ),
          ],
        ),
      ],
    ),
  );
}
