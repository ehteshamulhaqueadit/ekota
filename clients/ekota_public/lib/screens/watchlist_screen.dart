import 'package:flutter/material.dart';
import '../services/watchlist_service.dart';
import 'rental_detail_screen.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  List<Map<String, dynamic>> _watchlists = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWatchlists();
  }

  Future<void> _loadWatchlists() async {
    setState(() => _isLoading = true);
    try {
      final watchlists = await WatchlistService.getMyWatchlist();
      if (!mounted) return;
      setState(() {
        _watchlists = watchlists;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load watchlist: $e')),
      );
    }
  }

  Future<void> _toggleAlert(String listingId, String alertType, bool currentValue) async {
    try {
      if (alertType == 'available') {
        await WatchlistService.updateAlerts(listingId, alertOnAvailable: !currentValue);
      } else if (alertType == 'price') {
        await WatchlistService.updateAlerts(listingId, alertOnPriceChange: !currentValue);
      } else if (alertType == 'funded') {
        await WatchlistService.updateAlerts(listingId, alertOnFunded: !currentValue);
      }
      _loadWatchlists();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update alert: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Watchlist', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _watchlists.isEmpty
              ? const Center(child: Text('Your watchlist is empty.'))
              : RefreshIndicator(
                  onRefresh: _loadWatchlists,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _watchlists.length,
                    itemBuilder: (context, index) {
                      final watch = _watchlists[index];
                      final listing = watch['listing'] ?? {};
                      final poolItem = (listing['rentalPoolItem'] != null && listing['rentalPoolItem'].isNotEmpty)
                          ? listing['rentalPoolItem'][0]
                          : null;
                      
                      final imageUrls = List<String>.from(listing['imageUrls'] ?? []);
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 2,
                        child: Column(
                          children: [
                            ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: imageUrls.isNotEmpty
                                    ? Image.network(imageUrls.first, width: 60, height: 60, fit: BoxFit.cover)
                                    : Container(width: 60, height: 60, color: Colors.grey[200], child: const Icon(Icons.image)),
                              ),
                              title: Text(listing['assetName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(listing['category'] ?? ''),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                onPressed: () async {
                                  try {
                                    await WatchlistService.removeFromWatchlist(listing['id']);
                                    _loadWatchlists();
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed to remove: $e')),
                                    );
                                  }
                                },
                              ),
                              onTap: () {
                                if (poolItem != null) {
                                  final Map<String, dynamic> itemMap = Map<String, dynamic>.from(poolItem);
                                  itemMap['assetName'] = listing['assetName'];
                                  itemMap['category'] = listing['category'];
                                  itemMap['description'] = listing['description'];
                                  itemMap['imageUrls'] = listing['imageUrls'];
                                  itemMap['specifications'] = listing['specifications'];
                                  itemMap['producerName'] = listing['producer']?['fullName'];
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => RentalDetailScreen(poolItem: itemMap)),
                                  );
                                }
                              },
                            ),
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildAlertToggle('Availability', watch['alertOnAvailable'], () => _toggleAlert(listing['id'], 'available', watch['alertOnAvailable'])),
                                  _buildAlertToggle('Price', watch['alertOnPriceChange'], () => _toggleAlert(listing['id'], 'price', watch['alertOnPriceChange'])),
                                  _buildAlertToggle('Funding', watch['alertOnFunded'], () => _toggleAlert(listing['id'], 'funded', watch['alertOnFunded'])),
                                ],
                              ),
                            )
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildAlertToggle(String label, bool value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Icon(
            value ? Icons.notifications_active : Icons.notifications_off,
            color: value ? Colors.green : Colors.grey,
            size: 20,
          )
        ],
      ),
    );
  }
}
