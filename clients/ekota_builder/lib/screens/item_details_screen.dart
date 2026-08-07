import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/listing_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/media_carousel.dart';
import '../widgets/production_time_badge.dart';
import '../widgets/vote_row.dart';
import '../widgets/info_card.dart';
import '../widgets/comment_section.dart';
import '../widgets/review_section.dart';
import '../widgets/app_bottom_nav.dart';

class ItemDetailsScreen extends StatefulWidget {
  final String listingId;
  const ItemDetailsScreen({super.key, required this.listingId});

  @override
  State<ItemDetailsScreen> createState() => _ItemDetailsScreenState();
}

class _ItemDetailsScreenState extends State<ItemDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ListingProvider>().loadListing(widget.listingId);
    });
  }

  @override
  void dispose() {
    // Reset so the next listing opens fresh
    context.read<ListingProvider>().reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ListingProvider>();
    final listing = provider.listing;

    return Scaffold(
      appBar: AppBar(title: const Text('Item Details')),
      body: provider.loading
          ? const Center(child: CircularProgressIndicator())
          : provider.error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 8),
                      Text(provider.error!,
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => context
                            .read<ListingProvider>()
                            .loadListing(widget.listingId),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : listing == null
                  ? const SizedBox.shrink()
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        // Media
                        MediaCarousel(
                            imageUrls: listing.imageUrls,
                            videoUrls: listing.videoUrls),
                        const SizedBox(height: 16),

                        // Title
                        Text(
                          listing.assetName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),

                        // Campaign status
                        Center(
                          child: Text(
                            'Campaign: ${listing.campaignStatus}',
                            style: const TextStyle(
                                color: AppColors.textMuted),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Production time badge
                        Center(
                          child: ProductionTimeBadge(
                            type: listing.productionTimeType,
                            days: listing.productionDays,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Vote row
                        const Center(child: VoteRow()),
                        const SizedBox(height: 20),

                        // Funding progress
                        InfoCard(
                          title: 'Funding Progress',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: listing.fundingProgressPercent /
                                      100,
                                  minHeight: 8,
                                  backgroundColor: Colors.black12,
                                  color: AppColors.accent,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${listing.fundingProgressPercent.toStringAsFixed(0)}% funded  •  Target: ৳${listing.fundingTarget.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 13),
                              ),
                            ],
                          ),
                        ),

                        // Investors
                        InfoCard(
                          title: 'Investors',
                          child: Text(
                              '${listing.investorCount} investor${listing.investorCount == 1 ? '' : 's'}'),
                        ),

                        // Specifications
                        if (listing.specifications.isNotEmpty)
                          InfoCard(
                            title: 'Specifications',
                            child: Text(listing.specifications),
                          ),

                        // Description
                        InfoCard(
                          title: 'Description',
                          child: Text(listing.description),
                        ),

                        const SizedBox(height: 8),

                        // Comments
                        const CommentSection(),

                        // Reviews
                        const ReviewSection(),

                        const SizedBox(height: 20),
                      ],
                    ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
    );
  }
}
