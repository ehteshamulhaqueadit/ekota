import 'package:flutter/material.dart';
import '../services/rental_service.dart';
import 'rental_detail_screen.dart';

class RentalMarketplaceScreen extends StatefulWidget {
  const RentalMarketplaceScreen({super.key});

  @override
  State<RentalMarketplaceScreen> createState() => _RentalMarketplaceScreenState();
}

class _RentalMarketplaceScreenState extends State<RentalMarketplaceScreen> {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await PublicRentalService.getRentalPool();
      if (!mounted) return;
      setState(() {
        _items = items;
        _filtered = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _filterItems(String query) {
    setState(() {
      _search = query;
      _filtered = _items.where((item) {
        final name = (item['assetName'] ?? '').toString().toLowerCase();
        final cat = (item['category'] ?? '').toString().toLowerCase();
        return name.contains(query.toLowerCase()) || cat.contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          color: Colors.white,
          child: TextField(
            onChanged: _filterItems,
            decoration: InputDecoration(
              hintText: 'Search products...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.grey[100],
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        // Product grid
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadItems,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? ListView(children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Column(
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(
                                _search.isEmpty ? 'No products available' : 'No results for "$_search"',
                                style: TextStyle(color: Colors.grey[500], fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ])
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.72,
                        ),
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final item = _filtered[index];
                          final imageUrls = List<String>.from(item['imageUrls'] ?? []);
                          final isAvailable = item['status'] == 'AVAILABLE';

                          return GestureDetector(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RentalDetailScreen(poolItem: item),
                                ),
                              );
                              _loadItems();
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Product image
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                    child: Stack(
                                      children: [
                                        imageUrls.isNotEmpty
                                            ? Image.network(
                                                imageUrls.first,
                                                height: 130,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => Container(
                                                  height: 130,
                                                  color: Colors.grey[200],
                                                  child: const Center(
                                                    child: Icon(Icons.image, size: 40, color: Colors.grey),
                                                  ),
                                                ),
                                              )
                                            : Container(
                                                height: 130,
                                                color: Colors.grey[100],
                                                child: const Center(
                                                  child: Icon(Icons.inventory_2, size: 40, color: Colors.grey),
                                                ),
                                              ),
                                        // Status badge
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isAvailable ? Colors.green : Colors.orange,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              isAvailable ? 'Available' : 'Rented',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Info
                                  Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['assetName'] ?? '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          item['category'] ?? '',
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '৳${(item['currentRentPrice'] ?? 0).toStringAsFixed(0)}/day',
                                          style: const TextStyle(
                                            color: Color(0xFF6C63FF),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
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
          ),
        ),
      ],
    );
  }
}
