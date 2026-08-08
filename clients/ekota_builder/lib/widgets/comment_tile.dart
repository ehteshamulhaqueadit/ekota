import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/comment.dart';
import '../providers/auth_provider.dart';
import '../providers/listing_provider.dart';

class CommentTile extends StatefulWidget {
  final Comment comment;
  const CommentTile({super.key, required this.comment});

  @override
  State<CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<CommentTile> {
  bool _replying = false;
  final _replyController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _sendReply(BuildContext context) async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    setState(() => _submitting = true);
    try {
      await context
          .read<ListingProvider>()
          .addReply(widget.comment.id, text);
      if (mounted) setState(() => _replying = false);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isProducer = context.watch<AuthProvider>().isProducer;
    final c = widget.comment;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author + timestamp
          Row(
            children: [
              const CircleAvatar(
                radius: 14,
                backgroundColor: Colors.black12,
                child: Icon(Icons.person, size: 16),
              ),
              const SizedBox(width: 8),
              Text(c.authorName,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(
                timeago.format(c.createdAt),
                style:
                    const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Text(c.text),
          ),

          // Producer reply bubble
          if (c.reply != null)
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 6),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Producer reply',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(c.reply!.text),
                  ],
                ),
              ),
            ),

          // Reply UI (producer only, if no reply yet)
          if (isProducer && c.reply == null)
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 4),
              child: _replying
                  ? Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _replyController,
                          autofocus: true,
                          decoration: const InputDecoration(
                              hintText: 'Write a reply…'),
                        ),
                      ),
                      if (_submitting)
                        const Padding(
                          padding: EdgeInsets.all(8),
                          child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2)),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.send, size: 18),
                          onPressed: () => _sendReply(context),
                        ),
                    ])
                  : TextButton.icon(
                      onPressed: () => setState(() => _replying = true),
                      icon: const Icon(Icons.reply, size: 16),
                      label: const Text('Reply'),
                    ),
            ),
        ],
      ),
    );
  }
}
