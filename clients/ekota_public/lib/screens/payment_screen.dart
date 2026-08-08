import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/payment.dart';
import '../services/payment_service.dart';

class PaymentScreen extends StatefulWidget {
  final String authToken;

  const PaymentScreen({Key? key, required this.authToken}) : super(key: key);

  @override
  _PaymentScreenState createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final PaymentService _paymentService = PaymentService();
  final TextEditingController _amountController = TextEditingController();
  String _selectedPaymentType = 'RENT';
  String _selectedMethod = 'bKash';
  bool _isLoading = false;
  List<PaymentModel> _payments = [];

  final List<PaymentModel> _demoPayments = [
    PaymentModel(
      id: 'pay-01',
      tranId: 'EKOTA-PAY-172312-101',
      amount: 15000,
      currency: 'BDT',
      paymentType: 'RENT',
      status: 'VALIDATED',
      cardType: 'bKash-BKash',
      createdAt: DateTime.now().subtract(Duration(hours: 2)).toIso8601String(),
    ),
    PaymentModel(
      id: 'pay-02',
      tranId: 'EKOTA-PAY-172312-204',
      amount: 50000,
      currency: 'BDT',
      paymentType: 'INVESTMENT',
      status: 'VALIDATED',
      cardType: 'VISA-DBBL',
      createdAt: DateTime.now().subtract(Duration(days: 1)).toIso8601String(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    final fetched = await _paymentService.fetchUserPayments(widget.authToken);
    setState(() {
      _payments = fetched.isNotEmpty ? fetched : _demoPayments;
    });
  }

  Future<void> _handleInitiatePayment() async {
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a valid positive payment amount'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await _paymentService.initiatePayment(
      amount: amount,
      paymentType: _selectedPaymentType,
      token: widget.authToken,
    );

    setState(() => _isLoading = false);

    if (result['success'] == true && result['gatewayPageUrl'] != null) {
      final url = Uri.parse(result['gatewayPageUrl']);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('SSLCommerz URL: ${result['gatewayPageUrl']}')),
        );
      }

      _amountController.clear();
      _loadPayments();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment Session Initiated! Tran ID: ${result['tranId']}'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Payment session creation failed'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadPayments,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Payment Initiation Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              color: Color(0xFF1E293B),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.shield_outlined, color: Colors.greenAccent, size: 24),
                        SizedBox(width: 10),
                        Text(
                          'Secure Payment Gateway',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Pay rent fees or invest securely using SSLCommerz payment system.',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                    SizedBox(height: 20),

                    // Payment Type Radio Buttons
                    Text('Payment Purpose', style: TextStyle(color: Colors.grey[300], fontSize: 12, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: Center(child: Text('RENT PAYMENT')),
                            selected: _selectedPaymentType == 'RENT',
                            selectedColor: Colors.blueAccent,
                            onSelected: (val) {
                              if (val) setState(() => _selectedPaymentType = 'RENT');
                            },
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: ChoiceChip(
                            label: Center(child: Text('INVESTMENT')),
                            selected: _selectedPaymentType == 'INVESTMENT',
                            selectedColor: Colors.purpleAccent,
                            onSelected: (val) {
                              if (val) setState(() => _selectedPaymentType = 'INVESTMENT');
                            },
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 16),
                    Text('Amount in BDT', style: TextStyle(color: Colors.grey[300], fontSize: 12, fontWeight: FontWeight.bold)),
                    SizedBox(height: 6),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: 'Enter amount (e.g. 15000)',
                        hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                        prefixText: '৳ ',
                        prefixStyle: TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold),
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.greenAccent, width: 2),
                        ),
                      ),
                    ),

                    SizedBox(height: 16),
                    Text('Supported Payment Methods', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMethodBadge('bKash', Colors.pinkAccent),
                        _buildMethodBadge('Nagad', Colors.orangeAccent),
                        _buildMethodBadge('Rocket', Colors.purpleAccent),
                        _buildMethodBadge('Cards', Colors.blueAccent),
                      ],
                    ),

                    SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleInitiatePayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? CircularProgressIndicator(color: Colors.white)
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.lock, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Pay with SSLCommerz',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Transaction History',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                IconButton(
                  icon: Icon(Icons.refresh, color: Colors.greenAccent),
                  onPressed: _loadPayments,
                ),
              ],
            ),
            SizedBox(height: 10),

            // Payments List
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _payments.length,
              itemBuilder: (context, index) {
                final p = _payments[index];
                final isValidated = p.status == 'VALIDATED';

                return Card(
                  margin: EdgeInsets.only(bottom: 10),
                  color: Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isValidated ? Colors.green.withOpacity(0.2) : Colors.amber.withOpacity(0.2),
                      child: Icon(
                        isValidated ? Icons.check_circle : Icons.hourglass_top,
                        color: isValidated ? Colors.greenAccent : Colors.amberAccent,
                      ),
                    ),
                    title: Text(
                      '৳${p.amount.toStringAsFixed(2)} BDT',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 2),
                        Text('Type: ${p.paymentType} | Tran ID: ${p.tranId}', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                        Text('Method: ${p.cardType ?? "SSLCommerz Gateway"}', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                      ],
                    ),
                    trailing: Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isValidated ? Colors.green.withOpacity(0.15) : Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isValidated ? Colors.greenAccent : Colors.amberAccent,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        p.status,
                        style: TextStyle(
                          color: isValidated ? Colors.greenAccent : Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
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

  Widget _buildMethodBadge(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
