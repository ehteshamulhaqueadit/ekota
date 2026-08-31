import 'package:flutter/material.dart';
import '../services/investment_service.dart';

class InvestScreen extends StatefulWidget {
  final Map<String, dynamic> listing;
  const InvestScreen({super.key, required this.listing});

  @override
  State<InvestScreen> createState() => _InvestScreenState();
}

class _InvestScreenState extends State<InvestScreen> {
  final _amountController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;
  String? _success;
  Map<String, dynamic>? _investorsData;
  bool _loadingInvestors = true;

  @override
  void initState() {
    super.initState();
    _loadInvestors();
  }

  Future<void> _loadInvestors() async {
    try {
      final data = await InvestmentService.getListingInvestors(widget.listing['id']);
      if (!mounted) return;
      setState(() { _investorsData = data; _loadingInvestors = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingInvestors = false);
    }
  }

  Future<void> _invest() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Please enter a valid amount');
      return;
    }

    setState(() { _isSubmitting = true; _error = null; _success = null; });

    try {
      final result = await InvestmentService.invest(
        listingId: widget.listing['id'],
        amount: amount,
      );
      if (!mounted) return;

      if (result['investment'] != null) {
        setState(() {
          _success = 'Investment successful! Share: ${result['investment']['sharePercentage']?.toStringAsFixed(1)}%';
          _amountController.clear();
        });
        _loadInvestors();
      } else {
        setState(() => _error = result['error'] ?? 'Investment failed');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Network error: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    final fundingPct = (listing['fundingPercentage'] ?? 0).toDouble();
    final remaining = (listing['fundingTarget'] ?? 0) - (listing['currentFunded'] ?? 0);
    final imageUrls = List<String>.from(listing['imageUrls'] ?? []);

    return Scaffold(
      appBar: AppBar(
        title: Text(listing['assetName'] ?? 'Invest'),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            if (imageUrls.isNotEmpty)
              Image.network(
                imageUrls.first,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 220, color: Colors.grey[200],
                  child: const Icon(Icons.image, size: 64, color: Colors.grey),
                ),
              )
            else
              Container(
                height: 220, color: Colors.grey[200],
                child: const Center(child: Icon(Icons.inventory_2, size: 64, color: Colors.grey)),
              ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product name and category
                  Text(listing['assetName'] ?? '', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D2FF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(listing['category'] ?? '', style: const TextStyle(color: Color(0xFF00D2FF))),
                  ),
                  const SizedBox(height: 16),
                  Text(listing['description'] ?? '', style: TextStyle(color: Colors.grey[700], fontSize: 15)),

                  const SizedBox(height: 24),
                  // Funding Progress Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Funding Progress', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Raised', style: TextStyle(color: Colors.grey)),
                                  Text('৳${(listing['currentFunded'] ?? 0).toStringAsFixed(0)}',
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Target', style: TextStyle(color: Colors.grey)),
                                  Text('৳${(listing['fundingTarget'] ?? 0).toStringAsFixed(0)}',
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: (fundingPct / 100).clamp(0.0, 1.0),
                              backgroundColor: Colors.grey[200],
                              color: fundingPct >= 100 ? Colors.green : const Color(0xFF00D2FF),
                              minHeight: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Text('${fundingPct.toStringAsFixed(1)}% funded',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: fundingPct >= 100 ? Colors.green : const Color(0xFF00D2FF),
                                )),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Text('Remaining: ৳${remaining.toStringAsFixed(0)}',
                                style: TextStyle(color: Colors.grey[600])),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  // Investors list
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Investors', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          if (_loadingInvestors)
                            const Center(child: CircularProgressIndicator())
                          else if (_investorsData != null && _investorsData!['investors'] != null)
                            ...(List<Map<String, dynamic>>.from(_investorsData!['investors'])).map(
                              (inv) => ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFF00D2FF).withOpacity(0.2),
                                  child: const Icon(Icons.person, color: Color(0xFF00D2FF)),
                                ),
                                title: Text(inv['investorName'] ?? 'Unknown'),
                                subtitle: Text('৳${(inv['amount'] ?? 0).toStringAsFixed(0)}'),
                                trailing: Text(
                                  '${(inv['sharePercentage'] ?? 0).toStringAsFixed(1)}%',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                            )
                          else
                            const Text('No investors yet. Be the first!', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  // Investment form
                  if (remaining > 0) ...[
                    const Text('Invest in this Product', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Amount (৳)',
                        hintText: 'Max: ৳${remaining.toStringAsFixed(0)}',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.attach_money),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_error!, style: const TextStyle(color: Colors.red)),
                      ),
                    if (_success != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_success!, style: const TextStyle(color: Colors.green)),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _invest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00D2FF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSubmitting
                            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                            : const Text('Invest Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ] else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Text('Fully Funded!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
