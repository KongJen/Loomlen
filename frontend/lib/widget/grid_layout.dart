import 'package:flutter/material.dart';

class ResponsiveGridLayout extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double aspectRatio;
  final bool shrinkWrap;
  final EdgeInsetsGeometry? padding;

  const ResponsiveGridLayout({
    super.key,
    required this.children,
    this.spacing = 16.0,
    this.aspectRatio = 0.8,
    this.shrinkWrap = false,
    this.padding,
  });

  int _getGridColumns(double width) {
    if (width < 600) return 2;
    if (width < 900) return 3;
    if (width < 1200) return 4;
    if (width < 1500) return 5;
    return 6;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final crossAxisCount = _getGridColumns(screenSize.width);

    return GridView.builder(
      shrinkWrap: shrinkWrap,
      padding: padding ?? EdgeInsets.symmetric(horizontal: 16.0),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: aspectRatio,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }
}
