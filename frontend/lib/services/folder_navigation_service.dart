import 'package:flutter/material.dart';

class FolderNavigationService extends ChangeNotifier {
  final List<Map<String, dynamic>> _navigationStack = [];
  Map<String, dynamic>? _currentFolder;
  final Map<String, dynamic> _rootRoom;

  FolderNavigationService(this._rootRoom);

  Map<String, dynamic> get currentRoom => _rootRoom;
  Map<String, dynamic>? get currentFolder => _currentFolder;
  List<Map<String, dynamic>> get navigationStack => List.from(_navigationStack);
  bool get isInFolder => _currentFolder != null;

  String get currentParentId => _currentFolder?['id'] ?? _rootRoom['id'];

  Color get currentColor {
    if (_currentFolder != null && _currentFolder!['color'] != null) {
      return (_currentFolder!['color'] is int)
          ? Color(_currentFolder!['color'])
          : _currentFolder!['color'];
    } else {
      return (_rootRoom['color'] is int)
          ? Color(_rootRoom['color'])
          : _rootRoom['color'];
    }
  }

  void navigateToFolder(Map<String, dynamic> folder) {
    if (_currentFolder != null) {
      _navigationStack.add(_currentFolder!);
    }
    _currentFolder = folder;
    notifyListeners();
  }

  bool navigateBack() {
    if (_navigationStack.isNotEmpty) {
      _currentFolder = _navigationStack.removeLast();
      notifyListeners();
      return true;
    } else if (_currentFolder != null) {
      _currentFolder = null;
      notifyListeners();
      return true;
    }
    return false;
  }

  List<Map<String, dynamic>> getBreadcrumbPath() {
    List<Map<String, dynamic>> fullPath = [_rootRoom];
    if (_navigationStack.isNotEmpty) {
      fullPath.addAll(_navigationStack);
    }
    if (_currentFolder != null) {
      fullPath.add(_currentFolder!);
    }
    return fullPath;
  }
}
