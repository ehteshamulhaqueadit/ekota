import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/withdrawal_model.dart';
import '../services/withdrawal_service.dart';
import '../models/chat_message_model.dart';
import '../services/chat_api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'syndicate_chat_screen.dart';

class InvestorWithdrawalScreen extends StatefulWidget {
  const InvestorWithdrawalScreen({super.key});

  @override
  State<InvestorWithdrawalScreen> createState() => _InvestorWithdrawalScreenState();
}

class _InvestorWithdrawalScreenState extends State<InvestorWithdrawalScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Investor Payment State
  final _investAmountController = TextEditingController(text: '50000');
  bool _isInvesting = false;
  String? _investError;
  String? _investSuccess;
  List<dynamic> _investmentHistory = [];

  // Withdrawal Request State
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
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    // Auto-poll both investments and withdrawals every 3 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _tabController.dispose();
    _investAmountController.dispose();
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

      // Fetch investment payments
      final payments = await service.fetchUserPayments(token);

      if (mounted) {
        setState(() {
          if (balData != null) {
            _availableBalance = balData.availableBalance;
          }
          _withdrawals = list;
          _investmentHistory = payments;
        });
      }
    } catch (_) {}
  }

  Future<void> _handleInvestorCheckout() async {
    final amt = double.tryParse(_investAmountController.text.trim());
    if (amt == null || amt <= 0) {
      setState(() => _investError = 'Please enter a valid investment amount');
      return;
    }

    setState(() {
      _isInvesting = true;
      _investError = null;
      _investSuccess = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? 'dev-token';

      final service = WithdrawalService();
      final result = await service.initiatePayment(amount: amt, paymentType: 'INVESTMENT', token: token);

      if (result['success'] == true && result['gatewayPageUrl'] != null) {
        final url = Uri.parse(result['gatewayPageUrl']);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.inAppBrowserView);
        } else {
          await launchUrl(url);
        }

        setState(() {
          _investSuccess = 'Investment session created. Status: PENDING Admin Verification.';
        });
        _loadData();
      } else {
        setState(() => _investError = result['message'] ?? 'Investment initiation failed');
      }
    } catch (e) {
      setState(() => _investError = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isInvesting = false);
    }
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
      setState(() => _withdrawError = 'Insufficient wallet balance for payout request');
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
            Text('Ekota Syndicate', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3)),
            Text('Institutional Split-Buying & Investor Portal', style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.normal)),
          ],
        ),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: AppTheme.textMuted,
          tabs: const [
            Tab(icon: Icon(Icons.show_chart, size: 20), text: 'INVESTMENT'),
            Tab(icon: Icon(Icons.forum, size: 20), text: 'SYNDICATE CHAT'),
            Tab(icon: Icon(Icons.account_balance_wallet, size: 20), text: 'WITHDRAWAL'),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, size: 20), tooltip: 'Refresh Metrics', onPressed: _loadData),
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            tooltip: 'Sign Out',
            onPressed: () {
              _pollingTimer?.cancel();
              AuthService.logout(context);
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Investor Payment & Investment History
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Make Secure Investment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const Text('Invest safely via SSLCommerz gateway to fund projects', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _investAmountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Investment Amount (BDT)',
                            prefixText: '৳ ',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [25000, 50000, 100000, 250000].map((amt) {
                            return ActionChip(
                              label: Text('৳$amt'),
                              onPressed: () => setState(() => _investAmountController.text = amt.toString()),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        if (_investError != null)
                          Container(
                            padding: const EdgeInsets.all(10),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                            child: Text(_investError!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                          ),
                        if (_investSuccess != null)
                          Container(
                            padding: const EdgeInsets.all(10),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                            child: Text(_investSuccess!, style: const TextStyle(color: Colors.green, fontSize: 13)),
                          ),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.lock, color: Colors.white, size: 18),
                            label: _isInvesting
                                ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                : Text('Invest ৳${_investAmountController.text} BDT via SSLCommerz', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                            onPressed: _isInvesting ? null : _handleInvestorCheckout,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Investment History List with Live Badges
                const Text('My Investment Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (_investmentHistory.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                    child: const Text('No investment payments found.', style: TextStyle(color: Colors.grey)),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _investmentHistory.length,
                    itemBuilder: (context, index) {
                      final item = _investmentHistory[index];
                      final st = (item['status'] ?? 'PENDING').toString().toUpperCase();
                      final amt = (item['amount'] is num) ? (item['amount'] as num).toDouble() : double.parse(item['amount'].toString());
                      final tranId = item['tranId'] ?? item['id'] ?? '';
                      final payType = item['paymentType'] ?? 'INVESTMENT';

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

                      final statusText = isValidated
                          ? 'VALIDATED'
                          : isRejected
                              ? 'REJECTED'
                              : 'PENDING';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: badgeBg, child: Icon(iconData, color: badgeColor)),
                          title: Text('৳${amt.toStringAsFixed(2)} BDT', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('$payType • $tranId'),
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

          // Tab 2: Syndicate Real-Time Chat & Discussion Threads
          const SyndicateChatThreadsTab(),

          // Tab 3: Producer Payout Withdrawal & Withdrawal History
          SingleChildScrollView(
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
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A)),
                            onPressed: _isWithdrawing ? null : _handleWithdrawalSubmit,
                            child: _isWithdrawing
                                ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                : const Text('Submit Payout Request to Admin', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Withdrawal History with Live Badges
                const Text('Withdrawal Requests History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (_withdrawals.isEmpty)
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
                    itemCount: _withdrawals.length,
                    itemBuilder: (context, index) {
                      final item = _withdrawals[index];
                      final st = item.status.toUpperCase();
                      final isApproved = st == 'APPROVED';
                      final isRejected = st == 'REJECTED';

                      final badgeColor = isApproved ? Colors.green : isRejected ? Colors.red : Colors.amber.shade800;
                      final badgeBg = isApproved ? Colors.green.shade50 : isRejected ? Colors.red.shade50 : Colors.amber.shade50;
                      final iconData = isApproved ? Icons.check_circle : isRejected ? Icons.cancel : Icons.access_time;

                      final accountNum = item.accountDetails['accountNumber'] ?? item.accountDetails['phone'] ?? '';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: badgeBg, child: Icon(iconData, color: badgeColor)),
                          title: Text('৳${item.amount.toStringAsFixed(2)} BDT', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${item.method} • $accountNum'),
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
        ],
      ),
    );
  }

}

class SyndicateChatThreadsTab extends StatefulWidget {
  const SyndicateChatThreadsTab({super.key});

  @override
  State<SyndicateChatThreadsTab> createState() => _SyndicateChatThreadsTabState();
}

class _SyndicateChatThreadsTabState extends State<SyndicateChatThreadsTab> with AutomaticKeepAliveClientMixin {
  List<SyndicateThreadModel>? _threads;
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchThreads();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchThreads() async {
    final list = await ChatApiService().fetchThreads();
    if (mounted) {
      setState(() {
        _threads = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    final list = await ChatApiService().fetchThreads();
    if (mounted) {
      setState(() {
        _threads = list;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final threads = _threads ?? [];
    if (threads.isEmpty) {
      return const Center(
        child: Text('No active syndicate threads found.'),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        key: const PageStorageKey('syndicate_opportunity_list'),
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: threads.length,
        itemBuilder: (context, index) {
          final thread = threads[index];
          final target = thread.fundingTarget;
          final current = thread.currentFunding;
          final percentage = thread.fundingPercentage;

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          thread.assetName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Text(
                          '$percentage% Funded',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${thread.category} • ${thread.producerName}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (current / target).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '৳${current.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} Raised',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'Target: ৳${target.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} BDT',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.forum, size: 18),
                      label: const Text('Open Syndicate Discussion Chat'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SyndicateChatScreen(thread: thread),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
