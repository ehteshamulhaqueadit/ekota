import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get apiBaseUrl {
    return dotenv.env['API_BASE_URL'] ??
        const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'http://192.168.0.237:3000/api',
        );
  }
}
