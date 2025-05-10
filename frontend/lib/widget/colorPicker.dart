import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class ColorPickerWidget extends StatelessWidget {
  final Color currentColor;
  final ValueChanged<Color> onColorChanged;
  final List<Color> availableColors;
  final bool showCustomColorButton;
  final double colorCircleSize;
  final EdgeInsets colorCircleMargin;
  final String? labelText;
  final bool horizontalScrollable;

  const ColorPickerWidget({
    super.key,
    required this.currentColor,
    required this.onColorChanged,
    this.availableColors = const [
      Colors.black,
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.yellow,
    ],
    this.showCustomColorButton = true,
    this.colorCircleSize = 30,
    this.colorCircleMargin = const EdgeInsets.symmetric(horizontal: 4.0),
    this.labelText,
    this.horizontalScrollable = true,
  });

  void openColorPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        Color pickerColor = currentColor;

        return AlertDialog(
          title: const Text('Pick a color'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ColorPicker(
                  pickerColor: pickerColor,
                  onColorChanged: (Color color) {
                    pickerColor = color;
                  },
                  pickerAreaHeightPercent: 0.8,
                  enableAlpha: false,
                  displayThumbColor: true,
                  paletteType: PaletteType.hsv,
                  pickerAreaBorderRadius:
                      const BorderRadius.all(Radius.circular(10)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                onColorChanged(pickerColor);
                Navigator.of(context).pop();
              },
              child: const Text('Select'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildColorCircle(Color color) {
    return GestureDetector(
      onTap: () => onColorChanged(color),
      child: Container(
        margin: colorCircleMargin,
        width: colorCircleSize,
        height: colorCircleSize,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: currentColor.value == color.value
                ? Colors.white
                : Colors.transparent,
            width: 2.0,
          ),
          boxShadow: [
            if (currentColor.value == color.value)
              const BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                spreadRadius: 1,
              ),
          ],
        ),
      ),
    );
  }

  // Custom rainbow color wheel with add icon
  Widget _buildRainbowCircleAddButton(BuildContext context) {
    return GestureDetector(
      onTap: () => openColorPicker(context),
      child: Container(
        margin: colorCircleMargin,
        width: colorCircleSize,
        height: colorCircleSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const SweepGradient(
            colors: [
              Colors.red,
              Colors.orange,
              Colors.yellow,
              Colors.green,
              Colors.blue,
              Colors.indigo,
              Colors.purple,
              Colors.red,
            ],
            stops: [0.0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 1.0],
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: colorCircleSize * 0.5,
            height: colorCircleSize * 0.5,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add,
              size: 16,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Create a copy of color circles list
    final List<Widget> colorCircles =
        availableColors.map(_buildColorCircle).toList();

    // Add the custom rainbow circle with add button if enabled
    if (showCustomColorButton) {
      colorCircles.add(_buildRainbowCircleAddButton(context));
    }

    Widget colorSelection;
    if (horizontalScrollable) {
      colorSelection = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: colorCircles,
        ),
      );
    } else {
      colorSelection = Wrap(
        spacing: 4.0,
        runSpacing: 8.0,
        children: colorCircles,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Color label if provided
        if (labelText != null)
          Row(
            children: [
              Text(labelText!, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(child: colorSelection),
            ],
          )
        else
          colorSelection,
      ],
    );
  }
}
