import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/listing.dart';
import '../providers/listing_provider.dart';
import '../theme/app_colors.dart';

class VoteRow extends StatelessWidget {
  const VoteRow({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ListingProvider>();
    final listing = provider.listing!;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _VoteButton(
          icon: Icons.thumb_up_outlined,
          activeIcon: Icons.thumb_up,
          count: listing.upvotes,
          isActive: listing.myVote == VoteType.up,
          activeColor: AppColors.upvoteActive,
          onTap: () => context.read<ListingProvider>().vote(
                listing.myVote == VoteType.up
                    ? VoteType.none
                    : VoteType.up,
              ),
        ),
        const SizedBox(width: 24),
        _VoteButton(
          icon: Icons.thumb_down_outlined,
          activeIcon: Icons.thumb_down,
          count: listing.downvotes,
          isActive: listing.myVote == VoteType.down,
          activeColor: AppColors.downvoteActive,
          onTap: () => context.read<ListingProvider>().vote(
                listing.myVote == VoteType.down
                    ? VoteType.none
                    : VoteType.down,
              ),
        ),
      ],
    );
  }
}

class _VoteButton extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final int count;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _VoteButton({
    required this.icon,
    required this.activeIcon,
    required this.count,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? activeColor : Colors.grey,
              size: 26,
            ),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isActive ? activeColor : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
