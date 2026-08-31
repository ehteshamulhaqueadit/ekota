import 'dart:convert';
import 'api_client.dart';

class WarehouseService {
  /// Store product in warehouse
  static Future<Map<String, dynamic>> storeInWarehouse(String listingId) async {
    final response = await ApiClient.post('warehouse/store', body: {
      'listingId': listingId,
    });
    return jsonDecode(response.body);
  }

  /// Retrieve product from warehouse
  static Future<Map<String, dynamic>> retrieveFromWarehouse(String listingId) async {
    final response = await ApiClient.post('warehouse/retrieve', body: {
      'listingId': listingId,
    });
    return jsonDecode(response.body);
  }

  /// Get warehouse fee for a product
  static Future<Map<String, dynamic>> getWarehouseFee(String listingId) async {
    final response = await ApiClient.get('warehouse/fees/$listingId');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {};
  }

  /// Get my warehouse items
  static Future<List<Map<String, dynamic>>> getMyWarehouseItems() async {
    final response = await ApiClient.get('warehouse/my');
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    return [];
  }
}
