import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/payment.dart';

String get defaultPaymentApiUrl {
  if (!kIsWeb && Platform.isAndroid) {
    return 'http://10.0.2.2:5000/api/payments';
  }
  return 'http://localhost:5000/api/payments';
}

class PaymentService {
  final String baseUrl;

  PaymentService({String? baseUrl}) : baseUrl = baseUrl ?? defaultPaymentApiUrl;

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
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return {
          'success': true,
          'gatewayPageUrl': data['gatewayPageUrl'],
          'tranId': data['tranId'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to initiate payment',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  Future<List<PaymentModel>> fetchUserPayments(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/my-payments'),
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
