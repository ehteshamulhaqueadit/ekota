import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  // Your laptop's Wi-Fi IP for direct connection from physical phone
  static String hostIp = '192.168.1.195'; 
  static int port = 5000;

  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:$port/api';
    } else if (Platform.isAndroid) {
      return 'http://$hostIp:$port/api';
    }
    return 'http://localhost:$port/api';
  }

  static String get paymentApiUrl => '$baseUrl/payments';
  static String get withdrawalApiUrl => '$baseUrl/withdrawals';
  static String get notificationApiUrl => '$baseUrl/notifications';
}
