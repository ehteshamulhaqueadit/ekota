import 'dart:convert';
import 'api_client.dart';

class InvestmentService {
  /// Get all listings available for investment
  static Future<List<Map<String, dynamic>>> getAvailableListings() async {
    final response = await ApiClient.get('listings/available');
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    return [];
  }

  /// Invest in a product
  static Future<Map<String, dynamic>> invest({
    required String listingId,
    required double amount,
  }) async {
    final response = await ApiClient.post('investments', body: {
      'listingId': listingId,
      'amount': amount,
    });
    return jsonDecode(response.body);
  }

  /// Get all my investments
  static Future<List<Map<String, dynamic>>> getMyInvestments() async {
    final response = await ApiClient.get('investments/my');
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    return [];
  }

  /// Get investors for a listing
  static Future<Map<String, dynamic>> getListingInvestors(String listingId) async {
    final response = await ApiClient.get('listings/$listingId/investments');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {};
  }

  /// Get funding status for a listing
  static Future<Map<String, dynamic>> getFundingStatus(String listingId) async {
    final response = await ApiClient.get('listings/$listingId/funding-status');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {};
  }

  /// Get listing details
  static Future<Map<String, dynamic>?> getListingDetails(String listingId) async {
    final response = await ApiClient.get('listings/$listingId');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }
}
