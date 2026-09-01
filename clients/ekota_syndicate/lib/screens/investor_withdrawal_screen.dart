import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/withdrawal_model.dart';
import '../services/withdrawal_service.dart';
import '../theme/app_theme.dart';

class InvestorWithdrawalScreen extends StatefulWidget {
  const InvestorWithdrawalScreen({super.key});

  @override
  State<InvestorWithdrawalScreen> createState() => _InvestorWithdrawalScreenState();
}

class _InvestorWithdrawalScreenState extends State<InvestorWithdrawalScreen> {
  final _withdrawAmountController = TextEditingController(text: '25000');
  final _accountController = TextEditingController();
  String _withdrawMethod = 'BKASH';
  bool _isWithdrawing = false;
  String? _withdrawError;
  String? _withdrawSuccess;

  double _availableBalance = 150000.0;
  List<WithdrawalRequestModel> _withdrawals = [];
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _withdrawAmountController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? 'dev-token';
      
      final service = WithdrawalService();
      final balData = await service.fetchBalance(token);
      final list = await service.fetchMyRequests(token);

      if (mounted) {
        setState(() {
          if (balData != null) {
            _availableBalance = balData.availableBalance;
          }
          _withdrawals = list;
        });
      }
    } catch (_) {}
  }

  Future<void> _handleWithdrawalSubmit() async {
    final amt = double.tryParse(_withdrawAmountController.text.trim());
    final acc = _accountController.text.trim();

    if (amt == null || amt <= 0) {
      setState(() => _withdrawError = 'Enter a valid withdrawal amount');
      return;
    }

    if (acc.isEmpty) {
      setState(() => _withdrawError = 'Account / Phone number is required');
      return;
    }

    if (amt > _availableBalance) {
      setState(() => _withdrawError = 'Withdrawal Denied: Requested amount (৳${amt.toStringAsFixed(2)}) exceeds your available wallet balance (৳${_availableBalance.toStringAsFixed(2)} BDT).');
      return;
    }

    setState(() {
      _isWithdrawing = true;
      _withdrawError = null;
      _withdrawSuccess = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? 'dev-token';

      final res = await WithdrawalService().submitWithdrawal(
        amount: amt,
        method: _withdrawMethod,
        accountDetails: {'accountNumber': acc},
        token: token,
      );

      if (res['success'] == true) {
        setState(() {
          _withdrawSuccess = 'Withdrawal request submitted to Admin! Status: PENDING';
          _accountController.clear();
        });
        _loadData();
      } else {
        setState(() => _withdrawError = res['message'] ?? 'Submission failed');
      }
    } catch (e) {
      setState(() => _withdrawError = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isWithdrawing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payout Withdrawal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3)),
            Text('Transfer earnings to bank or mobile wallet', style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.normal)),
          ],
        ),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh, size: 20), tooltip: 'Refresh', onPressed: _loadData),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Available Balance Card
            Card(
              color: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Available Balance', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text('৳${_availableBalance.toStringAsFixed(2)} BDT', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const CircleAvatar(
                      backgroundColor: Color(0xFF1E293B),
                      child: Icon(Icons.account_balance_wallet, color: Color(0xFF10B981)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Request Withdrawal Form
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Request Payout Withdrawal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Text('Request funds transfer to your bank or mobile wallet', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 16),
                    Row(
                      children: ['BKASH', 'NAGAD', 'BANK_TRANSFER'].map((m) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(m),
                            selected: _withdrawMethod == m,
                            selectedColor: const Color(0xFF0F172A),
                            labelStyle: TextStyle(color: _withdrawMethod == m ? Colors.white : Colors.black),
                            onSelected: (val) {
                              if (val) setState(() => _withdrawMethod = m);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _withdrawAmountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Withdraw Amount (BDT)', prefixText: '৳ ', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _accountController,
                      decoration: InputDecoration(labelText: _withdrawMethod == 'BANK_TRANSFER' ? 'Account No / IBAN' : 'bKash/Nagad Phone Number', border: const OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    if (_withdrawError != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Text(_withdrawError!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                      ),
                    if (_withdrawSuccess != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Text(_withdrawSuccess!, style: const TextStyle(color: Colors.green, fontSize: 13)),
                      ),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.outbox, color: Colors.white, size: 18),
                        label: _isWithdrawing
                            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                            : const Text('Submit Payout Request', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                        onPressed: _isWithdrawing ? null : _handleWithdrawalSubmit,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Withdrawal Request History List with Live Badges
            const Text('Payout Request History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_withdrawals.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                child: const Text('No withdrawal requests submitted yet.', style: TextStyle(color: Colors.grey)),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _withdrawals.length,
                itemBuilder: (context, index) {
                  final item = _withdrawals[index];
                  final st = item.status.toUpperCase();
                  final isApproved = st == 'APPROVED' || st == 'PROCESSED' || st == 'COMPLETED';
                  final isRejected = st == 'REJECTED' || st == 'CANCELLED';

                  final badgeColor = isApproved
                      ? Colors.green
                      : isRejected
                          ? Colors.red
                          : Colors.amber.shade800;

                  final badgeBg = isApproved
                      ? Colors.green.shade50
                      : isRejected
                          ? Colors.red.shade50
                          : Colors.amber.shade50;

                  final iconData = isApproved
                      ? Icons.check_circle
                      : isRejected
                          ? Icons.cancel
                          : Icons.access_time;

                  final statusText = isApproved
                      ? 'APPROVED'
                      : isRejected
                          ? 'REJECTED'
                          : 'PENDING';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: badgeBg, child: Icon(iconData, color: badgeColor)),
                      title: Text('৳${item.amount.toStringAsFixed(2)} BDT', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${item.method} • ${item.createdAt.toString().split('.')[0]}'),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: badgeColor),
                        ),
                        child: Text(statusText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeColor)),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
