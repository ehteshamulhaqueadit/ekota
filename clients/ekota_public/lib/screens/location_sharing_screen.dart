import 'package:flutter/material.dart';
import '../services/rental_service.dart';

class LocationSharingScreen extends StatefulWidget {
  final String listingId;
  const LocationSharingScreen({super.key, required this.listingId});

  @override
  State<LocationSharingScreen> createState() => _LocationSharingScreenState();
}

class _LocationSharingScreenState extends State<LocationSharingScreen> {
  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isSharing = false;
  bool _isActive = false;
  String? _lastShared;

  @override
  void dispose() {
    _latController.dispose();
    _lonController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _shareLocation() async {
    final lat = double.tryParse(_latController.text);
    final lon = double.tryParse(_lonController.text);

    if (lat == null || lon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid latitude and longitude')),
      );
      return;
    }

    setState(() { _isSharing = true; });
    try {
      final result = await PublicRentalService.updateLocation(
        listingId: widget.listingId,
        latitude: lat,
        longitude: lon,
        address: _addressController.text.isNotEmpty ? _addressController.text : null,
      );
      if (!mounted) return;
      if (result['location'] != null) {
        setState(() {
          _isActive = true;
          _lastShared = 'Last shared: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? 'Failed to update location')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share Location'),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFF6C63FF)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Location Sharing',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6C63FF),
                              fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'As the active renter, your location is the live location of this product. '
                    'Investors who have subscribed to location tracking can see this.',
                    style: TextStyle(color: Colors.grey[700], fontSize: 13, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Status indicator
            if (_isActive) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Location Shared',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                        if (_lastShared != null)
                          Text(_lastShared!, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            const Text('Your GPS Coordinates',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              'Enter your current GPS coordinates to share with investors.',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 16),

            // Latitude
            TextField(
              controller: _latController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: InputDecoration(
                labelText: 'Latitude',
                hintText: 'e.g. 23.8103',
                prefixIcon: const Icon(Icons.north, color: Color(0xFF6C63FF)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF6C63FF)),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Longitude
            TextField(
              controller: _lonController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: InputDecoration(
                labelText: 'Longitude',
                hintText: 'e.g. 90.4125',
                prefixIcon: const Icon(Icons.east, color: Color(0xFF6C63FF)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF6C63FF)),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Address (optional)
            TextField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Address (optional)',
                hintText: 'e.g. Mirpur-10, Dhaka',
                prefixIcon: const Icon(Icons.home_outlined, color: Color(0xFF6C63FF)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF6C63FF)),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Sample coordinates helper
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sample Dhaka coordinates:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () {
                      _latController.text = '23.8103';
                      _lonController.text = '90.4125';
                      _addressController.text = 'Dhaka, Bangladesh';
                    },
                    child: const Text('📍 23.8103, 90.4125 (Dhaka city center)',
                        style: TextStyle(color: Color(0xFF6C63FF), fontSize: 13)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Share button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isSharing ? null : _shareLocation,
                icon: _isSharing
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.location_on),
                label: Text(
                  _isSharing ? 'Updating...' : 'Update My Location',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
