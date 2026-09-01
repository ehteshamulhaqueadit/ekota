import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';

class AddMoneyScreen extends StatefulWidget {
  const AddMoneyScreen({super.key});

  @override
  State<AddMoneyScreen> createState() => _AddMoneyScreenState();
}

class _AddMoneyScreenState extends State<AddMoneyScreen> {
  final _amountController = TextEditingController(text: '1000');
  bool _isSubmitting = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submitDeposit() async {
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      setState(() { _error = 'Please enter a valid amount greater than ৳0'; });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
      _success = null;
    });

    try {
      final res = await WalletService().initiateAddMoney(amount: amount);

      final gatewayUrlStr = res['gatewayPageUrl'];

      if (gatewayUrlStr != null && gatewayUrlStr.toString().isNotEmpty) {
        final url = Uri.parse(gatewayUrlStr);
        bool launched = false;

        try {
          launched = await launchUrl(url, webOnlyWindowName: '_blank');
        } catch (_) {}

        if (!launched) {
          try {
            launched = await launchUrl(url, mode: LaunchMode.externalApplication);
          } catch (_) {}
        }

        if (!launched) {
          await launchUrl(url);
        }

        setState(() {
          _success = 'SSLCommerz gateway opened. Complete the payment in the browser window to submit for Admin validation.';
        });
      } else {
        setState(() {
          _error = res['message'] ?? 'Failed to initialize SSLCommerz gateway';
        });
      }
    } catch (e) {
      setState(() { _error = 'Error initiating deposit: $e'; });
    } finally {
      if (mounted) setState(() { _isSubmitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Money to Wallet'),
        backgroundColor: AppTheme.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Deposit Amount (BDT)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    decoration: const InputDecoration(
                      prefixText: '৳ ',
                      prefixStyle: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 16),
                      hintText: 'Enter amount (e.g. 5000)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [500, 1000, 5000, 10000].map((preset) {
                      final isSelected = _amountController.text == preset.toString();
                      return ChoiceChip(
                        label: Text(
                          '৳$preset',
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: AppTheme.accent,
                        backgroundColor: const Color(0xFF1E293B),
                        onSelected: (_) {
                          setState(() {
                            _amountController.text = preset.toString();
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.dangerBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.dangerBorder),
                ),
                child: Text(_error!, style: const TextStyle(color: AppTheme.dangerText)),
              ),
            if (_success != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.successBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.successBorder),
                ),
                child: Text(_success!, style: const TextStyle(color: AppTheme.successText)),
              ),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitDeposit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppTheme.accent,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Proceed to SSLCommerz Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
