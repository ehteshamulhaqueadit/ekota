import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/withdrawal_model.dart';

String get defaultWithdrawalApiUrl {
  if (!kIsWeb && Platform.isAndroid) {
    return 'http://10.0.2.2:5000/api/withdrawals';
  }
  return 'http://localhost:5000/api/withdrawals';
}

class WithdrawalService {
  final String baseUrl;

  WithdrawalService({String? baseUrl}) : baseUrl = baseUrl ?? defaultWithdrawalApiUrl;

  Future<ProducerBalanceModel?> fetchBalance(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/balance'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ProducerBalanceModel.fromJson(data['balance']);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<WithdrawalRequestModel>> fetchMyRequests(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/my-requests'),
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
      if (response.statusCode == 201) {
        return {'success': true, 'message': 'Request submitted successfully'};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Submission failed'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
