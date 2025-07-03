import 'package:flutter/material.dart';

class OverlaySelect extends StatelessWidget {
  final VoidCallback onCreateFolder;
  final VoidCallback onCreateFile;
  final VoidCallback onImportPDF;
  final VoidCallback onClose;
  final Offset overlayPosition; // Position where clicked

  const OverlaySelect({
    super.key,
    required this.onCreateFolder,
    required this.onCreateFile,
    required this.onImportPDF,
    required this.onClose,
    required this.overlayPosition,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isPhone = screenSize.width < 600;

    return Stack(
      children: [
        // Background (click to close)
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            child: Container(color: Colors.black.withOpacity(0.5)),
          ),
        ),
        // Positioned Overlay Box
        isPhone
            ? Center(
                child: _buildOverlayContent(),
              )
            : Positioned(
                left: overlayPosition.dx,
                top: overlayPosition.dy,
                child: _buildOverlayContent(),
              ),
      ],
    );
  }

  Widget _buildOverlayContent() {
    return Material(
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

            Divider(height: 1, thickness: 1, color: Colors.grey[300]),

            InkWell(
              onTap: onImportPDF,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Center(
                  child: Text(
                    'Import File',
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
    );
  }
}
