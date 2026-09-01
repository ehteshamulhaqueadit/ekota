import 'package:flutter/material.dart';
import '../models/wallet_model.dart';
import '../models/wallet_transaction_model.dart';
import '../services/wallet_service.dart';
import 'add_money_screen.dart';
import 'withdrawal_screen.dart';
import 'my_rentals_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  Future<void> _loadWalletData() async {
    setState(() { _isLoading = true; });
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
          _isLoading = false;
        });
      }
    }
  }

  void _showTransactionDetails(WalletTransactionModel tx) {
    final st = tx.status.toUpperCase();
    final isPending = st == 'PENDING';
    final isRejected = st == 'REJECTED' || st == 'FAILED';
    final isProcessing = st == 'PROCESSING';

    final badgeColor = isPending
        ? Colors.amber.shade900
        : isRejected
            ? Colors.red.shade800
            : isProcessing
                ? Colors.blue.shade800
                : Colors.green.shade800;

    final badgeBg = isPending
        ? const Color(0xFFFEF3C7)
        : isRejected
            ? const Color(0xFFFEE2E2)
            : isProcessing
                ? const Color(0xFFDBEAFE)
                : const Color(0xFFD1FAE5);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    tx.title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      st,
                      style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Text(
                '৳${tx.amount.toStringAsFixed(2)} BDT',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isRejected ? Colors.red : (tx.amount >= 0 ? Colors.green : Colors.black),
                ),
              ),
              const Divider(height: 32),

              _detailRow('Status Detail', tx.statusSubtitle.isNotEmpty ? tx.statusSubtitle : st),
              _detailRow('Transaction Type', tx.type),
              _detailRow('Reference ID', tx.reference.isNotEmpty ? tx.reference : tx.id),
              _detailRow('Date & Time', tx.createdAt.toString().split('.')[0]),
              if (tx.description.isNotEmpty) _detailRow('Note', tx.description),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    colors: [Color(0xFF6C63FF), Color(0xFF4A40E0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C63FF).withOpacity(0.3),
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
                          'Available Rental Balance',
                          style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _wallet?.status ?? 'ACTIVE',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
                            icon: const Icon(Icons.add_circle_outline, size: 18, color: Color(0xFF6C63FF)),
                            label: const Text('Add Money', style: TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const PublicWithdrawalScreen()),
                              ).then((_) => _loadWalletData());
                            },
                            icon: const Icon(Icons.outbox, size: 18, color: Colors.white),
                            label: const Text('Withdraw', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white70),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TransactionHistoryScreen()),
                      );
                    },
                    child: const Text('View All', style: TextStyle(color: Color(0xFF6C63FF))),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_isLoading)
                const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
              else if (_recentTransactions.isEmpty)
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No recent transactions.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentTransactions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final tx = _recentTransactions[index];
                    final st = tx.status.toUpperCase();
                    final isPending = st == 'PENDING';
                    final isRejected = st == 'REJECTED' || st == 'FAILED';
                    final isProcessing = st == 'PROCESSING';

                    final cardBg = isPending
                        ? const Color(0xFFFFFBEB)
                        : isRejected
                            ? const Color(0xFFFFF5F5)
                            : isProcessing
                                ? const Color(0xFFF0F7FF)
                                : Colors.white;

                    final borderColor = isPending
                        ? const Color(0xFFFCD34D)
                        : isRejected
                            ? const Color(0xFFFCA5A5)
                            : isProcessing
                                ? const Color(0xFF93C5FD)
                                : Colors.grey.shade200;

                    final badgeBg = isPending
                        ? const Color(0xFFFEF3C7)
                        : isRejected
                            ? const Color(0xFFFEE2E2)
                            : isProcessing
                                ? const Color(0xFFDBEAFE)
                                : const Color(0xFFD1FAE5);

                    final badgeColor = isPending
                        ? Colors.amber.shade900
                        : isRejected
                            ? Colors.red.shade800
                            : isProcessing
                                ? Colors.blue.shade800
                                : Colors.green.shade800;

                    final iconData = isPending
                        ? Icons.access_time_filled
                        : isRejected
                            ? Icons.close
                            : isProcessing
                                ? Icons.sync_rounded
                                : (tx.amount >= 0 ? Icons.arrow_downward : Icons.arrow_upward);

                    return Card(
                      color: cardBg,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: borderColor, width: 1),
                      ),
                      child: ListTile(
                        onTap: () => _showTransactionDetails(tx),
                        leading: CircleAvatar(
                          backgroundColor: badgeBg,
                          child: Icon(iconData, color: badgeColor, size: 20),
                        ),
                        title: Text(
                          tx.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: isRejected ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(4)),
                              child: Text(
                                st,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
                              ),
                            ),
                            if (tx.statusSubtitle.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(tx.statusSubtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                            const SizedBox(height: 2),
                            Text(tx.createdAt.toString().split('.')[0], style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                        trailing: Text(
                          '${tx.amount >= 0 ? "+" : ""}৳${tx.amount.abs().toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isRejected
                                ? Colors.red
                                : (tx.amount >= 0 ? Colors.green : Colors.black),
                            decoration: isRejected ? TextDecoration.lineThrough : null,
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
}
