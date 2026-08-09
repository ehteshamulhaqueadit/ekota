import 'package:flutter/material.dart';
import '../models/withdrawal_model.dart';
import '../services/withdrawal_service.dart';
import '../theme/app_theme.dart';

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
  String? _validationError;

  final ProducerBalanceModel _defaultBalance = ProducerBalanceModel(
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
    if (mounted) {
      setState(() {
        _balance = b ?? _defaultBalance;
        if (r.isNotEmpty) _requests = r;
      });
    }
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
    String? modalError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final avail = _balance?.availableBalance ?? 342500;

            return Padding(
              padding: EdgeInsets.only(
                top: AppSpacing.xl,
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(color: AppColors.cardBorder, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    SizedBox(height: AppSpacing.md),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Withdraw Funds', style: AppTextStyles.h2),
                        IconButton(
                          icon: Icon(Icons.close, color: AppColors.textMuted),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),

                    SizedBox(height: AppSpacing.md),
                    Text('SELECT PAYOUT METHOD', style: AppTextStyles.bodySecondary.copyWith(fontWeight: FontWeight.bold)),
                    SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        _buildChip('BANK_TRANSFER', 'Bank Transfer', selectedMethod, (val) => setModalState(() => selectedMethod = val)),
                        _buildChip('BKASH', 'bKash Wallet', selectedMethod, (val) => setModalState(() => selectedMethod = val)),
                        _buildChip('NAGAD', 'Nagad Wallet', selectedMethod, (val) => setModalState(() => selectedMethod = val)),
                        _buildChip('ROCKET', 'Rocket Wallet', selectedMethod, (val) => setModalState(() => selectedMethod = val)),
                      ],
                    ),

                    SizedBox(height: AppSpacing.lg),
                    Text('REQUESTED AMOUNT', style: AppTextStyles.bodySecondary.copyWith(fontWeight: FontWeight.bold)),
                    SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      onChanged: (val) {
                        final req = double.tryParse(val.trim()) ?? 0;
                        if (req > avail) {
                          setModalState(() {
                            modalError = 'Insufficient balance! Available: ৳${avail.toStringAsFixed(2)}';
                          });
                        } else {
                          setModalState(() => modalError = null);
                        }
                      },
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: 'Enter amount (e.g. 10000)',
                        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
                        prefixText: '৳ ',
                        prefixStyle: TextStyle(color: AppColors.warning, fontSize: 18, fontWeight: FontWeight.bold),
                        filled: true,
                        fillColor: AppColors.cardBackground,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text('Available for payout: ৳${avail.toStringAsFixed(2)} BDT', style: TextStyle(color: AppColors.success, fontSize: 11)),

                    if (modalError != null) ...[
                      SizedBox(height: 6),
                      Text(modalError!, style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],

                    SizedBox(height: AppSpacing.lg),
                    Text('ACCOUNT DETAILS', style: AppTextStyles.bodySecondary.copyWith(fontWeight: FontWeight.bold)),
                    SizedBox(height: AppSpacing.sm),

                    if (selectedMethod == 'BANK_TRANSFER') ...[
                      _buildInput(bankNameController, 'Bank Name (e.g. Brac Bank, Dutch-Bangla)'),
                      SizedBox(height: AppSpacing.sm),
                      _buildInput(accountHolderController, 'Account Holder Name'),
                      SizedBox(height: AppSpacing.sm),
                      _buildInput(accountNumberController, 'Account Number'),
                      SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(child: _buildInput(branchController, 'Branch Name')),
                          SizedBox(width: AppSpacing.sm),
                          Expanded(child: _buildInput(routingController, 'Routing No.')),
                        ],
                      ),
                    ] else ...[
                      _buildInput(mobileNumberController, '$selectedMethod Mobile Wallet Number', icon: Icons.phone_android),
                    ],

                    SizedBox(height: AppSpacing.xl),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: modalError != null ? AppColors.textMuted : AppColors.primaryAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: modalError != null
                            ? null
                            : () async {
                                final amount = double.tryParse(amountController.text.trim());
                                if (amount == null || amount <= 0) {
                                  setModalState(() => modalError = 'Please enter a valid positive amount.');
                                  return;
                                }

                                if (amount > avail) {
                                  setModalState(() => modalError = 'Insufficient available balance!');
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
                                    backgroundColor: result['success'] == true ? AppColors.success : AppColors.error,
                                  ),
                                );

                                _loadData();
                              },
                        child: Text('Submit Withdrawal Request', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
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

  Widget _buildChip(String code, String label, String selected, Function(String) onSelect) {
    final isSelected = selected == code;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
      selected: isSelected,
      selectedColor: AppColors.primaryAccent,
      onSelected: (val) {
        if (val) onSelect(code);
      },
    );
  }

  Widget _buildInput(TextEditingController ctrl, String hint, {IconData? icon}) {
    return TextField(
      controller: ctrl,
      style: TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 11),
        prefixIcon: icon != null ? Icon(icon, color: AppColors.primaryAccent, size: 18) : null,
        filled: true,
        fillColor: AppColors.cardBackground,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bal = _balance ?? _defaultBalance;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        title: Text('Producer Wallet', style: AppTextStyles.h2),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.primaryAccent),
            onPressed: _loadData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primaryAccent,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Available Balance Dashboard Card
              Container(
                width: double.infinity,
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('AVAILABLE FOR PAYOUT', style: AppTextStyles.bodySecondary.copyWith(fontWeight: FontWeight.bold)),
                        Icon(Icons.account_balance_wallet_outlined, color: AppColors.warning, size: 20),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text('৳${bal.availableBalance.toStringAsFixed(2)} BDT', style: AppTextStyles.amountLarge.copyWith(color: AppColors.warning)),
                    SizedBox(height: AppSpacing.md),
                    Divider(color: AppColors.cardBorder, height: 1),
                    SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStat('Total Earnings', '৳${bal.totalEarnings.toStringAsFixed(0)}'),
                        _buildStat('Pending', '৳${bal.pendingWithdrawal.toStringAsFixed(0)}'),
                        _buildStat('Withdrawn', '৳${bal.totalWithdrawn.toStringAsFixed(0)}'),
                      ],
                    ),
                    SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.arrow_upward, color: Colors.white, size: 18),
                        label: Text('Request Payout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _showWithdrawalModal,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: AppSpacing.xxl),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Withdrawal History', style: AppTextStyles.h2),
                  IconButton(
                    icon: Icon(Icons.refresh, color: AppColors.primaryAccent, size: 20),
                    onPressed: _loadData,
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.sm),

              // Withdrawal Requests List
              if (_requests.isEmpty)
                Container(
                  padding: EdgeInsets.all(AppSpacing.xxl),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: const [
                      Icon(Icons.history_outlined, color: AppColors.textMuted, size: 40),
                      SizedBox(height: 8),
                      Text('No withdrawal requests yet', style: AppTextStyles.h3),
                      Text('Your submitted requests will appear here.', style: AppTextStyles.bodySecondary),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: _requests.length,
                  itemBuilder: (context, index) {
                    final req = _requests[index];
                    final isApproved = req.status == 'APPROVED' || req.status == 'PROCESSED';
                    final isPending = req.status == 'PENDING';

                    final statusColor = isApproved ? AppColors.success : (isPending ? AppColors.warning : AppColors.error);
                    final statusBg = isApproved ? AppColors.successBg : (isPending ? AppColors.warningBg : AppColors.errorBg);

                    return Card(
                      margin: EdgeInsets.only(bottom: AppSpacing.md),
                      color: AppColors.cardBackground,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.cardBorder)),
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('৳${req.amount.toStringAsFixed(2)} BDT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusBg,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: statusColor),
                                  ),
                                  child: Text(req.status, style: AppTextStyles.badgeText.copyWith(color: statusColor)),
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            Text('Method: ${req.method}', style: AppTextStyles.bodySecondary),
                            if (req.transactionRef != null) ...[
                              SizedBox(height: 2),
                              Text('Ref ID: ${req.transactionRef}', style: TextStyle(color: AppColors.primaryAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                            if (req.adminNote != null) ...[
                              SizedBox(height: 2),
                              Text('Admin Note: ${req.adminNote}', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontStyle: FontStyle.italic)),
                            ],
                            SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(req.createdAt.split('T')[0], style: AppTextStyles.bodySecondary),
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
      ),
    );
  }

  Widget _buildStat(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.bodySecondary),
        SizedBox(height: 2),
        Text(val, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
