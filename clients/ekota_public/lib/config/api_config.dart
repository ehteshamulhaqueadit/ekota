import 'app_config.dart';

class ApiConfig {
  static String get baseUrl => AppConfig.apiBaseUrl;
  static String get paymentApiUrl => '$baseUrl/payments';
  static String get withdrawalApiUrl => '$baseUrl/withdrawals';
  static String get notificationApiUrl => '$baseUrl/notifications';
}
