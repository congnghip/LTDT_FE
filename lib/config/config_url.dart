import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// ignore: camel_case_types
class Config_URL {
  static String get baseUrl {
    final envUrl = dotenv.env['BASE_URL'];

    // Nếu chạy trên Web hoặc Windows, tự động chuyển 10.0.2.2 về localhost
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
      if (envUrl != null && envUrl.isNotEmpty && !envUrl.contains('10.0.2.2')) {
        return envUrl;
      }
      return "http://localhost:5000/api/";
    }

    // Nếu chạy trên Android Emulator hoặc thiết bị di động
    if (envUrl != null && envUrl.isNotEmpty) {
      return envUrl;
    }
    return "http://10.0.2.2:5000/api/";
  }
}
