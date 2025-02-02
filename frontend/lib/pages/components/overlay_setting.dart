import 'package:flutter/material.dart';

class OverlaySettings extends StatefulWidget {
  final VoidCallback onClose;

  const OverlaySettings({Key? key, required this.onClose}) : super(key: key);

  @override
  _OverlaySettingsState createState() => _OverlaySettingsState();
}

class _OverlaySettingsState extends State<OverlaySettings> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background overlay
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: Container(color: Colors.black.withOpacity(0.5)),
          ),
        ),
        // Centered overlay box
        Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 300,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header: Centered text + Close button
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(10)),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            'Settings',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          child: IconButton(
                            icon: Icon(Icons.close, color: Colors.black),
                            onPressed: widget.onClose,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(),
                  ListTile(
                    leading: Icon(Icons.person),
                    title: Text('Profile'),
                    onTap: widget.onClose,
                  ),
                  ListTile(
                    leading: Icon(Icons.settings),
                    title: Text('General Settings'),
                    onTap: widget.onClose,
                  ),
                  ListTile(
                    leading: Icon(Icons.logout),
                    title: Text('Logout'),
                    onTap: widget.onClose,
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
