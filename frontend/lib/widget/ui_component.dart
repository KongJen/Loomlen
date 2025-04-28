import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';

class UIComponents {
  static Widget createAddButton({
    required double itemSize,
    String label = "New",
  }) {
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

  static PreferredSize createTitleAppBar({
    required BuildContext context,
    required String title,
    List<Widget>? actions,
    Widget? leading,
    double height = 100.0,
  }) {
    return PreferredSize(
      preferredSize: Size.fromHeight(height),
      child: AppBar(
        elevation: 0,
        leading: leading,
        actions: actions,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey, width: 1)),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 35,
              left: 60,
              right: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
