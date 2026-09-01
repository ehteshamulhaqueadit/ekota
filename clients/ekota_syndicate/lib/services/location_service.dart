import 'dart:convert';
import 'api_client.dart';

class LocationService {
  /// Get product location
  static Future<Map<String, dynamic>?> getProductLocation(String listingId) async {
    final response = await ApiClient.get('location/$listingId');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  /// Update product location (renter only)
  static Future<Map<String, dynamic>> updateLocation({
    required String listingId,
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    final response = await ApiClient.put('location/$listingId', body: {
      'latitude': latitude,
      'longitude': longitude,
      if (address != null) 'address': address,
    });
    return jsonDecode(response.body);
  }

  /// Subscribe to live location
  static Future<Map<String, dynamic>> subscribe(String listingId) async {
    final response = await ApiClient.post('location/subscribe/$listingId');
    return jsonDecode(response.body);
  }

  /// Unsubscribe from live location
  static Future<bool> unsubscribe(String listingId) async {
    final response = await ApiClient.delete('location/subscribe/$listingId');
    return response.statusCode == 200;
  }

  /// Get my subscriptions
  static Future<List<Map<String, dynamic>>> getMySubscriptions() async {
    final response = await ApiClient.get('location/subscriptions/my');
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    return [];
  }
}
