import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/wallet_service.dart';
import '../theme/app_colors.dart';

class AddMoneyScreen extends StatefulWidget {
  const AddMoneyScreen({super.key});

  @override
  State<AddMoneyScreen> createState() => _AddMoneyScreenState();
}

class _AddMoneyScreenState extends State<AddMoneyScreen> {
  final TextEditingController _amountController = TextEditingController(text: '1000');
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  final List<double> _presetAmounts = [1000, 5000, 10000, 50000];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _handleAddMoney() async {
    final amtText = _amountController.text.trim();
    final amount = double.tryParse(amtText);

    if (amount == null || amount <= 0) {
      setState(() {
        _errorMessage = 'Please enter a valid positive amount.';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final res = await WalletService().initiateAddMoney(amount: amount);

      if (res['success'] == true && res['gatewayPageUrl'] != null) {
        final gatewayUrl = res['gatewayPageUrl'].toString();
        final uri = Uri.parse(gatewayUrl);

        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
        } else {
          await launchUrl(uri);
        }

        setState(() {
          _successMessage = 'SSLCommerz payment session created. Status: PENDING Admin Verification.';
        });
      } else {
        setState(() {
          _errorMessage = res['message'] ?? 'Failed to create payment session.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error initiating payment: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Money to Wallet'),
        backgroundColor: AppColors.dark,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.account_balance_wallet, color: AppColors.accent, size: 24),
                        SizedBox(width: 10),
                        Text(
                          'SSLCommerz Secure Deposit',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Deposit money into your Builder Wallet via bKash, Nagad, Cards, or Net Banking.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 20),

                    const Text('Select or Enter Amount (BDT)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _presetAmounts.map((amt) {
                        final isSelected = _amountController.text == amt.toInt().toString();
                        return ActionChip(
                          avatar: const Icon(Icons.add, size: 16, color: Colors.black),
                          label: Text(
                            '৳${amt.toInt()}',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          backgroundColor: isSelected ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                          side: BorderSide(
                            color: isSelected ? const Color(0xFFB98A5E) : Colors.grey.shade400,
                            width: isSelected ? 2.0 : 1.0,
                          ),
                          onPressed: () {
                            setState(() {
                              _amountController.text = amt.toInt().toString();
                            });
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                      decoration: const InputDecoration(
                        labelText: 'Deposit Amount (৳)',
                        labelStyle: TextStyle(color: Colors.black54),
                        prefixText: '৳ ',
                        prefixStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.black, width: 2),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                      ),

                    if (_successMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Text(_successMessage!, style: const TextStyle(color: Colors.green, fontSize: 13)),
                      ),

                    SizedBox(
                      height: 50,
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.lock, color: Colors.white),
                        label: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                            : const Text('Proceed to SSLCommerz', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isLoading ? null : _handleAddMoney,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
