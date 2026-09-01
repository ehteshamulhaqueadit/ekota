import 'package:flutter/material.dart';
import '../models/chat_message_model.dart';
import '../services/chat_api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import 'chat_screen.dart';

class BuilderChatListScreen extends StatefulWidget {
  const BuilderChatListScreen({super.key});

  @override
  State<BuilderChatListScreen> createState() => _BuilderChatListScreenState();
}

class _BuilderChatListScreenState extends State<BuilderChatListScreen> {
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Split-Buying Chat Threads', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppColors.dark,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
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
                      'No active split-buying chat threads available.',
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
                                builder: (_) => BuilderChatScreen(thread: thread),
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
                                      backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                                      backgroundImage: thread.imageUrls.isNotEmpty
                                          ? NetworkImage(thread.imageUrls.first)
                                          : null,
                                      child: thread.imageUrls.isEmpty
                                          ? const Icon(Icons.chat_bubble_rounded, color: AppColors.accent, size: 26)
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
                                                color: AppColors.dark,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppColors.accent.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '${thread.fundingPercentage}% Funded',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.accent,
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
                                          color: AppColors.accent,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      const Row(
                                        children: [
                                          Icon(Icons.forum_outlined, size: 14, color: Colors.grey),
                                          SizedBox(width: 4),
                                          Text(
                                            'Tap to join live investor chat room',
                                            style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
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
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }
}
