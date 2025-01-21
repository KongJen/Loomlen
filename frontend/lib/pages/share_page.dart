import 'package:flutter/material.dart';

class SharePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(100.0),
        child: AppBar(
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey, width: 1),
              ),
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
                    'Share',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.black, // Add text color
                    ),
                  ),
                  // You can add more widgets here if needed
                ],
              ),
            ),
          ),
        ),
      ),
      body: Center(
        child: Text(
          'Welcome to Share!',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
