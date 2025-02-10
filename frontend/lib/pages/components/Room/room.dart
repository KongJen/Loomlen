import 'package:flutter/material.dart';

class RoomItem extends StatefulWidget {
  final String name;
  final String createdDate;
  final Color color;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  const RoomItem({
    Key? key,
    required this.name,
    required this.createdDate,
    required this.color,
    required this.isFavorite,
    required this.onToggleFavorite,
  }) : super(key: key);

  @override
  State<RoomItem> createState() => _RoomItemState();
}

class _RoomItemState extends State<RoomItem> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            children: [
              Icon(
                Icons.home_filled,
                size: 170,
                color: widget.color,
              ),
              Positioned(
                right: 15,
                top: 15,
                child: IconButton(
                  icon: Icon(Icons.star_rate_rounded,
                      size: 50,
                      color: widget.isFavorite
                          ? Colors.red // Show red if favorite
                          : const Color.fromARGB(255, 212, 212, 212),
                      shadows: [
                        BoxShadow(
                          color: Colors.black,
                          blurRadius: 2,
                          offset: Offset(-0.5, 0.5),
                        )
                      ]),
                  onPressed:
                      widget.onToggleFavorite, // Trigger the toggle callback
                ),
              ),
            ],
          ),
          Text(
            widget.name,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Colors.blueAccent,
            ),
          ),
          SizedBox(height: 2.0),
          Text(
            widget.createdDate,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
