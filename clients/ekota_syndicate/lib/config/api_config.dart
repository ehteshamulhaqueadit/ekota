import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  // Change this host IP to your laptop's local Wi-Fi IP (e.g. 192.168.1.50) when running APK on a physical phone!
  static String hostIp = '10.0.2.2'; // Default Android emulator host IP
  static int port = 5000;

  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:$port/api';
    } else if (Platform.isAndroid) {
      return 'http://$hostIp:$port/api';
    }
    return 'http://localhost:$port/api';
  }

  static String get withdrawalApiUrl => '$baseUrl/withdrawals';
  static String get notificationApiUrl => '$baseUrl/notifications';
}
