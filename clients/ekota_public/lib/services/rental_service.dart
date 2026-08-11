import 'dart:convert';
import 'api_client.dart';

class PublicRentalService {
  /// Get all products available to rent
  static Future<List<Map<String, dynamic>>> getRentalPool() async {
    final response = await PublicApiClient.get('rental-pool');
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    return [];
  }

  /// Rent a product from the pool
  static Future<Map<String, dynamic>> rentProduct(String poolItemId) async {
    final response = await PublicApiClient.post('rental-pool/$poolItemId/rent');
    return jsonDecode(response.body);
  }

  /// Return a rented product
  static Future<Map<String, dynamic>> returnProduct(String poolItemId) async {
    final response = await PublicApiClient.post('rental-pool/$poolItemId/return');
    return jsonDecode(response.body);
  }

  /// Get my active and past rentals
  static Future<List<Map<String, dynamic>>> getMyRentals() async {
    final response = await PublicApiClient.get('rentals/my');
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    return [];
  }

  /// Update the product's live location (renter submits their GPS)
  static Future<Map<String, dynamic>> updateLocation({
    required String listingId,
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    final response = await PublicApiClient.put('location/$listingId', body: {
      'latitude': latitude,
      'longitude': longitude,
      if (address != null) 'address': address,
    });
    return jsonDecode(response.body);
  }
}
