import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// ignore: camel_case_types
class Config_URL {
  static const String _compileTimeUrl = String.fromEnvironment('BASE_URL', defaultValue: '');

  static String get baseUrl {
    // 1. Ưu tiên biến môi trường lúc build (--dart-define=BASE_URL=...)
    if (_compileTimeUrl.isNotEmpty) {
      return _compileTimeUrl.endsWith('/') ? _compileTimeUrl : '$_compileTimeUrl/';
    }

    final envUrl = dotenv.env['BASE_URL'];

    // 2. Nếu chạy trên Web hoặc Windows
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
      if (envUrl != null && envUrl.isNotEmpty && !envUrl.contains('10.0.2.2')) {
        return envUrl.endsWith('/') ? envUrl : '$envUrl/';
      }
      return "http://localhost:5000/api/";
    }

    // 3. Nếu chạy trên Android Emulator hoặc thiết bị di động
    if (envUrl != null && envUrl.isNotEmpty) {
      return envUrl.endsWith('/') ? envUrl : '$envUrl/';
    }
    return "http://10.0.2.2:5000/api/";
  }
}
