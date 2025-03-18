import 'package:flutter/foundation.dart';

abstract class BaseProvider<T> with ChangeNotifier {
  final List<T> _items = [];

  List<T> get items => _items;

  void addItem(T item) {
    _items.add(item);
    notifyListeners();
  }

  void removeItem(T item) {
    _items.remove(item);
    notifyListeners();
  }
}
