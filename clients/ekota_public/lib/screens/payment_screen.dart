import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/payment.dart';
import '../services/payment_service.dart';
import 'login_screen.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _amountController = TextEditingController(text: '15000');
  String _paymentType = 'RENT';
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  List<PaymentModel> _payments = [];
  String _filterStatus = 'ALL';
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadPaymentHistory();
    // Auto-poll history every 3 seconds so status changes (VALIDATED/REJECTED by Admin) reflect live
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _loadPaymentHistory();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadPaymentHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? 'dev-token';
      final list = await PaymentService().fetchUserPayments(token);
      if (mounted) {
        setState(() {
          _payments = list;
        });
      }
    } catch (_) {}
  }

  Future<void> _handlePaymentCheckout() async {
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      setState(() => _errorMessage = 'Please enter a valid payment amount');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? 'dev-token';

      final result = await PaymentService().initiatePayment(
        amount: amount,
        paymentType: _paymentType,
        token: token,
      );

      if (result['success'] == true && result['gatewayPageUrl'] != null) {
        final urlString = result['gatewayPageUrl'] as String;
        final url = Uri.parse(urlString);

        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.inAppBrowserView);
        } else {
          await launchUrl(url);
        }

        setState(() {
          _successMessage = 'SSLCommerz payment session initiated. Status is PENDING admin verification.';
        });
        _loadPaymentHistory();
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to initiate SSLCommerz payment';
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Payment error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filterStatus == 'ALL'
        ? _payments
        : _payments.where((p) {
            final st = p.status.toUpperCase();
            if (_filterStatus == 'REJECTED') {
              return st == 'FAILED' || st == 'REJECTED' || st == 'CANCELLED';
            }
            return st == _filterStatus.toUpperCase();
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ekota Renters Payment'),
        backgroundColor: const Color(0xFF047857),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPaymentHistory,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              _pollingTimer?.cancel();
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Payment Form Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Make Secure Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('Pay rent or investment safely via SSLCommerz gateway', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 16),

                    // Payment Type Toggle
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('RENT PAYMENT')),
                            selected: _paymentType == 'RENT',
                            selectedColor: const Color(0xFF047857),
                            labelStyle: TextStyle(color: _paymentType == 'RENT' ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                            onSelected: (val) {
                              if (val) setState(() => _paymentType = 'RENT');
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('INVESTMENT')),
                            selected: _paymentType == 'INVESTMENT',
                            selectedColor: const Color(0xFF047857),
                            labelStyle: TextStyle(color: _paymentType == 'INVESTMENT' ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                            onSelected: (val) {
                              if (val) setState(() => _paymentType = 'INVESTMENT');
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Amount Input
                    TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Payment Amount (BDT)',
                        prefixText: '৳ ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Quick Amount Presets
                    Wrap(
                      spacing: 8,
                      children: [5000, 15000, 30000, 50000].map((amt) {
                        return ActionChip(
                          label: Text('৳$amt'),
                          onPressed: () {
                            setState(() => _amountController.text = amt.toString());
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                      ),

                    if (_successMessage != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Text(_successMessage!, style: const TextStyle(color: Colors.green, fontSize: 13)),
                      ),

                    // Pay Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.lock, color: Colors.white, size: 18),
                        label: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                            : Text('Pay ৳${_amountController.text} BDT via SSLCommerz', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF047857),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isLoading ? null : _handlePaymentCheckout,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Payment History Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Payment History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['ALL', 'VALIDATED', 'PENDING', 'REJECTED'].map((st) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: ChoiceChip(
                          label: Text(st, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          selected: _filterStatus == st,
                          selectedColor: const Color(0xFF047857),
                          labelStyle: TextStyle(color: _filterStatus == st ? Colors.white : Colors.black),
                          onSelected: (val) {
                            if (val) setState(() => _filterStatus = st);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (filteredList.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                child: const Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, color: Colors.grey, size: 36),
                    SizedBox(height: 8),
                    Text('No payments found', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Your completed transactions will appear here.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredList.length,
                itemBuilder: (context, index) {
                  final p = filteredList[index];
                  final st = p.status.toUpperCase();
                  final isValidated = st == 'VALIDATED';
                  final isRejected = st == 'FAILED' || st == 'REJECTED' || st == 'CANCELLED';

                  final badgeColor = isValidated
                      ? Colors.green
                      : isRejected
                          ? Colors.red
                          : Colors.amber.shade800;

                  final badgeBg = isValidated
                      ? Colors.green.shade50
                      : isRejected
                          ? Colors.red.shade50
                          : Colors.amber.shade50;

                  final iconData = isValidated
                      ? Icons.check_circle
                      : isRejected
                          ? Icons.cancel
                          : Icons.access_time;

                  final statusLabel = isValidated
                      ? 'VALIDATED'
                      : isRejected
                          ? 'REJECTED'
                          : 'PENDING';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: badgeBg,
                        child: Icon(iconData, color: badgeColor),
                      ),
                      title: Text('৳${p.amount.toStringAsFixed(2)} BDT', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${p.paymentType} • ${p.tranId}'),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: badgeColor),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                          ),
                        ),
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
