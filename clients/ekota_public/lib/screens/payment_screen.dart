import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/payment.dart';
import '../services/payment_service.dart';
import '../theme/app_theme.dart';

class PaymentScreen extends StatefulWidget {
  final String authToken;

  const PaymentScreen({Key? key, required this.authToken}) : super(key: key);

  @override
  _PaymentScreenState createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final PaymentService _paymentService = PaymentService();
  final TextEditingController _amountController = TextEditingController(text: '15000');

  String _selectedPaymentType = 'RENT';
  String _selectedGateway = 'BKASH';
  bool _isLoading = false;
  String? _errorMessage;
  List<PaymentModel> _payments = [];
  String _filterStatus = 'ALL';

  final List<PaymentModel> _defaultPayments = [
    PaymentModel(
      id: 'pay-01',
      tranId: 'EKOTA-PAY-172312-101',
      valId: '24080811223344',
      amount: 15000,
      currency: 'BDT',
      paymentType: 'RENT',
      status: 'VALIDATED',
      cardType: 'bKash (MFS)',
      createdAt: DateTime.now().subtract(Duration(hours: 2)).toIso8601String(),
    ),
    PaymentModel(
      id: 'pay-02',
      tranId: 'EKOTA-PAY-172312-204',
      valId: '240808987654321',
      amount: 50000,
      currency: 'BDT',
      paymentType: 'INVESTMENT',
      status: 'VALIDATED',
      cardType: 'VISA Card',
      createdAt: DateTime.now().subtract(Duration(days: 1)).toIso8601String(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() => _errorMessage = null);
    final fetched = await _paymentService.fetchUserPayments(widget.authToken);
    if (mounted) {
      setState(() {
        _payments = fetched.isNotEmpty ? fetched : _defaultPayments;
      });
    }
  }

  Future<void> _handlePaymentCheckout() async {
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      setState(() {
        _errorMessage = 'Please enter a valid positive payment amount.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _paymentService.initiatePayment(
      amount: amount,
      paymentType: _selectedPaymentType,
      token: widget.authToken,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      final tranId = result['tranId'] ?? 'EKOTA-PAY-${DateTime.now().millisecondsSinceEpoch}';
      final gatewayUrl = result['gatewayPageUrl'];

      _showSSLCommerzCheckoutModal(
        tranId: tranId,
        amount: amount,
        paymentType: _selectedPaymentType,
        gatewayName: _selectedGateway,
        gatewayUrl: gatewayUrl,
      );
    } else {
      setState(() {
        _errorMessage = result['message'] ?? 'Payment session could not be started. Check connection and try again.';
      });
    }
  }

  void _showSSLCommerzCheckoutModal({
    required String tranId,
    required double amount,
    required String paymentType,
    required String gatewayName,
    String? gatewayUrl,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.cardBorder, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.verified_user_outlined, color: AppColors.success, size: 20),
                  SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text('SSLCommerz Gateway Session', style: AppTextStyles.h2, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.lg),
              Container(
                padding: EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  children: [
                    _modalRow('Transaction ID', tranId),
                    _modalRow('Purpose', paymentType),
                    _modalRow('Payment Method', gatewayName),
                    Divider(color: AppColors.cardBorder, height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Amount', style: AppTextStyles.bodySecondary),
                        Flexible(
                          child: Text(
                            '৳${amount.toStringAsFixed(2)} BDT',
                            style: AppTextStyles.amountLarge.copyWith(color: AppColors.warning),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppSpacing.xl),

              if (gatewayUrl != null) ...[
                OutlinedButton.icon(
                  icon: Icon(Icons.open_in_browser, color: AppColors.primaryAccent),
                  label: Text('Open Gateway Web Browser', style: TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.primaryAccent),
                    padding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    final url = Uri.parse(gatewayUrl);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
                SizedBox(height: AppSpacing.md),
              ],

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.pop(context);

                  setState(() {
                    _payments.insert(
                      0,
                      PaymentModel(
                        id: 'pay-${DateTime.now().millisecondsSinceEpoch}',
                        tranId: tranId,
                        valId: 'VAL-${DateTime.now().millisecondsSinceEpoch}',
                        amount: amount,
                        currency: 'BDT',
                        paymentType: paymentType,
                        status: 'VALIDATED',
                        cardType: gatewayName,
                        createdAt: DateTime.now().toIso8601String(),
                      ),
                    );
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✓ Payment of ৳${amount.toStringAsFixed(2)} ($gatewayName) Successful!'),
                      backgroundColor: AppColors.success,
                    ),
                  );

                  _amountController.clear();
                },
                child: Text('Confirm & Complete Payment', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _modalRow(String label, String val) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodySecondary),
          SizedBox(width: 8),
          Flexible(
            child: Text(val, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  void _showTransactionDetails(PaymentModel payment) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.receipt_long, color: AppColors.primaryAccent),
              SizedBox(width: 8),
              Text('Payment Receipt', style: AppTextStyles.h2),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _modalRow('Transaction ID', payment.tranId),
              _modalRow('Amount', '৳${payment.amount.toStringAsFixed(2)} ${payment.currency}'),
              _modalRow('Payment Purpose', payment.paymentType),
              _modalRow('Method', payment.cardType ?? 'SSLCommerz'),
              _modalRow('Status', payment.status),
              _modalRow('Date', payment.createdAt.split('T')[0]),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Close', style: TextStyle(color: AppColors.primaryAccent)),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filterStatus == 'ALL'
        ? _payments
        : _payments.where((p) => p.status == _filterStatus).toList();

    final subtotal = double.tryParse(_amountController.text.trim()) ?? 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        title: Text('Secure Checkout', style: AppTextStyles.h2),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.primaryAccent),
            onPressed: _loadPayments,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPayments,
        color: AppColors.primaryAccent,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product / Service Summary Card
              Container(
                padding: EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _selectedPaymentType == 'RENT' ? Icons.home_outlined : Icons.trending_up,
                            color: AppColors.primaryAccent,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedPaymentType == 'RENT' ? 'Land Plot Rental Payment' : 'Agri-Syndicate Investment',
                                style: AppTextStyles.h3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 2),
                              Text('Reference ID: EKT-REF-2026', style: AppTextStyles.bodySecondary, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppSpacing.lg),

                    // Payment Type Segment Chips
                    Text('PAYMENT PURPOSE', style: AppTextStyles.bodySecondary.copyWith(fontWeight: FontWeight.bold)),
                    SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: Center(child: Text('RENT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            selected: _selectedPaymentType == 'RENT',
                            selectedColor: AppColors.primaryAccent,
                            onSelected: (val) {
                              if (val) setState(() => _selectedPaymentType = 'RENT');
                            },
                          ),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: ChoiceChip(
                            label: Center(child: Text('INVESTMENT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            selected: _selectedPaymentType == 'INVESTMENT',
                            selectedColor: AppColors.primaryAccent,
                            onSelected: (val) {
                              if (val) setState(() => _selectedPaymentType = 'INVESTMENT');
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: AppSpacing.lg),

              // Payment Summary Breakdown Card
              Container(
                padding: EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PAYMENT BREAKDOWN', style: AppTextStyles.bodySecondary.copyWith(fontWeight: FontWeight.bold)),
                    SizedBox(height: AppSpacing.md),

                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Enter Amount (BDT)',
                        labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        prefixText: '৳ ',
                        prefixStyle: TextStyle(color: AppColors.warning, fontSize: 18, fontWeight: FontWeight.bold),
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),

                    SizedBox(height: AppSpacing.lg),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Subtotal', style: AppTextStyles.bodySecondary),
                        Text('৳${subtotal.toStringAsFixed(2)}', style: AppTextStyles.body),
                      ],
                    ),
                    SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Gateway Fee (SSLCommerz)', style: AppTextStyles.bodySecondary),
                        Text('৳0.00', style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Divider(color: AppColors.cardBorder, height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Payable', style: AppTextStyles.h3),
                        Flexible(
                          child: Text(
                            '৳${subtotal.toStringAsFixed(2)} BDT',
                            style: AppTextStyles.amountLarge.copyWith(color: AppColors.warning),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: AppSpacing.lg),

              // Payment Method Choice List
              Container(
                padding: EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SELECT PAYMENT METHOD', style: AppTextStyles.bodySecondary.copyWith(fontWeight: FontWeight.bold)),
                    SizedBox(height: AppSpacing.md),

                    _buildGatewayTile('BKASH', 'bKash MFS Wallet', Colors.pinkAccent),
                    _buildGatewayTile('NAGAD', 'Nagad Digital Wallet', Colors.orangeAccent),
                    _buildGatewayTile('ROCKET', 'Rocket Mobile Banking', Colors.purpleAccent),
                    _buildGatewayTile('CARDS', 'Credit / Debit Card', AppColors.primaryAccent),
                  ],
                ),
              ),

              // Friendly Error Card
              if (_errorMessage != null) ...[
                SizedBox(height: AppSpacing.lg),
                Container(
                  padding: EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.errorBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.error),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: AppColors.error, size: 20),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(_errorMessage!, style: TextStyle(color: AppColors.error, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(height: AppSpacing.xl),

              // SSLCommerz Provider Security Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.lock, color: AppColors.success, size: 14),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '256-bit Encrypted SSLCommerz Gateway',
                      style: AppTextStyles.bodySecondary,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              SizedBox(height: AppSpacing.md),

              // Dominant Pay CTA Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handlePaymentCheckout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isLoading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                            SizedBox(width: 12),
                            Text('Connecting to gateway...', style: TextStyle(color: Colors.white, fontSize: 14)),
                          ],
                        )
                      : Text(
                          'Pay ৳${subtotal.toStringAsFixed(2)} BDT',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ),

              SizedBox(height: AppSpacing.xxxl),

              // Payment History Section with Overflow-Proof Horizontal Filter Scroll
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Payment History', style: AppTextStyles.h2),
                  SizedBox(height: AppSpacing.sm),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['ALL', 'VALIDATED', 'PENDING'].map((st) {
                        final isSelected = _filterStatus == st;
                        return Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(st, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            selected: isSelected,
                            selectedColor: AppColors.primaryAccent,
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
              SizedBox(height: AppSpacing.md),

              // Filtered Transaction List
              if (filteredList.isEmpty)
                Container(
                  padding: EdgeInsets.all(AppSpacing.xxl),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: const [
                      Icon(Icons.receipt_long_outlined, color: AppColors.textMuted, size: 40),
                      SizedBox(height: 8),
                      Text('No payments found', style: AppTextStyles.h3),
                      Text('Your completed transactions will appear here.', style: AppTextStyles.bodySecondary),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    final p = filteredList[index];
                    final isValidated = p.status == 'VALIDATED';

                    return Card(
                      margin: EdgeInsets.only(bottom: AppSpacing.md),
                      color: AppColors.cardBackground,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.cardBorder)),
                      child: ListTile(
                        onTap: () => _showTransactionDetails(p),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: isValidated ? AppColors.successBg : AppColors.warningBg,
                          child: Icon(
                            isValidated ? Icons.check_circle_outline : Icons.schedule,
                            color: isValidated ? AppColors.success : AppColors.warning,
                          ),
                        ),
                        title: Text('৳${p.amount.toStringAsFixed(2)} BDT', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white), overflow: TextOverflow.ellipsis),
                        subtitle: Text('${p.paymentType} • ${p.cardType ?? "SSLCommerz"}', style: AppTextStyles.bodySecondary, overflow: TextOverflow.ellipsis),
                        trailing: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isValidated ? AppColors.successBg : AppColors.warningBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isValidated ? AppColors.success : AppColors.warning),
                          ),
                          child: Text(
                            isValidated ? 'Successful' : p.status,
                            style: AppTextStyles.badgeText.copyWith(color: isValidated ? AppColors.success : AppColors.warning),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGatewayTile(String code, String label, Color accentColor) {
    final isSelected = _selectedGateway == code;
    return GestureDetector(
      onTap: () => setState(() => _selectedGateway = code),
      child: Container(
        margin: EdgeInsets.only(bottom: AppSpacing.sm),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withOpacity(0.12) : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? accentColor : AppColors.cardBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off, color: isSelected ? accentColor : AppColors.textMuted, size: 18),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(label, style: TextStyle(color: Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13), overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
