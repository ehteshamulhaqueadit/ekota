import 'package:flutter/material.dart';
import '../services/investment_service.dart';
import 'invest_screen.dart';

class InvestmentMarketplaceScreen extends StatefulWidget {
  const InvestmentMarketplaceScreen({super.key});

  @override
  State<InvestmentMarketplaceScreen> createState() => _InvestmentMarketplaceScreenState();
}

class _InvestmentMarketplaceScreenState extends State<InvestmentMarketplaceScreen> {
  List<Map<String, dynamic>> _listings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadListings();
  }

  Future<void> _loadListings() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final listings = await InvestmentService.getAvailableListings();
      if (!mounted) return;
      setState(() { _listings = listings; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadListings,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text('Error: $_error', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadListings, child: const Text('Retry')),
                    ],
                  ),
                )
              : _listings.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 200),
                        Center(
                          child: Column(
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('No products available for investment',
                                  style: TextStyle(fontSize: 16, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _listings.length,
                      itemBuilder: (context, index) {
                        final listing = _listings[index];
                        final fundingPct = (listing['fundingPercentage'] ?? 0).toDouble();
                        final imageUrls = List<String>.from(listing['imageUrls'] ?? []);

                        return Card(
                          elevation: 3,
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => InvestScreen(listing: listing),
                                ),
                              );
                              _loadListings();
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Image
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                  child: imageUrls.isNotEmpty
                                      ? Image.network(
                                          imageUrls.first,
                                          height: 180,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            height: 180,
                                            color: Colors.grey[200],
                                            child: const Icon(Icons.image, size: 64, color: Colors.grey),
                                          ),
                                        )
                                      : Container(
                                          height: 180,
                                          color: Colors.grey[200],
                                          child: const Center(
                                            child: Icon(Icons.inventory_2, size: 64, color: Colors.grey),
                                          ),
                                        ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Title and Category
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              listing['assetName'] ?? 'Unnamed',
                                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF00D2FF).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              listing['category'] ?? '',
                                              style: const TextStyle(
                                                color: Color(0xFF00D2FF),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        listing['description'] ?? '',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                      ),
                                      const SizedBox(height: 16),
                                      // Funding progress
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '৳${(listing['currentFunded'] ?? 0).toStringAsFixed(0)}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          Text(
                                            'of ৳${(listing['fundingTarget'] ?? 0).toStringAsFixed(0)}',
                                            style: TextStyle(color: Colors.grey[600]),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: LinearProgressIndicator(
                                          value: (fundingPct / 100).clamp(0.0, 1.0),
                                          backgroundColor: Colors.grey[200],
                                          color: fundingPct >= 100
                                              ? Colors.green
                                              : const Color(0xFF00D2FF),
                                          minHeight: 8,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${fundingPct.toStringAsFixed(1)}% funded',
                                            style: TextStyle(
                                              color: fundingPct >= 100 ? Colors.green : const Color(0xFF00D2FF),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              const Icon(Icons.people, size: 16, color: Colors.grey),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${listing['investorCount'] ?? 0} investors',
                                                style: TextStyle(color: Colors.grey[600]),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
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
