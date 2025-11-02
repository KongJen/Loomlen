import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';

class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;

  late final Logger _logger;
  File? _logFile;

  LogService._internal() {
    _logger = Logger(
      printer: PrettyPrinter(methodCount: 0),
    );
    _init();
  }

  Future<void> _init() async {
    final directory = await getApplicationDocumentsDirectory();
    final logDir = Directory('${directory.path}/logs');
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    _logFile = File('${logDir.path}/app_log.txt');
  }

  Future<void> log(String message) async {
    _logger.i(message);
    if (_logFile != null) {
      await _logFile!.writeAsString(
        '[${DateTime.now()}] $message\n',
        mode: FileMode.append,
      );
    }
  }

  Future<void> error(String message,
      [dynamic error, StackTrace? stackTrace]) async {
    _logger.e(message, error: error, stackTrace: stackTrace);
    if (_logFile != null) {
      await _logFile!.writeAsString(
        '[${DateTime.now()}] ERROR: $message\n$error\n$stackTrace\n',
        mode: FileMode.append,
      );
    }
  }

  Future<void> clearLogs() async {
    if (_logFile != null && await _logFile!.exists()) {
      await _logFile!.writeAsString('');
    }
  }

  Future<String?> getLogFilePath() async => _logFile?.path;
}
