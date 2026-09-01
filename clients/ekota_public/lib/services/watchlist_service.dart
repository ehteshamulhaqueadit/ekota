import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class WatchlistService {
  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<List<Map<String, dynamic>>> getMyWatchlist() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/watchlist/my'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    throw Exception('Failed to load watchlist');
  }

  static Future<void> addToWatchlist(String listingId) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/watchlist'),
      headers: await _getHeaders(),
      body: jsonEncode({'listingId': listingId}),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to add to watchlist');
    }
  }

  static Future<void> removeFromWatchlist(String listingId) async {
    final response = await http.delete(
      Uri.parse('${AppConfig.apiBaseUrl}/watchlist/$listingId'),
      headers: await _getHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to remove from watchlist');
    }
  }

  static Future<void> updateAlerts(String listingId, {
    bool? alertOnAvailable,
    bool? alertOnPriceChange,
    bool? alertOnFunded,
  }) async {
    final body = <String, dynamic>{};
    if (alertOnAvailable != null) body['alertOnAvailable'] = alertOnAvailable;
    if (alertOnPriceChange != null) body['alertOnPriceChange'] = alertOnPriceChange;
    if (alertOnFunded != null) body['alertOnFunded'] = alertOnFunded;

    final response = await http.put(
      Uri.parse('${AppConfig.apiBaseUrl}/watchlist/$listingId'),
      headers: await _getHeaders(),
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update watchlist alerts');
    }
  }
}
