import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/rental_service.dart';
import 'location_sharing_screen.dart';
import 'rental_portal_screen.dart';

class MyRentalsScreen extends StatefulWidget {
  const MyRentalsScreen({super.key});

  @override
  State<MyRentalsScreen> createState() => _MyRentalsScreenState();
}

class _MyRentalsScreenState extends State<MyRentalsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _active = [];
  List<Map<String, dynamic>> _past = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRentals();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRentals() async {
    setState(() => _isLoading = true);
    try {
      final rentals = await PublicRentalService.getMyRentals();
      if (!mounted) return;
      setState(() {
        _active = rentals.where((r) => r['isActive'] == true).toList();
        _past = rentals.where((r) => r['isActive'] != true).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _returnProduct(Map<String, dynamic> rental) async {
    final poolItemId = rental['poolItemId']?.toString();
    if (poolItemId == null || poolItemId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to return: rental data is missing. Please restart the app.')),
      );
      return;
    }

    // Confirm the return request. The server generates a NEW return gate-pass
    // QR that the warehouse scans to finally complete the return.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Return Product'),
        content: const Text(
          'Requesting a return will generate a NEW return gate-pass QR. '
          'Show this QR at the warehouse so they can verify and complete your return.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Request Return', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await PublicRentalService.returnProduct(poolItemId);
      if (!mounted) return;

      if (result['error'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error']), backgroundColor: Colors.red),
        );
        return;
      }

      final returnCode = (result['returnGatePassCode'] ?? '').toString();
      if (returnCode.isNotEmpty) {
        await _showReturnQr(returnCode);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Return requested! Show the new QR at the warehouse to complete it.'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _loadRentals();
    } catch (e) {
      if (!mounted) return;
      // The request may have timed out even though the server already processed
      // the return (the response was lost). Refresh to verify the real state
      // instead of telling the user it failed when it actually succeeded.
      List<Map<String, dynamic>> rentals = [];
      try {
        rentals = await PublicRentalService.getMyRentals();
      } catch (_) {
        // Keep the empty list below — fall back to showing the error.
      }
      if (!mounted) return;

      final stillActive = rentals.any(
        (r) => r['poolItemId']?.toString() == poolItemId && r['isActive'] == true,
      );

      if (stillActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product returned successfully.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadRentals();
      }
    }
  }

  /// Show the NEW return gate-pass QR after a return request, with
  /// instructions to present it at the warehouse.
  Future<void> _showReturnQr(String returnCode) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.qr_code_2, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Return Gate-Pass'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Return requested! Show this QR at the warehouse to complete your return.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            QrImageView(
              data: returnCode,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF1E1B4B)),
              dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square, color: Color(0xFF1E1B4B)),
            ),
            const SizedBox(height: 12),
            SelectableText(
              returnCode,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 11, letterSpacing: 0.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF6C63FF),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF6C63FF),
          tabs: [
            Tab(text: 'Active (${_active.length})'),
            Tab(text: 'Past (${_past.length})'),
          ],
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadRentals,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRentalList(_active, isActive: true),
                      _buildRentalList(_past, isActive: false),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildRentalList(List<Map<String, dynamic>> rentals, {required bool isActive}) {
    if (rentals.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 160),
        Center(
          child: Column(
            children: [
              Icon(isActive ? Icons.receipt_long_outlined : Icons.history,
                  size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                isActive ? 'No active rentals' : 'No past rentals',
                style: TextStyle(color: Colors.grey[400], fontSize: 16),
              ),
            ],
          ),
        ),
      ]);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rentals.length,
      itemBuilder: (context, index) {
        final rental = rentals[index];
        final listing = rental['listing'] ?? {};
        final imageUrls = List<String>.from(listing['imageUrls'] ?? []);
        final listingId = listing['id'];

        // Calculate days if active
        String durationText = '';
        if (isActive && rental['startDate'] != null) {
          final start = DateTime.tryParse(rental['startDate']);
          if (start != null) {
            final days = DateTime.now().difference(start).inDays;
            durationText = '${days + 1} day${days == 0 ? '' : 's'} so far';
          }
        } else if (rental['endDate'] != null) {
          final days = rental['daysRented'] ?? 1;
          durationText = '$days day${days == 1 ? '' : 's'}';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Product info row
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: imageUrls.isNotEmpty
                          ? Image.network(imageUrls.first,
                              width: 64, height: 64, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 64, height: 64,
                                color: Colors.grey[100],
                                child: const Icon(Icons.image, color: Colors.grey),
                              ))
                          : Container(
                              width: 64, height: 64,
                              color: Colors.grey[100],
                              child: const Icon(Icons.inventory_2, color: Colors.grey)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(listing['assetName'] ?? 'Product',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text('৳${(rental['dailyRate'] ?? 0).toStringAsFixed(0)}/day',
                              style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.w600)),
                          if (durationText.isNotEmpty)
                            Text(durationText, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        ],
                      ),
                    ),
                    if (!isActive && rental['totalCost'] != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Total', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          Text(
                            '৳${(rental['totalCost'] as num).toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              // Action buttons for active rentals
              if (isActive) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Open the active rental portal (countdown + gate-pass)
                      ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RentalPortalScreen(rentalId: rental['id'].toString()),
                          ),
                        ),
                        icon: const Icon(Icons.qr_code_2, size: 16),
                        label: const Text('Open Rental Portal'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          // Share location button
                          if (listingId != null)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LocationSharingScreen(listingId: listingId),
                                  ),
                                ),
                                icon: const Icon(Icons.location_on, size: 16),
                                label: const Text('Share Location'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF6C63FF),
                                  side: const BorderSide(color: Color(0xFF6C63FF)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          if (listingId != null) const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _returnProduct(rental),
                              icon: const Icon(Icons.assignment_return, size: 16),
                              label: const Text('Return'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[50],
                                foregroundColor: Colors.red,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
