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

  /// Get the rental pool with optional filters.
  /// [lat]/[lng] + [radiusKm] filter by distance from a point,
  /// [category], [minPrice]/[maxPrice] filter pricing, and
  /// [availableOnly] keeps only currently-available items.
  static Future<List<Map<String, dynamic>>> getRentalPoolFiltered({
    double? lat,
    double? lng,
    double? radiusKm,
    String? category,
    double? minPrice,
    double? maxPrice,
    bool availableOnly = false,
  }) async {
    final params = <String>[];
    if (lat != null) params.add('lat=$lat');
    if (lng != null) params.add('lng=$lng');
    if (radiusKm != null) params.add('radius=$radiusKm');
    if (category != null && category.isNotEmpty) params.add('category=${Uri.encodeQueryComponent(category)}');
    if (minPrice != null) params.add('minPrice=$minPrice');
    if (maxPrice != null) params.add('maxPrice=$maxPrice');
    if (availableOnly) params.add('availableOnly=true');

    final query = params.isEmpty ? '' : '?${params.join('&')}';
    final response = await PublicApiClient.get('rental-pool$query');
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

  /// Request a return for a rented product.
  /// The server generates a NEW return gate-pass (a fresh QR, separate from
  /// the pickup QR). The warehouse scans that return QR to verify and finally
  /// complete the return. Returns the new `returnGatePassCode`.
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

  /// Get the active rental portal for a confirmed booking.
  /// Includes live status, countdown deadline, digital gate-pass and the
  /// warehouse scan audit trail.
  static Future<Map<String, dynamic>> getRentalPortal(String rentalId) async {
    final response = await PublicApiClient.get('rentals/$rentalId/portal');
    return jsonDecode(response.body);
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
