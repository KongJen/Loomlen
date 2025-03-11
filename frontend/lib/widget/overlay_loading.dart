import 'package:flutter/material.dart';

class LoadingOverlay {
  BuildContext _context;
  bool _isShowing = false;
  BuildContext? _dialogContext;
  String _message;
  String? _subMessage;

  LoadingOverlay({
    required BuildContext context,
    String message = 'Loading...',
    String? subMessage,
  }) : _context = context,
       _message = message,
       _subMessage = subMessage;

  void show() {
    if (_isShowing) return;

    _isShowing = true;

    showDialog(
      context: _context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        _dialogContext = context;
        return WillPopScope(
          onWillPop:
              () async => false, // Prevent back button from closing dialog
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Center(
              child: Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text(
                      _message,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_subMessage != null) ...[
                      SizedBox(height: 10),
                      Text(
                        _subMessage!,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void updateMessage(String message, {String? subMessage}) {
    _message = message;
    if (subMessage != null) {
      _subMessage = subMessage;
    }

    // If not showing, no need to update UI
    if (!_isShowing) return;

    // Force rebuild by hiding and showing again
    hide();
    show();
  }

  void hide() {
    if (!_isShowing) return;

    if (_dialogContext != null && Navigator.of(_dialogContext!).canPop()) {
      Navigator.of(_dialogContext!).pop();
      _dialogContext = null;
    }

    _isShowing = false;
  }

  bool get isShowing => _isShowing;
}
