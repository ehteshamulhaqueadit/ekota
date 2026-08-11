import 'package:flutter/material.dart';
import '../services/rental_service.dart';
import '../services/investment_service.dart';

class RentalManagementScreen extends StatefulWidget {
  const RentalManagementScreen({super.key});

  @override
  State<RentalManagementScreen> createState() => _RentalManagementScreenState();
}

class _RentalManagementScreenState extends State<RentalManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _rentalPool = [];
  List<Map<String, dynamic>> _myInvestments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final pool = await RentalService.getRentalPool();
      final investments = await InvestmentService.getMyInvestments();
      if (!mounted) return;
      setState(() {
        _rentalPool = pool;
        _myInvestments = investments;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _listForRent(String listingId) async {
    try {
      final result = await RentalService.listInRentalPool(listingId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error'] ?? 'Listed successfully!')),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Rental Pool', icon: Icon(Icons.storefront)),
            Tab(text: 'List for Rent', icon: Icon(Icons.add_business)),
          ],
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // Rental Pool Tab
                    RefreshIndicator(
                      onRefresh: _loadData,
                      child: _rentalPool.isEmpty
                          ? ListView(children: const [
                              SizedBox(height: 200),
                              Center(child: Text('No products in rental pool', style: TextStyle(color: Colors.grey))),
                            ])
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _rentalPool.length,
                              itemBuilder: (context, index) {
                                final item = _rentalPool[index];
                                final imageUrls = List<String>.from(item['imageUrls'] ?? []);
                                return Card(
                                  elevation: 2,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(12),
                                    leading: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: imageUrls.isNotEmpty
                                          ? Image.network(imageUrls.first, width: 56, height: 56, fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Container(width: 56, height: 56, color: Colors.grey[200], child: const Icon(Icons.image)))
                                          : Container(width: 56, height: 56, color: Colors.grey[200], child: const Icon(Icons.inventory_2)),
                                    ),
                                    title: Text(item['assetName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text('৳${item['currentRentPrice']}/day'),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: item['status'] == 'AVAILABLE'
                                            ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(item['status'] ?? '',
                                          style: TextStyle(
                                            color: item['status'] == 'AVAILABLE' ? Colors.green : Colors.orange,
                                            fontWeight: FontWeight.w600, fontSize: 12,
                                          )),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),

                    // List for Rent Tab (show delivered investments)
                    RefreshIndicator(
                      onRefresh: _loadData,
                      child: Builder(builder: (context) {
                        final deliveredInvs = _myInvestments.where((inv) {
                          final listing = inv['listing'] ?? {};
                          return listing['isDelivered'] == true;
                        }).toList();

                        if (deliveredInvs.isEmpty) {
                          return ListView(children: const [
                            SizedBox(height: 200),
                            Center(child: Text('No delivered products to list', style: TextStyle(color: Colors.grey))),
                          ]);
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: deliveredInvs.length,
                          itemBuilder: (context, index) {
                            final inv = deliveredInvs[index];
                            final listing = inv['listing'] ?? {};
                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(12),
                                title: Text(listing['assetName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Your share: ${(inv['sharePercentage'] ?? 0).toStringAsFixed(1)}%'),
                                trailing: ElevatedButton(
                                  onPressed: () => _listForRent(listing['id']),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00D2FF),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('List'),
                                ),
                              ),
                            );
                          },
                        );
                      }),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
