import 'package:flutter/material.dart';
import '../services/investment_service.dart';
import '../services/rental_service.dart';
import '../services/warehouse_service.dart';
import '../services/location_service.dart';
import 'voting_screen.dart';

class InvestmentDetailScreen extends StatefulWidget {
  final String listingId;
  final Map<String, dynamic> investmentData;

  const InvestmentDetailScreen({
    super.key,
    required this.listingId,
    required this.investmentData,
  });

  @override
  State<InvestmentDetailScreen> createState() => _InvestmentDetailScreenState();
}

class _InvestmentDetailScreenState extends State<InvestmentDetailScreen> {
  Map<String, dynamic>? _listingDetails;
  bool _isLoading = true;
  bool _isActioning = false;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);
    try {
      final details = await InvestmentService.getListingDetails(widget.listingId);
      if (!mounted) return;
      setState(() { _listingDetails = details; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _listForRent() async {
    setState(() => _isActioning = true);
    try {
      final result = await RentalService.listInRentalPool(widget.listingId);
      if (!mounted) return;
      final msg = result['error'] ?? 'Listed in rental pool successfully!';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      _loadDetails();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isActioning = false);
    }
  }

  Future<void> _storeInWarehouse() async {
    setState(() => _isActioning = true);
    try {
      final result = await WarehouseService.storeInWarehouse(widget.listingId);
      if (!mounted) return;
      final msg = result['message'] ?? result['error'] ?? 'Done';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      _loadDetails();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isActioning = false);
    }
  }

  Future<void> _retrieveFromWarehouse() async {
    setState(() => _isActioning = true);
    try {
      final result = await WarehouseService.retrieveFromWarehouse(widget.listingId);
      if (!mounted) return;
      final msg = result['message'] ?? result['error'] ?? 'Done';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      _loadDetails();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isActioning = false);
    }
  }

  Future<void> _subscribeLocation() async {
    setState(() => _isActioning = true);
    try {
      final result = await LocationService.subscribe(widget.listingId);
      if (!mounted) return;
      final msg = result['message'] ?? result['error'] ?? 'Done';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isActioning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.investmentData;
    final listing = inv['listing'] ?? {};

    return Scaffold(
      appBar: AppBar(
        title: Text(listing['assetName'] ?? 'Investment Detail'),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Share info card
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: const Color(0xFF1A1A2E),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _statColumn('Your Share', '${(inv['sharePercentage'] ?? 0).toStringAsFixed(1)}%'),
                          Container(width: 1, height: 40, color: Colors.white24),
                          _statColumn('Invested', '৳${(inv['amount'] ?? 0).toStringAsFixed(0)}'),
                          Container(width: 1, height: 40, color: Colors.white24),
                          _statColumn('Status', listing['campaignStatus'] ?? 'N/A'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Product info
                  if (_listingDetails != null) ...[
                    Text(_listingDetails!['assetName'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_listingDetails!['description'] ?? '', style: TextStyle(color: Colors.grey[700])),
                    const SizedBox(height: 16),

                    // Storage info
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Storage', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  _listingDetails!['storageLocation'] == 'WAREHOUSE'
                                      ? Icons.warehouse
                                      : Icons.home,
                                  color: const Color(0xFF00D2FF),
                                ),
                                const SizedBox(width: 8),
                                Text(_listingDetails!['storageLocation'] == 'WAREHOUSE'
                                    ? 'In Warehouse'
                                    : 'At Home'),
                              ],
                            ),
                            if (_listingDetails!['warehouseStorage'] != null &&
                                _listingDetails!['warehouseStorage']['isActive'] == true) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Monthly Fee: ৳${_listingDetails!['warehouseStorage']['monthlyFee']}',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Rental pool status
                    if (_listingDetails!['rentalPoolItem'] != null)
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Rental Pool', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Rent Price: ৳${_listingDetails!['rentalPoolItem']['currentRentPrice']}'),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _listingDetails!['rentalPoolItem']['status'] == 'AVAILABLE'
                                          ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(_listingDetails!['rentalPoolItem']['status'] ?? '',
                                        style: TextStyle(
                                          color: _listingDetails!['rentalPoolItem']['status'] == 'AVAILABLE'
                                              ? Colors.green : Colors.orange,
                                          fontWeight: FontWeight.w600,
                                        )),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],

                  const SizedBox(height: 24),
                  const Text('Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  // Action buttons
                  if (_listingDetails != null && _listingDetails!['isDelivered'] == true) ...[
                    if (_listingDetails!['rentalPoolItem'] == null)
                      _actionButton(Icons.storefront, 'List in Rental Pool', _listForRent),
                    const SizedBox(height: 8),

                    if (_listingDetails!['rentalPoolItem'] != null)
                      _actionButton(Icons.how_to_vote, 'Vote on Rent Price', () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VotingScreen(
                              poolItemId: _listingDetails!['rentalPoolItem']['id'],
                              listingId: widget.listingId,
                              currentRentPrice: (_listingDetails!['rentalPoolItem']['currentRentPrice'] as num).toDouble(),
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: 8),

                    if (_listingDetails!['storageLocation'] != 'WAREHOUSE')
                      _actionButton(Icons.warehouse, 'Store in Warehouse', _storeInWarehouse)
                    else
                      _actionButton(Icons.home, 'Retrieve from Warehouse', _retrieveFromWarehouse),
                    const SizedBox(height: 8),

                    _actionButton(Icons.location_on, 'Subscribe to Live Location', _subscribeLocation),
                  ] else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange),
                          SizedBox(width: 8),
                          Expanded(child: Text('Product not yet delivered. Actions available after delivery.')),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _statColumn(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isActioning ? null : onTap,
        icon: Icon(icon),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
