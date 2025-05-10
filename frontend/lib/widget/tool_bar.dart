import 'package:flutter/material.dart';
import 'package:frontend/model/tools.dart';
import 'package:frontend/widget/colorPicker.dart';

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
        ColorPickerWidget(
          currentColor: selectedColor,
          onColorChanged: onColorChanged,
          availableColors: availableColors,
          labelText: null,
          horizontalScrollable: true,
          showCustomColorButton: true,
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
// Add this enhanced version to tool_bar.dart

Widget buildTextSettingsBar({
  required Color selectedColor,
  required List<Color> availableColors,
  required ValueChanged<Color> onColorChanged,
  required double fontSize,
  required ValueChanged<double> onFontSizeChanged,
  required TextAlign textAlign,
  required ValueChanged<TextAlign> onTextAlignChanged,
  bool isBold = false,
  bool isItalic = false,
  ValueChanged<bool>? onBoldChanged,
  ValueChanged<bool>? onItalicChanged,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    color: Colors.grey.shade200,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Font size row
        Row(
          children: [
            const Text('Size: ', style: TextStyle(fontSize: 16)),
            Expanded(
              child: Slider(
                value: fontSize,
                min: 10.0,
                max: 36.0,
                divisions: 13,
                label: fontSize.round().toString(),
                onChanged: onFontSizeChanged,
              ),
            ),
            Text('${fontSize.round()}', style: TextStyle(fontSize: 14)),
          ],
        ),

        // Text alignment and style controls
        Row(
          children: [
            if (onBoldChanged != null)
              IconButton(
                icon: Icon(Icons.format_bold),
                isSelected: isBold,
                selectedIcon: Icon(Icons.format_bold, color: Colors.blue),
                onPressed: () => onBoldChanged(!isBold),
                tooltip: 'Bold',
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
              ),
            if (onItalicChanged != null)
              IconButton(
                icon: Icon(Icons.format_italic),
                isSelected: isItalic,
                selectedIcon: Icon(Icons.format_italic, color: Colors.blue),
                onPressed: () => onItalicChanged(!isItalic),
                tooltip: 'Italic',
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
              ),
          ],
        ),

        const SizedBox(height: 8),

        // Color selection row
        Row(
          children: [
            const Text('Color: ', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ColorPickerWidget(
                  currentColor: selectedColor,
                  onColorChanged: onColorChanged,
                  availableColors: availableColors,
                  labelText: null,
                  horizontalScrollable: true,
                  showCustomColorButton: true,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
