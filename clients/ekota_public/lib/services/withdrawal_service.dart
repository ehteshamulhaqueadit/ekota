import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/withdrawal_model.dart';

class WithdrawalService {
  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? 'dev-token';
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<WithdrawalBalanceModel?> fetchBalance() async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}/withdrawals/balance');
    final response = await http.get(url, headers: await _headers());

    if (response.statusCode == 200) {
      return WithdrawalBalanceModel.fromJson(jsonDecode(response.body));
    }
    return null;
  }

  Future<List<WithdrawalRequestModel>> fetchMyRequests() async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}/withdrawals/my-requests');
    final response = await http.get(url, headers: await _headers());

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List list = data['requests'] ?? [];
      return list.map((item) => WithdrawalRequestModel.fromJson(item)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> submitWithdrawal({
    required double amount,
    required String method,
    required Map<String, dynamic> accountDetails,
  }) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}/withdrawals/request');
    final response = await http.post(
      url,
      headers: await _headers(),
      body: jsonEncode({
        'amount': amount,
        'method': method,
        'accountDetails': accountDetails,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    return {
      'success': false,
      'message': 'Failed to submit withdrawal request',
    };
  }
}
