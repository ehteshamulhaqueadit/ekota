import 'package:flutter/material.dart';
import '../models/chat_message_model.dart';
import '../services/chat_api_service.dart';
import '../theme/app_theme.dart';
import 'syndicate_chat_screen.dart';

class SyndicateChatListScreen extends StatefulWidget {
  const SyndicateChatListScreen({super.key});

  @override
  State<SyndicateChatListScreen> createState() => _SyndicateChatListScreenState();
}

class _SyndicateChatListScreenState extends State<SyndicateChatListScreen> {
  final ChatApiService _apiService = ChatApiService();
  List<SyndicateThreadModel> _threads = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThreads();
  }

  Future<void> _loadThreads() async {
    setState(() => _isLoading = true);
    final threads = await _apiService.fetchThreads();
    if (mounted) {
      setState(() {
        _threads = threads;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Syndicate Chat Channels'),
        backgroundColor: AppTheme.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadThreads,
            tooltip: 'Refresh Channels',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadThreads,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _threads.isEmpty
                ? const Center(
                    child: Text(
                      'No active syndicate chat channels available.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _threads.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final thread = _threads[index];
                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SyndicateChatScreen(thread: thread),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 28,
                                      backgroundColor: AppTheme.accent.withValues(alpha: 0.15),
                                      backgroundImage: thread.imageUrls.isNotEmpty
                                          ? NetworkImage(thread.imageUrls.first)
                                          : null,
                                      child: thread.imageUrls.isEmpty
                                          ? const Icon(Icons.chat_bubble_rounded, color: AppTheme.accent, size: 26)
                                          : null,
                                    ),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 14,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              thread.assetName,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.textPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppTheme.accent.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '${thread.fundingPercentage}% Funded',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.accent,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Producer: ${thread.producerName}',
                                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                                      ),
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: (thread.fundingPercentage / 100).clamp(0.0, 1.0),
                                          minHeight: 5,
                                          backgroundColor: Colors.grey.shade200,
                                          color: AppTheme.accent,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: const [
                                          Icon(Icons.forum_outlined, size: 14, color: AppTheme.textSecondary),
                                          SizedBox(width: 4),
                                          Text(
                                            'Tap to join live investor chat room',
                                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
