import 'package:flutter/material.dart';

class OverlayService {
  static OverlayEntry? _currentOverlay;

  static void showOverlay(BuildContext context, Widget overlayWidget) {
    hideOverlay();

    OverlayState overlayState = Overlay.of(context);
    _currentOverlay = OverlayEntry(builder: (context) => overlayWidget);
    overlayState.insert(_currentOverlay!);
  }

  static void hideOverlay() {
    if (_currentOverlay != null) {
      _currentOverlay!.remove();
      _currentOverlay = null;
    }
  }
}
