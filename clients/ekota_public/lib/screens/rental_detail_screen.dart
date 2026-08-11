import 'package:flutter/material.dart';
import '../services/rental_service.dart';

class RentalDetailScreen extends StatefulWidget {
  final Map<String, dynamic> poolItem;
  const RentalDetailScreen({super.key, required this.poolItem});

  @override
  State<RentalDetailScreen> createState() => _RentalDetailScreenState();
}

class _RentalDetailScreenState extends State<RentalDetailScreen> {
  bool _isRenting = false;
  String? _error;
  String? _success;

  Future<void> _rentProduct() async {
    setState(() { _isRenting = true; _error = null; _success = null; });
    try {
      final result = await PublicRentalService.rentProduct(widget.poolItem['id']);
      if (!mounted) return;
      if (result['rental'] != null) {
        setState(() => _success = 'Rental started! Enjoy your product.');
      } else {
        setState(() => _error = result['error'] ?? 'Could not rent this product');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Network error: $e');
    } finally {
      if (mounted) setState(() => _isRenting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.poolItem;
    final imageUrls = List<String>.from(item['imageUrls'] ?? []);
    final isAvailable = item['status'] == 'AVAILABLE';
    final price = (item['currentRentPrice'] ?? 0).toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      body: CustomScrollView(
        slivers: [
          // App bar with image
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: const Color(0xFF6C63FF),
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: imageUrls.isNotEmpty
                  ? Image.network(
                      imageUrls.first,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.image, size: 80, color: Colors.grey),
                      ),
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.inventory_2, size: 80, color: Colors.grey),
                      ),
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item['assetName'] ?? 'Product',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isAvailable ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isAvailable ? 'Available' : 'Rented',
                          style: TextStyle(
                            color: isAvailable ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item['category'] ?? '',
                    style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),

                  // Price card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Rental Price', style: TextStyle(color: Colors.white70, fontSize: 13)),
                            SizedBox(height: 4),
                            Text('Per day', style: TextStyle(color: Colors.white60, fontSize: 11)),
                          ],
                        ),
                        Text(
                          '৳${price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Description
                  if (item['description'] != null && item['description'].isNotEmpty) ...[
                    const Text('Description', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(item['description'], style: TextStyle(color: Colors.grey[600], height: 1.5)),
                    const SizedBox(height: 20),
                  ],

                  // Producer
                  if (item['producerName'] != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 18, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text('Made by: ${item['producerName']}',
                            style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // How it works
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('How it works', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        _howItWorksRow(Icons.shopping_cart_checkout, 'Rent the product below'),
                        _howItWorksRow(Icons.location_on, 'Your live location is shared with investors'),
                        _howItWorksRow(Icons.assignment_return, 'Return when done to stop billing'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Feedback messages
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red))),
                        ],
                      ),
                    ),
                  if (_success != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_success!, style: const TextStyle(color: Colors.green))),
                        ],
                      ),
                    ),

                  // Rent button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: (!isAvailable || _isRenting || _success != null) ? null : _rentProduct,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[300],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _isRenting
                          ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          : Text(
                              _success != null
                                  ? '✓ Rented'
                                  : isAvailable
                                      ? 'Rent Now'
                                      : 'Currently Unavailable',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _howItWorksRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6C63FF)),
          const SizedBox(width: 10),
          Text(text, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
        ],
      ),
    );
  }
}
