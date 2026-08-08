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
  ProducerBalanceModel? _balance;
  List<WithdrawalRequestModel> _requests = [];
  bool _isLoading = false;

  final ProducerBalanceModel _fallbackBalance = ProducerBalanceModel(
    totalEarnings: 485000.0,
    availableBalance: 342500.0,
    pendingWithdrawal: 142500.0,
    totalWithdrawn: 0.0,
  );

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final b = await _service.fetchBalance(widget.authToken);
    final r = await _service.fetchMyRequests(widget.authToken);
    setState(() {
      _balance = b ?? _fallbackBalance;
      if (r.isNotEmpty) _requests = r;
    });
  }

  void _showWithdrawalModal() {
    final amountController = TextEditingController();
    final bankNameController = TextEditingController();
    final accountHolderController = TextEditingController();
    final accountNumberController = TextEditingController();
    final branchController = TextEditingController();
    final routingController = TextEditingController();
    final mobileNumberController = TextEditingController();
    String selectedMethod = 'BANK_TRANSFER';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Color(0xFF1E293B),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Request Payout from Admin',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text('Select Payout Method', style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['BANK_TRANSFER', 'BKASH', 'NAGAD', 'ROCKET'].map((m) {
                        final isSelected = selectedMethod == m;
                        final label = m == 'BANK_TRANSFER' ? 'Bank Transfer' : m;
                        return ChoiceChip(
                          label: Text(label),
                          selected: isSelected,
                          selectedColor: Colors.amber[700],
                          onSelected: (val) {
                            if (val) setModalState(() => selectedMethod = m);
                          },
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 16),

                    Text('Withdrawal Amount (BDT)', style: TextStyle(color: Colors.grey[300], fontSize: 12, fontWeight: FontWeight.bold)),
                    SizedBox(height: 6),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: 'Enter amount to withdraw',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        prefixText: '৳ ',
                        prefixStyle: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Available for payout: ৳${(_balance?.availableBalance ?? 342500).toStringAsFixed(2)} BDT',
                      style: TextStyle(color: Colors.greenAccent, fontSize: 11),
                    ),

                    SizedBox(height: 14),
                    if (selectedMethod == 'BANK_TRANSFER') ...[
                      TextField(
                        controller: bankNameController,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Bank Name (e.g. Dutch-Bangla Bank, Brac Bank)',
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          filled: true,
                          fillColor: Colors.black26,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      SizedBox(height: 10),
                      TextField(
                        controller: accountHolderController,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Account Holder Name',
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          filled: true,
                          fillColor: Colors.black26,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      SizedBox(height: 10),
                      TextField(
                        controller: accountNumberController,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Account Number',
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          filled: true,
                          fillColor: Colors.black26,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: branchController,
                              style: TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Branch Name',
                                labelStyle: TextStyle(color: Colors.grey[400]),
                                filled: true,
                                fillColor: Colors.black26,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: routingController,
                              style: TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Routing Number',
                                labelStyle: TextStyle(color: Colors.grey[400]),
                                filled: true,
                                fillColor: Colors.black26,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      TextField(
                        controller: mobileNumberController,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: '$selectedMethod Mobile Wallet Number',
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: Icon(Icons.phone_android, color: Colors.amber),
                          filled: true,
                          fillColor: Colors.black26,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],

                    SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber[600],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final amount = double.tryParse(amountController.text.trim());
                          if (amount == null || amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Please enter a valid withdrawal amount')),
                            );
                            return;
                          }

                          Map<String, dynamic> accountDetails = {};
                          if (selectedMethod == 'BANK_TRANSFER') {
                            accountDetails = {
                              'bankName': bankNameController.text.trim(),
                              'accountName': accountHolderController.text.trim(),
                              'accountNumber': accountNumberController.text.trim(),
                              'branchName': branchController.text.trim(),
                              'routingNumber': routingController.text.trim(),
                            };
                          } else {
                            accountDetails = {
                              'mobileNumber': mobileNumberController.text.trim(),
                            };
                          }

                          Navigator.pop(context);
                          setState(() => _isLoading = true);

                          final result = await _service.submitWithdrawal(
                            amount: amount,
                            method: selectedMethod,
                            accountDetails: accountDetails,
                            token: widget.authToken,
                          );

                          setState(() => _isLoading = false);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(result['message'] ?? 'Done'),
                              backgroundColor: result['success'] == true ? Colors.green : Colors.redAccent,
                            ),
                          );

                          _loadData();
                        },
                        child: Text(
                          'Submit Request to Admin',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
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
    final bal = _balance ?? _fallbackBalance;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Producer Balance Card
            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              color: Color(0xFF1E293B),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Available Balance', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                        Icon(Icons.account_balance_wallet, color: Colors.amberAccent),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      '৳${bal.availableBalance.toStringAsFixed(2)} BDT',
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                    ),
                    SizedBox(height: 16),
                    Divider(color: Colors.white12),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatItem('Total Earnings', '৳${bal.totalEarnings.toStringAsFixed(0)}'),
                        _buildStatItem('Pending Payout', '৳${bal.pendingWithdrawal.toStringAsFixed(0)}'),
                        _buildStatItem('Total Withdrawn', '৳${bal.totalWithdrawn.toStringAsFixed(0)}'),
                      ],
                    ),
                    SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.arrow_circle_up_outlined, color: Colors.black),
                        label: Text(
                          'Request Payout to Admin',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _showWithdrawalModal,
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
                  'Withdrawal Requests History',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                IconButton(
                  icon: Icon(Icons.refresh, color: Colors.greenAccent),
                  onPressed: _loadData,
                ),
              ],
            ),
            SizedBox(height: 12),

            // Requests List
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _requests.length,
              itemBuilder: (context, index) {
                final req = _requests[index];
                final isPending = req.status == 'PENDING';
                final isApproved = req.status == 'APPROVED' || req.status == 'PROCESSED';

                return Card(
                  margin: EdgeInsets.only(bottom: 12),
                  color: Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '৳${req.amount.toStringAsFixed(2)} BDT',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isApproved
                                    ? Colors.green.withOpacity(0.15)
                                    : isPending
                                        ? Colors.amber.withOpacity(0.15)
                                        : Colors.red.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isApproved
                                      ? Colors.greenAccent
                                      : isPending
                                          ? Colors.amberAccent
                                          : Colors.redAccent,
                                ),
                              ),
                              child: Text(
                                req.status,
                                style: TextStyle(
                                  color: isApproved
                                      ? Colors.greenAccent
                                      : isPending
                                          ? Colors.amberAccent
                                          : Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Method: ${req.method}',
                          style: TextStyle(color: Colors.grey[300], fontSize: 13),
                        ),
                        if (req.transactionRef != null) ...[
                          SizedBox(height: 4),
                          Text(
                            'Ref / Proof ID: ${req.transactionRef}',
                            style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                        if (req.adminNote != null) ...[
                          SizedBox(height: 4),
                          Text(
                            'Admin Note: ${req.adminNote}',
                            style: TextStyle(color: Colors.grey[400], fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        ],
                        SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            req.createdAt.split('T')[0],
                            style: TextStyle(color: Colors.grey[500], fontSize: 11),
                          ),
                        ),
                      ],
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

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 11)),
        SizedBox(height: 2),
        Text(value, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}
