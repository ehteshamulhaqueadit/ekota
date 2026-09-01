import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/listing_service.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';

class OrderConfirmationScreen extends StatefulWidget {
  const OrderConfirmationScreen({super.key});

  @override
  State<OrderConfirmationScreen> createState() => _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen> {
  List<dynamic> _fullyFundedListings = [];
  bool _isLoading = true;
  Set<String> _confirmingIds = {};

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
      setState(() {
        _fullyFundedListings = listings
            .where((l) => l.campaignStatus.toUpperCase() == 'FULLY_FUNDED' ||
                l.campaignStatus.toUpperCase() == 'IN_PRODUCTION')
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDelivery(String listingId, String assetName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delivery'),
        content: Text(
          'Are you sure you want to mark "$assetName" as delivered?\n\n'
          'This will notify all investors that the product has been delivered.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirm Delivery', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _confirmingIds.add(listingId));
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt') ?? '';
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/listings/$listingId/confirm-delivery'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Order confirmed!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadListings();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? data['message'] ?? 'Failed to confirm')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _confirmingIds.remove(listingId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Orders')),
      body: RefreshIndicator(
        onRefresh: _loadListings,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _fullyFundedListings.isEmpty
                ? ListView(children: const [
                    SizedBox(height: 200),
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.pending_actions, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No fully funded orders to confirm',
                              style: TextStyle(fontSize: 16, color: Colors.grey)),
                          SizedBox(height: 8),
                          Text('Orders appear here when 100% funded',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ])
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _fullyFundedListings.length,
                    itemBuilder: (context, index) {
                      final listing = _fullyFundedListings[index];
                      final isConfirming = _confirmingIds.contains(listing.id);
                      final isInProduction = listing.campaignStatus.toUpperCase() == 'IN_PRODUCTION';

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
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.check_circle, color: Colors.green),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(listing.assetName,
                                            style: const TextStyle(
                                                fontSize: 18, fontWeight: FontWeight.bold)),
                                        Text('100% Funded  •  ৳${listing.fundingTarget.toStringAsFixed(0)}',
                                            style: TextStyle(color: Colors.grey[600])),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Investor count
                              Row(
                                children: [
                                  const Icon(Icons.people, size: 16, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text('${listing.investorCount} investors',
                                      style: TextStyle(color: Colors.grey[600])),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Action section
                              if (isInProduction)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.pending, color: Colors.orange),
                                      SizedBox(width: 8),
                                      Text('In Production',
                                          style: TextStyle(
                                              color: Colors.orange,
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                )
                              else
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    onPressed: isConfirming
                                        ? null
                                        : () => _confirmDelivery(listing.id, listing.assetName),
                                    icon: isConfirming
                                        ? const SizedBox(
                                            width: 18, height: 18,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2, color: Colors.white))
                                        : const Icon(Icons.local_shipping),
                                    label: const Text('Confirm Delivery'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
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
