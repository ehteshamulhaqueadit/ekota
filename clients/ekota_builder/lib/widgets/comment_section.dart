import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/listing_provider.dart';
import 'comment_tile.dart';
import 'info_card.dart';

class CommentSection extends StatefulWidget {
  const CommentSection({super.key});
  @override
  State<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
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
      await context.read<ListingProvider>().addComment(text);
      _controller.clear();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final comments = context.watch<ListingProvider>().comments;
    return InfoCard(
      title: 'Comments (${comments.length})',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (comments.isEmpty)
            const Text('No comments yet.',
                style: TextStyle(color: Colors.grey)),
          for (final c in comments) ...[
            CommentTile(comment: c),
            const Divider(height: 1),
          ],
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration:
                    const InputDecoration(hintText: 'Add a comment…'),
              ),
            ),
            const SizedBox(width: 8),
            if (_submitting)
              const SizedBox(
                  width: 24,
                  height: 24,
                  child:
                      CircularProgressIndicator(strokeWidth: 2))
            else
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: () => _post(context),
              ),
          ]),
        ],
      ),
    );
  }
}
