import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../providers/listing_provider.dart';
import 'info_card.dart';

class ReviewSection extends StatefulWidget {
  const ReviewSection({super.key});
  @override
  State<ReviewSection> createState() => _ReviewSectionState();
}

class _ReviewSectionState extends State<ReviewSection> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _post(BuildContext context) async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _submitting = true);
    try {
      await context.read<ListingProvider>().addReview(text);
      _controller.clear();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ListingProvider>();
    return InfoCard(
      title: 'Reviews (${provider.reviews.length})',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (provider.reviews.isEmpty)
            const Text('No reviews yet.',
                style: TextStyle(color: Colors.grey)),
          for (final r in provider.reviews)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.black12,
                      child: Icon(Icons.person, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Text(r.investorName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text(
                      timeago.format(r.createdAt),
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 36),
                    child: Text(r.text),
                  ),
                  const Divider(height: 16),
                ],
              ),
            ),
          const SizedBox(height: 4),
          // Only investors who invested in this listing can review.
          // canReview comes from the backend — never computed client-side.
          if (provider.canReview)
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                      hintText: 'Leave a review…'),
                ),
              ),
              const SizedBox(width: 8),
              if (_submitting)
                const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))
              else
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _post(context),
                ),
            ])
          else
            const Text(
              'Only investors who have invested in this item can leave a review.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
        ],
      ),
    );
  }
}
