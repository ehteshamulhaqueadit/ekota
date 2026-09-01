import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/wallet_model.dart';
import '../models/wallet_transaction_model.dart';

class WalletService {
  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? prefs.getString('jwt') ?? 'dev-token';
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<WalletModel> fetchWallet() async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}/wallet');
    final response = await http.get(url, headers: await _headers());

    if (response.statusCode == 200) {
      return WalletModel.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load wallet');
  }

  Future<List<WalletTransactionModel>> fetchTransactions({int page = 1, int limit = 20}) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}/wallet/transactions?page=$page&limit=$limit');
    final response = await http.get(url, headers: await _headers());

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List list = data['transactions'] ?? [];
      return list.map((item) => WalletTransactionModel.fromJson(item)).toList();
    }
    throw Exception('Failed to load transactions');
  }

  Future<Map<String, dynamic>> initiateAddMoney({required double amount}) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}/payments/initiate');
    final response = await http.post(
      url,
      headers: await _headers(),
      body: jsonEncode({
        'amount': amount,
        'paymentType': 'DEPOSIT',
        'appSource': 'syndicate',
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    return {
      'success': false,
      'message': 'Failed to initiate deposit payment',
    };
  }
}
