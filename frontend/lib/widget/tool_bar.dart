import 'package:flutter/material.dart';
import 'package:frontend/model/tools.dart';

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
          children: availableColors
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
                        color: selectedColor == color
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
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.grey.shade200,
      border: Border(bottom: BorderSide(color: Colors.grey.shade400)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Text('Eraser Width: ', style: TextStyle(fontSize: 14)),
            Expanded(
              child: Slider(
                value: eraserWidth,
                min: 5,
                max: 40,
                divisions: 7,
                label: eraserWidth.toInt().toString(),
                onChanged: onWidthChanged,
              ),
            ),
            // Text('${eraserWidth.toInt()}px', style: TextStyle(fontSize: 14)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Eraser Mode: ', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 12),
            ToggleButtons(
              isSelected: [
                eraserMode == EraserMode.point,
                eraserMode == EraserMode.stroke,
              ],
              onPressed: (index) {
                onModeChanged(
                  index == 0 ? EraserMode.point : EraserMode.stroke,
                );
              },
              borderRadius: BorderRadius.circular(4),
              selectedColor: Colors.white,
              fillColor: Colors.blue,
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('Point'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('Stroke'),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}
