import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/listing.dart';
import '../providers/auth_provider.dart';
import '../services/listing_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';

class YourItemsScreen extends StatefulWidget {
  const YourItemsScreen({super.key});

  @override
  State<YourItemsScreen> createState() => _YourItemsScreenState();
}

class _YourItemsScreenState extends State<YourItemsScreen> {
  late Future<List<Listing>> _future;

  @override
  void initState() {
    super.initState();
    _loadListings();
  }

  void _loadListings() {
    final producerId = context.read<AuthProvider>().userId ?? '';
    _future = ListingService().getMyListings(producerId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Items')),
      body: RefreshIndicator(
        onRefresh: () async => setState(() => _loadListings()),
        child: FutureBuilder<List<Listing>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 8),
                    Text(snap.error.toString(),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          setState(() => _loadListings()),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            final items = snap.data!;
            if (items.isEmpty) {
              return const Center(
                child: Text(
                  'No items yet.\nTap + to add your first listing.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: items.length,
              itemBuilder: (context, i) => _ListingCard(listing: items[i]),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        shape: const CircleBorder(),
        onPressed: () =>
            Navigator.pushNamed(context, '/producer/items/create'),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
    );
  }
}

class _ListingCard extends StatelessWidget {
  final Listing listing;
  const _ListingCard({required this.listing});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          Navigator.pushNamed(context, '/listings/${listing.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: listing.imageUrls.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: listing.imageUrls.first,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(height: 150, color: Colors.black12),
                      errorWidget: (_, __, ___) => Container(
                          height: 150,
                          color: Colors.black12,
                          child: const Icon(Icons.broken_image,
                              color: Colors.grey)),
                    )
                  : Container(
                      height: 150,
                      color: Colors.black12,
                      child: const Icon(Icons.image_not_supported,
                          color: Colors.grey, size: 40),
                    ),
            ),
            // Details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(listing.assetName,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(children: [
                    _badge(listing.status),
                    const SizedBox(width: 6),
                    _badge(listing.campaignStatus),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.thumb_up_outlined,
                        size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text('${listing.upvotes}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                    const SizedBox(width: 12),
                    const Icon(Icons.people_outline,
                        size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text('${listing.investorCount} investors',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
    );
  }
}
