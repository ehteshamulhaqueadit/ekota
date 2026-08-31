import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class PublicApiClient {
  static const Duration _timeout = Duration(seconds: 30);

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<http.Response> get(String path) async {
    final headers = await _headers();
    return http
        .get(
          Uri.parse('${AppConfig.apiBaseUrl}/$path'),
          headers: headers,
        )
        .timeout(_timeout);
  }

  static Future<http.Response> post(String path, {Map<String, dynamic>? body}) async {
    final headers = await _headers();
    return http
        .post(
          Uri.parse('${AppConfig.apiBaseUrl}/$path'),
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(_timeout);
  }

  static Future<http.Response> put(String path, {Map<String, dynamic>? body}) async {
    final headers = await _headers();
    return http
        .put(
          Uri.parse('${AppConfig.apiBaseUrl}/$path'),
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(_timeout);
  }
}
