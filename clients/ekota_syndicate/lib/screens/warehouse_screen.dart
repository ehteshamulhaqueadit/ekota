import 'package:flutter/material.dart';
import '../services/warehouse_service.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  List<Map<String, dynamic>> _warehouseItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await WarehouseService.getMyWarehouseItems();
      if (!mounted) return;
      setState(() { _warehouseItems = items; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _retrieveItem(String listingId) async {
    try {
      final result = await WarehouseService.retrieveFromWarehouse(listingId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? result['error'] ?? 'Done')),
      );
      _loadItems();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadItems,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _warehouseItems.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 200),
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.warehouse_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No products in warehouse', style: TextStyle(fontSize: 16, color: Colors.grey)),
                          SizedBox(height: 8),
                          Text('Store products from your portfolio',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _warehouseItems.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      // Summary card
                      final totalFee = _warehouseItems.fold<double>(
                        0, (sum, item) => sum + (item['monthlyFee'] as num).toDouble(),
                      );
                      return Card(
                        elevation: 3,
                        color: const Color(0xFF1A1A2E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        margin: const EdgeInsets.only(bottom: 20),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              const Icon(Icons.warehouse, color: Color(0xFF00D2FF), size: 36),
                              const SizedBox(height: 12),
                              const Text('Total Monthly Fees',
                                  style: TextStyle(color: Colors.white70, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text('৳${totalFee.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('${_warehouseItems.length} items stored',
                                  style: const TextStyle(color: Color(0xFF00D2FF))),
                            ],
                          ),
                        ),
                      );
                    }

                    final item = _warehouseItems[index - 1];
                    final imageUrls = List<String>.from(item['imageUrls'] ?? []);

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: imageUrls.isNotEmpty
                                  ? Image.network(imageUrls.first, width: 56, height: 56, fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(width: 56, height: 56, color: Colors.grey[200], child: const Icon(Icons.image)))
                                  : Container(width: 56, height: 56, color: Colors.grey[200], child: const Icon(Icons.inventory_2)),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['assetName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text('Fee: ৳${(item['monthlyFee'] ?? 0).toStringAsFixed(0)}/mo',
                                      style: TextStyle(color: Colors.grey[600])),
                                  Text('Share: ${(item['mySharePercentage'] ?? 0).toStringAsFixed(1)}%',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => _retrieveItem(item['listingId']),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.withOpacity(0.1),
                                foregroundColor: Colors.orange,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Retrieve'),
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
