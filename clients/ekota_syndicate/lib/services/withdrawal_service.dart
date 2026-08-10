import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/withdrawal_model.dart';

class WithdrawalService {
  final String baseUrl;

  WithdrawalService({String? customUrl}) : baseUrl = customUrl ?? ApiConfig.withdrawalApiUrl;

  Future<ProducerBalanceModel?> fetchBalance(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/balance'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ProducerBalanceModel.fromJson(data);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<WithdrawalRequestModel>> fetchMyRequests(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/my'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List list = data['requests'] ?? [];
        return list.map((item) => WithdrawalRequestModel.fromJson(item)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<dynamic>> fetchUserPayments(String token) async {
    try {
      final paymentUrl = baseUrl.replaceAll('/withdrawals', '/payments/my');
      final response = await http.get(
        Uri.parse(paymentUrl),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['payments'] ?? [];
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> submitWithdrawal({
    required double amount,
    required String method,
    required Map<String, dynamic> accountDetails,
    required String token,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/request'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'amount': amount,
          'method': method,
          'accountDetails': accountDetails,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'message': 'Withdrawal request submitted to Admin successfully'};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Submission failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network connection failed. Is backend server running?'};
    }
  }

  Future<Map<String, dynamic>> initiatePayment({
    required double amount,
    required String paymentType,
    required String token,
  }) async {
    try {
      final paymentUrl = baseUrl.replaceAll('/withdrawals', '/payments/initiate');
      final response = await http.post(
        Uri.parse(paymentUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'amount': amount,
          'paymentType': paymentType,
          'productName': 'Ekota Investment Funding',
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return {
          'success': true,
          'gatewayPageUrl': data['gatewayPageUrl'],
          'tranId': data['tranId'],
        };
      }
      return {'success': false, 'message': data['message'] ?? 'Payment initiation failed'};
    } catch (e) {
      return {'success': false, 'message': 'Network connection failed: $e'};
    }
  }
}
