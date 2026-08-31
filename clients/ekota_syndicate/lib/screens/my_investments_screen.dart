import 'package:flutter/material.dart';
import '../services/investment_service.dart';
import 'investment_detail_screen.dart';

class MyInvestmentsScreen extends StatefulWidget {
  const MyInvestmentsScreen({super.key});

  @override
  State<MyInvestmentsScreen> createState() => _MyInvestmentsScreenState();
}

class _MyInvestmentsScreenState extends State<MyInvestmentsScreen> {
  List<Map<String, dynamic>> _investments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvestments();
  }

  Future<void> _loadInvestments() async {
    setState(() => _isLoading = true);
    try {
      final investments = await InvestmentService.getMyInvestments();
      if (!mounted) return;
      setState(() { _investments = investments; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadInvestments,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _investments.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 200),
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No investments yet', style: TextStyle(fontSize: 16, color: Colors.grey)),
                          SizedBox(height: 8),
                          Text('Browse the marketplace to start investing',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _investments.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      // Portfolio summary
                      final totalInvested = _investments.fold<double>(
                        0, (sum, inv) => sum + (inv['amount'] as num).toDouble(),
                      );
                      return Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        color: const Color(0xFF1A1A2E),
                        margin: const EdgeInsets.only(bottom: 20),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              const Text('Total Portfolio Value',
                                  style: TextStyle(color: Colors.white70, fontSize: 14)),
                              const SizedBox(height: 8),
                              Text('৳${totalInvested.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text('${_investments.length} active investments',
                                  style: const TextStyle(color: Color(0xFF00D2FF))),
                            ],
                          ),
                        ),
                      );
                    }

                    final inv = _investments[index - 1];
                    final listing = inv['listing'] ?? {};
                    final fundingPct = (inv['fundingPercentage'] ?? 0).toDouble();
                    final imageUrls = List<String>.from(listing['imageUrls'] ?? []);

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => InvestmentDetailScreen(
                                listingId: listing['id'] ?? '',
                                investmentData: inv,
                              ),
                            ),
                          );
                          _loadInvestments();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // Thumbnail
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: imageUrls.isNotEmpty
                                    ? Image.network(imageUrls.first,
                                        width: 60, height: 60, fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            Container(width: 60, height: 60, color: Colors.grey[200],
                                                child: const Icon(Icons.image, color: Colors.grey)))
                                    : Container(width: 60, height: 60, color: Colors.grey[200],
                                        child: const Icon(Icons.inventory_2, color: Colors.grey)),
                              ),
                              const SizedBox(width: 16),
                              // Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(listing['assetName'] ?? 'Unknown',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text('Invested: ৳${(inv['amount'] ?? 0).toStringAsFixed(0)}',
                                        style: TextStyle(color: Colors.grey[600])),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: (fundingPct / 100).clamp(0.0, 1.0),
                                        backgroundColor: Colors.grey[200],
                                        color: fundingPct >= 100 ? Colors.green : const Color(0xFF00D2FF),
                                        minHeight: 6,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Share percentage
                              Column(
                                children: [
                                  Text('${(inv['sharePercentage'] ?? 0).toStringAsFixed(1)}%',
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                                          color: Color(0xFF00D2FF))),
                                  const Text('share', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
