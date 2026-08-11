import 'package:flutter/material.dart';
import '../services/listing_service.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';

class FundingProgressScreen extends StatefulWidget {
  const FundingProgressScreen({super.key});

  @override
  State<FundingProgressScreen> createState() => _FundingProgressScreenState();
}

class _FundingProgressScreenState extends State<FundingProgressScreen> {
  List<dynamic> _listings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadListings();
  }

  Future<void> _loadListings() async {
    setState(() => _isLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      final listings = await ListingService().getMyListings(auth.userId ?? '');
      if (!mounted) return;
      setState(() { _listings = listings; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'FULLY_FUNDED': return Colors.green;
      case 'DELIVERED': return Colors.blue;
      case 'IN_PRODUCTION': return Colors.orange;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Funding Progress')),
      body: RefreshIndicator(
        onRefresh: _loadListings,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _listings.isEmpty
                ? ListView(children: const [
                    SizedBox(height: 200),
                    Center(child: Text('No listings found', style: TextStyle(color: Colors.grey))),
                  ])
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _listings.length,
                    itemBuilder: (context, index) {
                      final listing = _listings[index];
                      final fundingTarget = (listing.fundingTarget as num).toDouble();
                      // Use fundingProgressPercent from model
                      final fundingPct = listing.fundingProgressPercent.clamp(0.0, 100.0);
                      final status = listing.campaignStatus ?? '';

                      return Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(listing.assetName,
                                        style: const TextStyle(
                                            fontSize: 18, fontWeight: FontWeight.bold)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _statusColor(status).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                          color: _statusColor(status),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Funding progress bar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: fundingPct / 100,
                                  backgroundColor: Colors.grey[200],
                                  color: fundingPct >= 100 ? Colors.green : const Color(0xFF7C4DFF),
                                  minHeight: 10,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${fundingPct.toStringAsFixed(1)}% funded',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: fundingPct >= 100 ? Colors.green : const Color(0xFF7C4DFF),
                                      )),
                                  Text('Target: ৳${fundingTarget.toStringAsFixed(0)}',
                                      style: TextStyle(color: Colors.grey[600])),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.people, size: 16, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text('${listing.investorCount} investor${listing.investorCount == 1 ? '' : 's'}',
                                      style: TextStyle(color: Colors.grey[600])),
                                ],
                              ),
                              if (status.toUpperCase() == 'FULLY_FUNDED') ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                                      SizedBox(width: 8),
                                      Text('Ready to confirm delivery!',
                                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
