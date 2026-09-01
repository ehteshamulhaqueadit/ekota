import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/payment.dart';

class PaymentService {
  final String baseUrl;

  PaymentService({String? customUrl}) : baseUrl = customUrl ?? ApiConfig.paymentApiUrl;

  Future<Map<String, dynamic>> initiatePayment({
    required double amount,
    required String paymentType,
    required String token,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/initiate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'amount': amount,
          'paymentType': paymentType,
          'appSource': 'public',
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return {
          'success': true,
          'gatewayPageUrl': data['gatewayPageUrl'],
          'tranId': data['tranId'],
          'amount': data['amount'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to initiate payment session',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network connection error. Is backend server running?',
      };
    }
  }

  Future<List<PaymentModel>> fetchUserPayments(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/my'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List list = data['payments'] ?? [];
        return list.map((item) => PaymentModel.fromJson(item)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
