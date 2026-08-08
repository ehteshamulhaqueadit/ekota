import 'package:flutter/material.dart';
import '../models/withdrawal_model.dart';
import '../services/withdrawal_service.dart';

class ProducerWithdrawalScreen extends StatefulWidget {
  final String authToken;

  const ProducerWithdrawalScreen({Key? key, required this.authToken}) : super(key: key);

  @override
  _ProducerWithdrawalScreenState createState() => _ProducerWithdrawalScreenState();
}

class _ProducerWithdrawalScreenState extends State<ProducerWithdrawalScreen> {
  final WithdrawalService _service = WithdrawalService();
  double _availableBalance = 342500;
  bool _showSuccessBanner = false;
  String _lastRequestedAmount = '';

  List<Map<String, dynamic>> _history = [
    {
      'amount': '৳142,500',
      'method': 'bKash · 14 Jul 2026',
      'status': 'Pending',
      'statusColor': Colors.orange,
    },
    {
      'amount': '৳98,500',
      'method': 'bKash · 10 Jun 2026',
      'status': 'Paid',
      'statusColor': Colors.blue,
    },
    {
      'amount': '৳75,000',
      'method': 'bKash · 15 May 2026',
      'status': 'Approved',
      'statusColor': Colors.green,
    },
  ];

  void _openWithdrawalModal() {
    final amountController = TextEditingController();
    final accountNumberController = TextEditingController();
    final noteController = TextEditingController();
    String selectedMethod = 'bKash';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 24,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Withdrawal Progress Bar (1 -> 2 -> 3)
                    Text('Withdrawal Progress', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: const [
                        _stepCircle('1', 'Request', true),
                        _stepLine(),
                        _stepCircle('2', 'Admin Review', false),
                        _stepLine(),
                        _stepCircle('3', 'Completed', false),
                      ],
                    ),

                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Withdrawal Request', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),

                    SizedBox(height: 14),
                    Text('Withdrawal Amount', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                    SizedBox(height: 6),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '৳ 0.00',
                        filled: true,
                        fillColor: Color(0xFFF9FAFB),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text('Available: ৳342,500', style: TextStyle(fontSize: 11, color: Colors.grey[500])),

                    SizedBox(height: 14),
                    Text('Withdrawal Method', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                    SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedMethod,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Color(0xFFF9FAFB),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: ['bKash', 'Nagad', 'Rocket', 'Bank Transfer']
                          .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                      onChanged: (val) => setModalState(() => selectedMethod = val!),
                    ),

                    SizedBox(height: 14),
                    Text('Account Number', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                    SizedBox(height: 6),
                    TextField(
                      controller: accountNumberController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: 'Mobile number',
                        filled: true,
                        fillColor: Color(0xFFF9FAFB),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),

                    SizedBox(height: 14),
                    Text('Optional Note', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                    SizedBox(height: 6),
                    TextField(
                      controller: noteController,
                      decoration: InputDecoration(
                        hintText: 'Any additional details...',
                        filled: true,
                        fillColor: Color(0xFFF9FAFB),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),

                    SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF047857),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          final reqAmt = amountController.text.trim();
                          Navigator.pop(context);
                          setState(() {
                            _lastRequestedAmount = reqAmt.isNotEmpty ? '৳$reqAmt' : '৳142,500';
                            _history.insert(0, {
                              'amount': _lastRequestedAmount,
                              'method': '$selectedMethod · Today',
                              'status': 'Pending',
                              'statusColor': Colors.orange,
                            });
                            _showSuccessBanner = true;
                          });
                        },
                        child: Text('CONFIRM', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF052E21),
      appBar: AppBar(
        backgroundColor: Color(0xFF052E21),
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: const [
            Text('Renter/Investor', style: TextStyle(color: Colors.white70, fontSize: 13)),
            Text('Producer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            Text('Admin', style: TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Good morning,', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text('Nilufar Rashidova', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 16),

                  // Available Balance Card (Figma page 4)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Color(0xFF0B4A34),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AVAILABLE BALANCE', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('৳342,500', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Row(
                          children: const [
                            Icon(Icons.access_time, size: 12, color: Colors.white60),
                            SizedBox(width: 4),
                            Text('Last updated: Today, 09:00 AM', style: TextStyle(color: Colors.white60, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16),

                  // Request Withdrawal Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _openWithdrawalModal,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF047857),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Withdrawal Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),

            if (_showSuccessBanner)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                color: Color(0xFF047857),
                child: Column(
                  children: const [
                    Text('Congratulation!', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Withdrawal Sucessfull', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  ],
                ),
              ),

            // History Container
            Container(
              margin: EdgeInsets.only(top: 16),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Withdrawal History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                  SizedBox(height: 16),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final item = _history[index];
                      return Container(
                        margin: EdgeInsets.only(bottom: 12),
                        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Color(0xFFECFDF5),
                                  child: Icon(Icons.arrow_downward, color: Color(0xFF047857), size: 18),
                                ),
                                SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['amount'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                                    Text(item['method'], style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (item['statusColor'] as Color).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                item['status'],
                                style: TextStyle(color: item['statusColor'], fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 3,
        selectedItemColor: Color(0xFF047857),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Projects'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
          BottomNavigationBarItem(icon: Icon(Icons.monetization_on), label: 'Payouts'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _stepCircle extends StatelessWidget {
  final String num;
  final String label;
  final bool active;
  const _stepCircle(this.num, this.label, this.active);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: active ? Color(0xFF047857) : Colors.grey[300],
          child: Text(num, style: TextStyle(color: active ? Colors.white : Colors.black87, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: active ? Color(0xFF047857) : Colors.grey[600])),
      ],
    );
  }
}

class _stepLine extends StatelessWidget {
  const _stepLine();
  @override
  Widget build(BuildContext context) {
    return Container(width: 30, height: 1, color: Colors.grey[300]);
  }
}
