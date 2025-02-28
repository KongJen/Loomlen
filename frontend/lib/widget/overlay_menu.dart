import 'package:flutter/material.dart';

class OverlaySelect extends StatelessWidget {
  final VoidCallback onCreateFolder;
  final VoidCallback onCreateFile;
  final VoidCallback onClose;
  final Offset overlayPosition; // Position where clicked

  const OverlaySelect({
    super.key,
    required this.onCreateFolder,
    required this.onCreateFile,
    required this.onClose,
    required this.overlayPosition,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background (click to close)
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            // ignore: deprecated_member_use
            child: Container(color: Colors.black.withOpacity(0.5)),
          ),
        ),
        // Positioned Overlay Box
        Positioned(
          left: overlayPosition.dx,
          top: overlayPosition.dy,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Create Folder Button
                  InkWell(
                    onTap: onCreateFolder,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(
                        child: Text(
                          'Create Folder',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Divider Line
                  Divider(height: 1, thickness: 1, color: Colors.grey[300]),
                  // Create File Button
                  InkWell(
                    onTap: onCreateFile,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(
                        child: Text(
                          'Create File',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
