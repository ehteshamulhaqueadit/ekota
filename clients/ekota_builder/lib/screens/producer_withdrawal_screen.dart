import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../widgets/app_bottom_nav.dart';

class ProducerWithdrawalScreen extends StatefulWidget {
  const ProducerWithdrawalScreen({super.key});

  @override
  State<ProducerWithdrawalScreen> createState() => _ProducerWithdrawalScreenState();
}

class _ProducerWithdrawalScreenState extends State<ProducerWithdrawalScreen> {
  final _amountController = TextEditingController(text: '45000');
  final _accountController = TextEditingController(text: '01711-223344');
  String _withdrawMethod = 'BKASH';
  bool _isSubmitting = false;
  String? _error;
  String? _success;

  double _availableBalance = 245000.0;
  double _pendingWithdrawal = 45000.0;
  List<dynamic> _requests = [];
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadWithdrawalData();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _loadWithdrawalData();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _amountController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  Future<void> _loadWithdrawalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt') ?? prefs.getString('auth_token') ?? 'dev-token';

      final balUrl = Uri.parse('${AppConfig.apiBaseUrl}/withdrawals/balance');
      final balRes = await http.get(balUrl, headers: {'Authorization': 'Bearer $token'});

      if (balRes.statusCode == 200) {
        final balData = jsonDecode(balRes.body);
        if (mounted) {
          setState(() {
            _availableBalance = (balData['availableBalance'] as num?)?.toDouble() ?? 245000.0;
            _pendingWithdrawal = (balData['pendingWithdrawal'] as num?)?.toDouble() ?? 45000.0;
          });
        }
      }

      final reqUrl = Uri.parse('${AppConfig.apiBaseUrl}/withdrawals/my');
      final reqRes = await http.get(reqUrl, headers: {'Authorization': 'Bearer $token'});

      if (reqRes.statusCode == 200) {
        final reqData = jsonDecode(reqRes.body);
        if (mounted) {
          setState(() {
            _requests = reqData['requests'] ?? [];
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _submitRequest() async {
    final amt = double.tryParse(_amountController.text.trim());
    final acc = _accountController.text.trim();

    if (amt == null || amt <= 0) {
      setState(() => _error = 'Enter a valid positive withdrawal amount');
      return;
    }

    if (acc.isEmpty) {
      setState(() => _error = 'Account or mobile number is required');
      return;
    }

    if (amt > _availableBalance) {
      setState(() => _error = 'Withdrawal Denied: Requested amount (৳${amt.toStringAsFixed(2)}) exceeds your available wallet balance (৳${_availableBalance.toStringAsFixed(2)} BDT).');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
      _success = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt') ?? prefs.getString('auth_token') ?? 'dev-token';

      final url = Uri.parse('${AppConfig.apiBaseUrl}/withdrawals/request');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'amount': amt,
          'method': _withdrawMethod,
          'accountNumber': acc,
          'accountDetails': {'accountNumber': acc},
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 201 || response.statusCode == 200 || data['success'] == true) {
        setState(() {
          _success = 'Withdrawal request submitted to Admin successfully! Status: PENDING';
        });
        _loadWithdrawalData();
      } else {
        setState(() => _error = data['message'] ?? 'Submission failed');
      }
    } catch (e) {
      setState(() => _error = 'Error submitting request: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Producer Payout Withdrawals'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadWithdrawalData),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Balance Card
            Card(
              color: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Available Balance', style: TextStyle(color: Colors.grey, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text('৳${_availableBalance.toStringAsFixed(2)} BDT',
                                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const CircleAvatar(
                          backgroundColor: Colors.white12,
                          child: Icon(Icons.account_balance_wallet, color: Colors.greenAccent),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white24, height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Pending Admin Review:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        Text('৳${_pendingWithdrawal.toStringAsFixed(2)} BDT',
                            style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Withdrawal Form Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Request Payout Withdrawal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('Submit request to Admins for review & bank/wallet transfer', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 16),

                    Row(
                      children: ['BKASH', 'NAGAD', 'BANK_TRANSFER'].map((m) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(m),
                            selected: _withdrawMethod == m,
                            selectedColor: Colors.black,
                            labelStyle: TextStyle(color: _withdrawMethod == m ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                            onSelected: (val) {
                              if (val) setState(() => _withdrawMethod = m);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Withdrawal Amount (BDT)',
                        prefixText: '৳ ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: _accountController,
                      decoration: InputDecoration(
                        labelText: _withdrawMethod == 'BANK_TRANSFER' ? 'Account No / IBAN' : 'bKash / Nagad Phone Number',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                      ),

                    if (_success != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Text(_success!, style: const TextStyle(color: Colors.green, fontSize: 13)),
                      ),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.send, color: Colors.white, size: 18),
                        label: _isSubmitting
                            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                            : const Text('Submit Payout Request to Admin', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isSubmitting ? null : _submitRequest,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // History List
            const Text('My Withdrawal Requests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            if (_requests.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                child: const Text('No withdrawal requests found.', style: TextStyle(color: Colors.grey)),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _requests.length,
                itemBuilder: (context, index) {
                  final item = _requests[index];
                  final st = (item['status'] ?? 'PENDING').toString().toUpperCase();
                  final amt = (item['amount'] is num) ? (item['amount'] as num).toDouble() : double.parse(item['amount'].toString());
                  final method = item['method'] ?? item['paymentMethod'] ?? 'BKASH';
                  final acc = item['accountNumber'] ?? item['accountDetails']?['accountNumber'] ?? '—';

                  final isApproved = st == 'APPROVED';
                  final isRejected = st == 'REJECTED';

                  final badgeColor = isApproved ? Colors.green : isRejected ? Colors.red : Colors.amber.shade800;
                  final badgeBg = isApproved ? Colors.green.shade50 : isRejected ? Colors.red.shade50 : Colors.amber.shade50;
                  final iconData = isApproved ? Icons.check_circle : isRejected ? Icons.cancel : Icons.access_time;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: badgeBg, child: Icon(iconData, color: badgeColor)),
                      title: Text('৳${amt.toStringAsFixed(2)} BDT', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('$method • $acc'),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: badgeColor),
                        ),
                        child: Text(st, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeColor)),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
    );
  }
}
