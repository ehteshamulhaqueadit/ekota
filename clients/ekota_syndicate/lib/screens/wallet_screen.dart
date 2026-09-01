import 'package:flutter/material.dart';
import '../models/wallet_model.dart';
import '../models/wallet_transaction_model.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';
import 'add_money_screen.dart';
import 'investor_withdrawal_screen.dart';
import 'transaction_history_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _isLoading = true;
  WalletModel? _wallet;
  List<WalletTransactionModel> _recentTransactions = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  Future<void> _loadWalletData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final wallet = await WalletService().fetchWallet();
      final txs = await WalletService().fetchTransactions(limit: 5);
      if (mounted) {
        setState(() {
          _wallet = wallet;
          _recentTransactions = txs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load wallet data: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Ekota Wallet'),
        backgroundColor: AppTheme.primary,
      ),
      body: RefreshIndicator(
        onRefresh: _loadWalletData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Wallet Balance Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Available Balance',
                          style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _wallet?.status ?? 'ACTIVE',
                            style: const TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '৳${_wallet?.balance.toStringAsFixed(2) ?? "0.00"}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const AddMoneyScreen()),
                              ).then((_) => _loadWalletData());
                            },
                            icon: const Icon(Icons.add_circle_outline, size: 18),
                            label: const Text('Add Money'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const InvestorWithdrawalScreen()),
                              ).then((_) => _loadWalletData());
                            },
                            icon: const Icon(Icons.outbox, size: 18, color: Colors.white),
                            label: const Text('Withdraw', style: TextStyle(color: Colors.white)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white38),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Recent Transactions Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Activity',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TransactionHistoryScreen()),
                      );
                    },
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_isLoading)
                const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
              else if (_recentTransactions.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: const Center(
                    child: Text('No transaction activity recorded yet.', style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                Column(
                  children: [
                    ..._recentTransactions.take(5).map((tx) {
                      final isCredit = tx.type == 'DEPOSIT' || tx.type == 'REFUND' || tx.type == 'WITHDRAWAL_REVERSAL';
                      final isVal = tx.status.toUpperCase().contains('VALIDATED') || tx.status.toUpperCase().contains('COMPLETED');
                      final isRej = tx.status.toUpperCase().contains('REJECTED') || tx.status.toUpperCase().contains('FAILED');
                      final isProc = tx.status.toUpperCase().contains('PROCESSING');

                      String statusText = 'Pending';
                      Color bg = const Color(0xFFFEF3C7);
                      Color fg = const Color(0xFFB45309);
                      Color cardBg = const Color(0xFFFFFBEB); // Soft Amber background tint for Pending
                      Color cardBorder = const Color(0xFFFCD34D); // Amber border
                      IconData statusIcon = Icons.hourglass_top_rounded;

                      if (isVal) {
                        statusText = 'Completed';
                        bg = const Color(0xFFD1FAE5);
                        fg = const Color(0xFF047857);
                        statusIcon = Icons.check_circle_rounded;
                        cardBg = Colors.white;
                        cardBorder = Colors.transparent;
                      } else if (isRej) {
                        statusText = 'Rejected';
                        bg = const Color(0xFFFEE2E2);
                        fg = const Color(0xFFB91C1C);
                        statusIcon = Icons.cancel_rounded;
                        cardBg = const Color(0xFFFFF5F5); // Soft Red background tint for Rejected
                        cardBorder = const Color(0xFFFCA5A5); // Red border
                      } else if (isProc) {
                        statusText = 'Processing';
                        bg = const Color(0xFFDBEAFE);
                        fg = const Color(0xFF1D4ED8);
                        statusIcon = Icons.sync_rounded;
                        cardBg = const Color(0xFFF0F7FF); // Soft Blue background tint for Processing
                        cardBorder = const Color(0xFF93C5FD); // Blue border
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: isVal ? 1.5 : 2.0,
                        color: cardBg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: cardBorder != Colors.transparent
                              ? BorderSide(color: cardBorder, width: 1.2)
                              : BorderSide.none,
                        ),
                        child: InkWell(
                          onTap: () => _showTransactionDetails(context, tx),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: isVal ? AppTheme.successBg : isRej ? AppTheme.dangerBg : const Color(0xFFFEF3C7),
                                  child: Icon(
                                    isVal
                                        ? (isCredit ? Icons.arrow_downward : Icons.arrow_upward)
                                        : isRej
                                            ? Icons.close
                                            : Icons.access_time_filled,
                                    color: isVal ? AppTheme.successText : isRej ? AppTheme.dangerText : const Color(0xFFB45309),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tx.description.isNotEmpty ? tx.description : tx.title,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (tx.statusSubtitle.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          tx.statusSubtitle,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isRej ? const Color(0xFF991B1B) : (isVal ? Colors.black87 : const Color(0xFF92400E)),
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      const SizedBox(height: 2),
                                      Text(
                                        tx.createdAt.toString().split('.')[0],
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${isCredit ? "+" : "-"}৳${tx.amount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: isVal
                                            ? (isCredit ? AppTheme.successText : AppTheme.dangerText)
                                            : isRej
                                                ? Colors.grey.shade500
                                                : const Color(0xFFB45309),
                                        decoration: isRej ? TextDecoration.lineThrough : TextDecoration.none,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: bg,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(statusIcon, size: 10, color: fg),
                                          const SizedBox(width: 3),
                                          Text(
                                            statusText,
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const TransactionHistoryScreen()),
                          );
                        },
                        icon: const Icon(Icons.list_alt, size: 16),
                        label: const Text('View All Transactions'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTransactionDetails(BuildContext context, WalletTransactionModel tx) {
    final isCredit = tx.type == 'DEPOSIT' || tx.type == 'REFUND' || tx.type == 'WITHDRAWAL_REVERSAL';
    final isVal = tx.status.toUpperCase().contains('VALIDATED') || tx.status.toUpperCase().contains('COMPLETED');
    final isRej = tx.status.toUpperCase().contains('REJECTED') || tx.status.toUpperCase().contains('FAILED');
    final isProc = tx.status.toUpperCase().contains('PROCESSING');

    String statusText = 'Pending';
    Color bg = const Color(0xFFFEF3C7);
    Color fg = const Color(0xFFB45309);
    IconData statusIcon = Icons.hourglass_top_rounded;

    if (isVal) {
      statusText = 'Completed';
      bg = const Color(0xFFD1FAE5);
      fg = const Color(0xFF047857);
      statusIcon = Icons.check_circle_rounded;
    } else if (isRej) {
      statusText = 'Rejected';
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
      statusIcon = Icons.cancel_rounded;
    } else if (isProc) {
      statusText = 'Processing';
      bg = const Color(0xFFDBEAFE);
      fg = const Color(0xFF1D4ED8);
      statusIcon = Icons.sync_rounded;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Transaction Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                '${isCredit ? "+" : "-"}৳${tx.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: isVal ? (isCredit ? AppTheme.successText : AppTheme.dangerText) : isRej ? Colors.grey : const Color(0xFFB45309),
                  decoration: isRej ? TextDecoration.lineThrough : TextDecoration.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: fg),
                    const SizedBox(width: 4),
                    Text(statusText, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: fg)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            _detailRow('Transaction Type', tx.title.isNotEmpty ? tx.title : tx.type),
            _detailRow('Description', tx.description),
            if (tx.statusSubtitle.isNotEmpty) _detailRow('Status Note', tx.statusSubtitle),
            _detailRow('Transaction ID', tx.reference.isNotEmpty ? tx.reference : tx.id),
            _detailRow('Date & Time', tx.createdAt.toString().split('.')[0]),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
