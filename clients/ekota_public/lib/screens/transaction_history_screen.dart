import 'package:flutter/material.dart';
import '../models/wallet_transaction_model.dart';
import '../services/wallet_service.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  bool _isLoading = true;
  List<WalletTransactionModel> _allTransactions = [];
  String _selectedFilter = 'ALL';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      final txs = await WalletService().fetchTransactions(limit: 50);
      if (mounted) {
        setState(() {
          _allTransactions = txs;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<WalletTransactionModel> get _filteredTransactions {
    return _allTransactions.where((tx) {
      final matchesSearch = tx.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          tx.reference.toLowerCase().contains(_searchQuery.toLowerCase());
      if (_selectedFilter == 'ALL') return matchesSearch;
      return matchesSearch && tx.type.toUpperCase() == _selectedFilter;
    }).toList();
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
    final list = _filteredTransactions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['ALL', 'DEPOSIT', 'RENT', 'REFUND'].map((filter) {
                  final selected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: selected,
                      selectedColor: const Color(0xFF6C63FF),
                      labelStyle: TextStyle(color: selected ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                      onSelected: (_) => setState(() => _selectedFilter = filter),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadTransactions,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : list.isEmpty
                      ? const Center(child: Text('No transactions found.'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: list.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final tx = list[index];
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
            ),
          ),
        ],
      ),
    );
  }
}
