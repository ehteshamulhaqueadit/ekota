import 'package:flutter/material.dart';
import '../models/wallet_model.dart';
import '../models/wallet_transaction_model.dart';
import '../services/wallet_service.dart';

class WalletProvider with ChangeNotifier {
  final WalletService _service = WalletService();

  WalletModel? _wallet;
  List<WalletTransactionModel> _transactions = [];
  bool _isLoading = false;
  String? _error;

  WalletModel? get wallet => _wallet;
  List<WalletTransactionModel> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get error => _error;
  double get balance => _wallet?.balance ?? 0.0;

  Future<void> loadWallet() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _wallet = await _service.fetchWallet();
      _transactions = await _service.fetchTransactions();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await loadWallet();
  }
}
