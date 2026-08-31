import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../services/rental_service.dart';
import 'rental_detail_screen.dart';

/// Interactive Leaflet/OpenStreetMap-style explorer for nearby rental assets.
///
/// Fetches the rental pool (with asset coordinates), clusters nearby listings,
/// and lets renters filter by distance, category, price range and real-time
/// availability before booking from an interactive pin.
class MapExploreScreen extends StatefulWidget {
  const MapExploreScreen({super.key});

  @override
  State<MapExploreScreen> createState() => _MapExploreScreenState();
}

class _MapExploreScreenState extends State<MapExploreScreen> {
  static const LatLng _defaultCenter = LatLng(23.8103, 90.4125); // Dhaka

  final MapController _mapController = MapController();

  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filtered = [];
  List<String> _categories = [];
  bool _isLoading = true;

  LatLng? _userLocation;
  bool _locationDenied = false;

  String? _selectedCategory;
  double _distanceKm = 25;
  RangeValues _priceRange = const RangeValues(0, 10000);
  bool _availableOnly = false;

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
        _categories = items
            .map((e) => (e['category'] ?? '').toString())
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        _priceRange = _buildPriceRange(items);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
    _locateUser();
  }

  RangeValues _buildPriceRange(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const RangeValues(0, 10000);
    double minPrice = double.infinity;
    double maxPrice = 0;
    for (final item in items) {
      final p = (item['currentRentPrice'] ?? 0).toDouble();
      if (p < minPrice) minPrice = p;
      if (p > maxPrice) maxPrice = p;
    }
    if (!minPrice.isFinite || maxPrice <= 0) return const RangeValues(0, 10000);
    return RangeValues(minPrice.floorToDouble(), maxPrice.ceilToDouble());
  }

  Future<void> _locateUser() async {
    if (_locationDenied) return;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setUserLocation(null);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _setUserLocation(null, denied: true);
        return;
      }
      Position? pos;
      try {
        // Give the GPS a bounded window so a slow fix never hangs the map.
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 15),
          ),
        );
      } catch (_) {
        // No fresh fix in time — fall back to the most recent known position.
        pos = await Geolocator.getLastKnownPosition();
      }
      if (pos != null) {
        _setUserLocation(LatLng(pos.latitude, pos.longitude));
      } else {
        _setUserLocation(null);
      }
    } catch (_) {
      _setUserLocation(null);
    }
  }

  void _setUserLocation(LatLng? loc, {bool denied = false}) {
    if (!mounted) return;
    setState(() {
      _userLocation = loc;
      _locationDenied = denied;
    });
    _applyFilters();
  }

  void _applyFilters() {
    final List<Map<String, dynamic>> result = [];
    for (final item in _items) {
      final lat = item['latitude'];
      final lng = item['longitude'];
      if (lat == null || lng == null) continue;

      if (_availableOnly && item['status'] != 'AVAILABLE') continue;
      if (_selectedCategory != null && item['category'] != _selectedCategory) continue;

      final price = (item['currentRentPrice'] ?? 0).toDouble();
      if (price < _priceRange.start || price > _priceRange.end) continue;

      if (_userLocation != null) {
        final dist = const Distance()
            .as(LengthUnit.Kilometer, _userLocation!, LatLng(lat, lng));
        if (dist > _distanceKm) continue;
      }

      result.add(item);
    }
    setState(() => _filtered = result);
  }

  void _selectCategory(String? category) {
    setState(() => _selectedCategory = category);
    _applyFilters();
  }

  Future<void> _showFilterSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filters',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Distance
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Nearby within', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    '${_distanceKm.round()} km',
                    style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Slider(
                value: _distanceKm.clamp(1, 100),
                min: 1,
                max: 100,
                divisions: 99,
                activeColor: const Color(0xFF6C63FF),
                onChanged: (v) => setSheetState(() => _distanceKm = v),
              ),
              const SizedBox(height: 12),

              // Price range
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Daily price', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    '৳${_priceRange.start.round()} – ৳${_priceRange.end.round()}',
                    style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              RangeSlider(
                values: _priceRange,
                min: 0,
                max: 10000,
                activeColor: const Color(0xFF6C63FF),
                divisions: 100,
                labels: RangeLabels(
                  '৳${_priceRange.start.round()}',
                  '৳${_priceRange.end.round()}',
                ),
                onChanged: (v) => setSheetState(() => _priceRange = v),
              ),
              const SizedBox(height: 12),

              // Availability
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Available now only',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Show only assets that are not currently rented'),
                value: _availableOnly,
                activeTrackColor: const Color(0xFF6C63FF),
                onChanged: (v) => setSheetState(() => _availableOnly = v),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setSheetState(() {
                          _distanceKm = 25;
                          _priceRange = _buildPriceRange(_items);
                          _availableOnly = false;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6C63FF),
                        side: const BorderSide(color: Color(0xFF6C63FF)),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _applyFilters();
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Marker> _buildMarkers() {
    return _filtered.map((item) {
      final lat = (item['latitude'] as num).toDouble();
      final lng = (item['longitude'] as num).toDouble();
      return Marker(
        point: LatLng(lat, lng),
        width: 70,
        height: 86,
        alignment: Alignment.bottomCenter,
        child: _buildPin(item),
      );
    }).toList();
  }

  Widget _buildPin(Map<String, dynamic> item) {
    final imageUrls = List<String>.from(item['imageUrls'] ?? []);
    final isAvailable = item['status'] == 'AVAILABLE';
    final price = (item['currentRentPrice'] ?? 0).toDouble();
    final color = isAvailable ? const Color(0xFF6C63FF) : Colors.orange;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: SizedBox(
                  width: 58,
                  height: 40,
                  child: imageUrls.isNotEmpty
                      ? Image.network(
                          imageUrls.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.inventory_2, size: 20, color: Colors.grey),
                          ),
                        )
                      : Container(
                          color: Colors.grey[100],
                          child: const Icon(Icons.inventory_2, size: 20, color: Colors.grey),
                        ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '৳${price.toStringAsFixed(0)}/d',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 12,
          height: 12,
          transform: Matrix4.rotationZ(0.7854),
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildCluster(int count) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Map<String, dynamic>? _itemForPoint(LatLng point) {
    for (final item in _filtered) {
      final lat = item['latitude'];
      final lng = item['longitude'];
      if (lat != null &&
          lng != null &&
          (lat as num).toDouble() == point.latitude &&
          (lng as num).toDouble() == point.longitude) {
        return item;
      }
    }
    return null;
  }

  Future<void> _showItemDetails(Map<String, dynamic> item) async {
    final imageUrls = List<String>.from(item['imageUrls'] ?? []);
    final isAvailable = item['status'] == 'AVAILABLE';
    final daily = (item['currentRentPrice'] ?? 0).toDouble();
    final hourly = (item['hourlyRate'] ?? daily / 24).toDouble();

    double? distanceKm;
    final lat = item['latitude'];
    final lng = item['longitude'];
    if (_userLocation != null && lat != null && lng != null) {
      distanceKm = const Distance()
          .as(LengthUnit.Kilometer, _userLocation!, LatLng(lat, lng));
    }
    final distanceLabel = distanceKm != null
        ? (distanceKm <= 1 ? 'Less than 1 km' : '${distanceKm.toStringAsFixed(1)} km')
        : null;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: SizedBox(
                height: 150,
                width: double.infinity,
                child: imageUrls.isNotEmpty
                    ? Image.network(
                        imageUrls.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.image, size: 48, color: Colors.grey),
                        ),
                      )
                    : Container(
                        color: Colors.grey[100],
                        child: const Icon(Icons.inventory_2, size: 48, color: Colors.grey),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['assetName'] ?? 'Product',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item['category'] ?? '',
                              style: const TextStyle(
                                color: Color(0xFF6C63FF),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isAvailable
                              ? Colors.green.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isAvailable ? 'Available' : 'Rented',
                          style: TextStyle(
                            color: isAvailable ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Hourly & daily rates
                  Row(
                    children: [
                      _rateCard('Per Hour', '৳${hourly.toStringAsFixed(0)}'),
                      const SizedBox(width: 12),
                      _rateCard('Per Day', '৳${daily.toStringAsFixed(0)}'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (item['address'] != null &&
                      (item['address'] as String).isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.place_outlined, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item['address'],
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (distanceLabel != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.near_me_outlined, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          '$distanceLabel from you',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Booking checkout
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RentalDetailScreen(poolItem: item),
                          ),
                        );
                        _loadItems();
                      },
                      icon: const Icon(Icons.shopping_cart_checkout),
                      label: const Text(
                        'Book Now',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rateCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF6C63FF).withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF6C63FF),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _recenterOnUser() {
    final target = _userLocation ?? _defaultCenter;
    _mapController.move(target, math.max(_mapController.camera.zoom, 13));
    _locateUser();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with filter button
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Explore Nearby',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${_filtered.length} asset${_filtered.length == 1 ? '' : 's'} on the map',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _showFilterSheet,
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('Filters'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6C63FF),
                ),
              ),
            ],
          ),
        ),

        // Category chips
        SizedBox(
          height: 44,
          child: _categories.isEmpty
              ? const SizedBox.shrink()
              : ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  children: [
                    _categoryChip('All', null),
                    for (final c in _categories) _categoryChip(c, c),
                  ],
                ),
        ),

        // Map
        Expanded(
          child: Stack(
            children: [
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _userLocation ?? _defaultCenter,
                        initialZoom: 12,
                        minZoom: 3,
                        maxZoom: 19,
                        onTap: (_, __) {},
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.ekota_public',
                        ),
                        if (_userLocation != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _userLocation!,
                                width: 26,
                                height: 26,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E88E5),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        if (_filtered.isNotEmpty)
                          MarkerClusterLayerWidget(
                            options: MarkerClusterLayerOptions(
                              markers: _buildMarkers(),
                              builder: (ctx, markers) => _buildCluster(markers.length),
                              size: const Size(52, 52),
                              alignment: Alignment.center,
                              maxClusterRadius: 60,
                              disableClusteringAtZoom: 17,
                              showPolygon: false,
                              onMarkerTap: (marker) {
                                final item = _itemForPoint(marker.point);
                                if (item != null) _showItemDetails(item);
                              },
                            ),
                          ),
                      ],
                    ),
              // Recenter button
              Positioned(
                right: 14,
                bottom: 20,
                child: FloatingActionButton.small(
                  heroTag: 'map_recenter',
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF6C63FF),
                  onPressed: _recenterOnUser,
                  tooltip: 'My location',
                  child: const Icon(Icons.my_location),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _categoryChip(String label, String? value) {
    final selected = _selectedCategory == value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => _selectCategory(value),
        selectedColor: const Color(0xFF6C63FF),
        backgroundColor: Colors.grey[100],
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.grey[700],
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}