import 'package:flutter/material.dart';
import '../models/wallet_transaction_model.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  bool _isLoading = true;
  List<WalletTransactionModel> _transactions = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final list = await WalletService().fetchTransactions();
      if (mounted) {
        setState(() {
          _transactions = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        backgroundColor: AppTheme.primary,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchTransactions,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                : _transactions.isEmpty
                    ? const Center(child: Text('No transaction history found.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _transactions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = _transactions[index];
                          final isCredit = item.type == 'DEPOSIT' || item.type == 'REFUND' || item.type == 'WITHDRAWAL_REVERSAL';
                          final isVal = item.status.toUpperCase().contains('VALIDATED') || item.status.toUpperCase().contains('COMPLETED');
                          final isRej = item.status.toUpperCase().contains('REJECTED') || item.status.toUpperCase().contains('FAILED');
                          final isProc = item.status.toUpperCase().contains('PROCESSING');

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
                              onTap: () => _showTransactionDetails(context, item),
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
                                            item.description.isNotEmpty ? item.description : item.title,
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (item.statusSubtitle.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              item.statusSubtitle,
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
                                            item.createdAt.toString().split('.')[0],
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
                                          '${isCredit ? "+" : "-"}৳${item.amount.toStringAsFixed(2)}',
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
                        },
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
