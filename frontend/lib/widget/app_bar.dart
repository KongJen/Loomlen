import 'package:flutter/material.dart';
import '../services/overlay_service.dart';
import '../widget/overlay_setting.dart';
import '../widget/overlay_auth.dart';

class ReusableAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showActionButtons;
  final Widget? leading;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final Color titleColor;
  final double? titleFontSize;
  final double? height;

  final bool? isListView;
  final VoidCallback? onToggleView;

  const ReusableAppBar({
    super.key,
    required this.title,
    this.showActionButtons = true,
    this.leading,
    this.actions,
    this.backgroundColor,
    this.titleColor = Colors.black,
    this.titleFontSize,
    this.height,
    this.isListView,
    this.onToggleView,
  });

  @override
  Size get preferredSize {
    return Size.fromHeight(height ?? kToolbarHeight * 1.75);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final calculatedHeight = height ?? (screenSize.height * 0.12);
    final fontSize = titleFontSize ?? (screenSize.width < 600 ? 30 : 40);

    return AppBar(
      toolbarHeight: calculatedHeight,
      elevation: 0,
      backgroundColor: backgroundColor ?? Colors.transparent,
      leading: leading,
      // Exclude actions from here as we'll position them manually
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey, width: 1)),
        ),
        child: Stack(
          children: [
            // Title positioned lower
            Positioned(
              left: screenSize.width * 0.05,
              bottom: calculatedHeight / 200, // Position title in lower part
              child: Text(
                title,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Action buttons positioned higher
            if (showActionButtons)
              Positioned(
                top: MediaQuery.of(context).padding.top -
                    2, // Position buttons higher
                right: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: actions ?? _buildActionButtonsList(context),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActionButtonsList(BuildContext context) {
    return [
      // IconButton(
      //   icon: const Icon(Icons.select_all, color: Colors.black),
      //   onPressed: () {},
      // ),
      // IconButton(
      //   icon: const Icon(Icons.settings, color: Colors.black),
      //   onPressed: () {
      //     OverlayService.showOverlay(
      //       context,
      //       OverlaySettings(onClose: OverlayService.hideOverlay),
      //     );
      //   },
      // ),
      if (isListView != null && onToggleView != null)
        IconButton(
          icon: Icon(
            isListView! ? Icons.grid_view : Icons.list,
            color: Colors.black,
          ),
          onPressed: onToggleView,
        ),
      IconButton(
        icon: const Icon(Icons.person, color: Colors.black),
        onPressed: () {
          OverlayService.showOverlay(
            context,
            OverlayAuth(onClose: OverlayService.hideOverlay),
          );
        },
      ),
    ];
  }
}
