import 'dart:convert';
import 'api_client.dart';

class RentalService {
  /// List a product in the rental pool
  static Future<Map<String, dynamic>> listInRentalPool(String listingId) async {
    final response = await ApiClient.post('rental-pool', body: {
      'listingId': listingId,
    });
    return jsonDecode(response.body);
  }

  /// Get all available rental pool items
  static Future<List<Map<String, dynamic>>> getRentalPool() async {
    final response = await ApiClient.get('rental-pool');
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    return [];
  }

  /// Rent a product
  static Future<Map<String, dynamic>> rentProduct(String poolItemId) async {
    final response = await ApiClient.post('rental-pool/$poolItemId/rent');
    return jsonDecode(response.body);
  }

  /// Return a rented product
  static Future<Map<String, dynamic>> returnProduct(String poolItemId) async {
    final response = await ApiClient.post('rental-pool/$poolItemId/return');
    return jsonDecode(response.body);
  }

  /// Get my rentals
  static Future<List<Map<String, dynamic>>> getMyRentals() async {
    final response = await ApiClient.get('rentals/my');
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    return [];
  }
}
