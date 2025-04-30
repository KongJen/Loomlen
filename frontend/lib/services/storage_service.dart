import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class StorageService {
  Future<File> _getFile(String filename) async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$filename.json');
  }

  Future<List<Map<String, dynamic>>> loadData(String filename) async {
    final file = await _getFile(filename);
    if (await file.exists()) {
      final content = await file.readAsString();
      return (content.isNotEmpty)
          ? List<Map<String, dynamic>>.from(jsonDecode(content))
          : [];
    }
    return [];
  }

  Future<void> saveData(
    String filename,
    List<Map<String, dynamic>> data,
  ) async {
    final file = await _getFile(filename);
    await file.writeAsString(jsonEncode(data));
  }
}
