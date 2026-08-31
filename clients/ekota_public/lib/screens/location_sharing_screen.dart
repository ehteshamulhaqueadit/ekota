import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

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

  bool _isLocating = false;
  String? _gpsMessage;
  double? _gpsAccuracy;
  bool _permissionDeniedForever = false;

  @override
  void initState() {
    super.initState();
    _fetchGps();
  }

  @override
  void dispose() {
    _latController.dispose();
    _lonController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  /// Reads the product's live location straight from the device GPS and
  /// auto-fills the form. Falls back to the last known fix if a fresh GPS
  /// lock takes too long, so sharing still works on slow or indoor GPS.
  Future<void> _fetchGps() async {
    if (_isLocating) return;
    setState(() {
      _isLocating = true;
      _gpsMessage = 'Detecting your GPS location…';
      _permissionDeniedForever = false;
    });

    try {
      final pos = await _getDevicePosition();
      if (!mounted) return;
      if (pos == null) {
        setState(() => _isLocating = false);
        return;
      }

      _latController.text = pos.latitude.toStringAsFixed(6);
      _lonController.text = pos.longitude.toStringAsFixed(6);
      setState(() {
        _isLocating = false;
        _gpsAccuracy = pos.accuracy;
        _gpsMessage = pos.accuracy > 0
            ? 'GPS locked — accuracy ±${pos.accuracy.toStringAsFixed(0)} m'
            : 'GPS location acquired';
      });

      final address = await _reverseGeocode(pos.latitude, pos.longitude);
      if (!mounted) return;
      if (address != null && address.isNotEmpty) {
        _addressController.text = address;
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLocating = false;
        _gpsMessage =
            'Could not read GPS automatically. Tap "Use My GPS Location" to retry, or enter the coordinates manually.';
      });
    }
  }

  Future<Position?> _getDevicePosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() =>
            _gpsMessage = 'Location services are turned off. Enable GPS from your device settings.');
      }
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      if (mounted) {
        setState(() => _gpsMessage =
            'Location permission was denied. Allow location access to auto-fill your GPS coordinates.');
      }
      return null;
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _permissionDeniedForever = true;
          _gpsMessage = 'Location permission is permanently blocked. Open app settings to allow it.';
        });
      }
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (_) {
      // Fresh fix took too long — use the most recent cached fix.
      return Geolocator.getLastKnownPosition();
    }
  }

  /// Best-effort reverse geocoding (OpenStreetMap Nominatim, no API key).
  /// Address is optional, so this never blocks sharing when it fails.
  Future<String?> _reverseGeocode(double lat, double lon) async {
    try {
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=jsonv2&zoom=16');
      final res = await http
          .get(uri, headers: const {'User-Agent': 'ekota_public_app'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      if (data is Map && data['display_name'] is String) {
        return data['display_name'] as String;
      }
    } catch (_) {
      // ignore — geocoding is best-effort
    }
    return null;
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
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Invalid coordinates. Latitude must be -90..90 and longitude -180..180')),
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

            // Device GPS card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.gps_fixed, color: Color(0xFF6C63FF)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Device GPS',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      if (_gpsAccuracy != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '±${_gpsAccuracy!.toStringAsFixed(0)} m',
                            style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_isLocating)
                    Row(
                      children: const [
                        SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6C63FF)),
                        ),
                        SizedBox(width: 10),
                        Expanded(child: Text('Detecting your GPS location…', style: TextStyle(fontSize: 13))),
                      ],
                    )
                  else if (_gpsMessage != null)
                    Text(_gpsMessage!, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLocating ? null : _fetchGps,
                          icon: const Icon(Icons.my_location, size: 18),
                          label: const Text('Use My GPS Location'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6C63FF),
                            side: const BorderSide(color: Color(0xFF6C63FF)),
                            minimumSize: const Size.fromHeight(46),
                          ),
                        ),
                      ),
                      if (_permissionDeniedForever) ...[
                        const SizedBox(width: 10),
                        TextButton(
                          onPressed: () => Geolocator.openAppSettings(),
                          child: const Text('Open Settings'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text('Your GPS Coordinates',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              'Auto-filled from your device. You can adjust them before sharing.',
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
                hintText: 'Auto-filled from GPS, or type it',
                prefixIcon: const Icon(Icons.home_outlined, color: Color(0xFF6C63FF)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF6C63FF)),
                ),
              ),
            ),
            const SizedBox(height: 28),

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