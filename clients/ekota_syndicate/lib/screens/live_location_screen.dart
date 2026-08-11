import 'package:flutter/material.dart';
import '../services/location_service.dart';

class LiveLocationScreen extends StatefulWidget {
  const LiveLocationScreen({super.key});

  @override
  State<LiveLocationScreen> createState() => _LiveLocationScreenState();
}

class _LiveLocationScreenState extends State<LiveLocationScreen> {
  List<Map<String, dynamic>> _subscriptions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  Future<void> _loadSubscriptions() async {
    setState(() => _isLoading = true);
    try {
      final subs = await LocationService.getMySubscriptions();
      if (!mounted) return;
      setState(() { _subscriptions = subs; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _viewLocation(String listingId, String assetName) async {
    try {
      final location = await LocationService.getProductLocation(listingId);
      if (!mounted) return;
      if (location == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No location data available')),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(assetName),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on, color: Color(0xFF00D2FF)),
                  const SizedBox(width: 8),
                  const Text('Live Location', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              _locationRow('Latitude', '${location['latitude']}'),
              _locationRow('Longitude', '${location['longitude']}'),
              if (location['address'] != null)
                _locationRow('Address', location['address']),
              _locationRow('Storage', location['storageLocation'] ?? 'Unknown'),
              const SizedBox(height: 8),
              Text(
                'Last updated: ${location['lastUpdated'] ?? 'N/A'}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 16),
              // Simple map placeholder showing coordinates
              Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.map, color: Color(0xFF00D2FF), size: 40),
                      const SizedBox(height: 8),
                      Text(
                        '${location['latitude']?.toStringAsFixed(6)}, ${location['longitude']?.toStringAsFixed(6)}',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _unsubscribe(String listingId) async {
    try {
      final success = await LocationService.unsubscribe(listingId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? 'Unsubscribed successfully' : 'Failed to unsubscribe')),
      );
      _loadSubscriptions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Widget _locationRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text('$label:', style: TextStyle(color: Colors.grey[600]))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadSubscriptions,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _subscriptions.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 200),
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.location_off_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No location subscriptions', style: TextStyle(fontSize: 16, color: Colors.grey)),
                          SizedBox(height: 8),
                          Text('Subscribe from your investment details',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _subscriptions.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      final totalFee = _subscriptions.fold<double>(
                        0, (sum, s) => sum + (s['monthlyFee'] as num).toDouble(),
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
                              const Icon(Icons.location_on, color: Color(0xFF00D2FF), size: 36),
                              const SizedBox(height: 12),
                              const Text('Location Tracking Fee',
                                  style: TextStyle(color: Colors.white70, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text('৳${totalFee.toStringAsFixed(0)}/month',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('${_subscriptions.length} products tracked',
                                  style: const TextStyle(color: Color(0xFF00D2FF))),
                            ],
                          ),
                        ),
                      );
                    }

                    final sub = _subscriptions[index - 1];
                    final listing = sub['listing'] ?? {};
                    final hasLocation = listing['hasLocation'] == true;

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  hasLocation ? Icons.location_on : Icons.location_off,
                                  color: hasLocation ? Colors.green : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(listing['assetName'] ?? sub['listingId'],
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Fee: ৳${sub['monthlyFee']}/month',
                                style: TextStyle(color: Colors.grey[600])),
                            if (listing['storageLocation'] != null)
                              Text('Storage: ${listing['storageLocation']}',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: hasLocation
                                        ? () => _viewLocation(sub['listingId'], listing['assetName'] ?? '')
                                        : null,
                                    icon: const Icon(Icons.map, size: 18),
                                    label: const Text('View Location'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00D2FF),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () => _unsubscribe(sub['listingId']),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Unsub'),
                                ),
                              ],
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
