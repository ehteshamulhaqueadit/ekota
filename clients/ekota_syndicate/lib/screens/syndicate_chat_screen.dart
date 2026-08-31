import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message_model.dart';
import '../services/chat_api_service.dart';
import '../services/chat_socket_service.dart';
import '../services/auth_service.dart';
import '../utils/device_file_picker.dart';

class SyndicateChatScreen extends StatefulWidget {
  final SyndicateThreadModel thread;

  const SyndicateChatScreen({super.key, required this.thread});

  @override
  State<SyndicateChatScreen> createState() => _SyndicateChatScreenState();
}

class _SyndicateChatScreenState extends State<SyndicateChatScreen> {
  final ChatApiService _apiService = ChatApiService();
  final ChatSocketService _socketService = ChatSocketService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessageModel> _messages = [];
  bool _isLoadingHistory = true;
  bool _isConnected = false;
  bool _userHasScrolled = false;
  String _currentUserEmail = '';
  String? _currentUserId;
  String? _currentUserName;
  String? _authToken;

  String? _selectedFileName;
  Uint8List? _selectedFileBytes;
  bool _isUploadingAttachment = false;

  StreamSubscription? _messageSubscription;
  StreamSubscription? _connSubscription;

  late double _currentFunding;
  late int _fundingPercentage;

  @override
  void initState() {
    super.initState();
    _currentFunding = widget.thread.currentFunding;
    _fundingPercentage = widget.thread.fundingPercentage;
    _initChatSession();
  }

  Future<void> _initChatSession() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id');
    _currentUserEmail = prefs.getString('user_email') ?? '';
    _currentUserName = prefs.getString('user_name') ?? '';
    _authToken = prefs.getString('auth_token') ?? 'dev-token';

    // 1. Fetch persisted chat history from PostgreSQL
    final history = await _apiService.fetchChatHistory(widget.thread.id);
    if (mounted) {
      setState(() {
        _messages = history;
        _isLoadingHistory = false;
      });
      _scrollToBottom();
    }

    // 2. Initialize Socket.io connection & join syndicate room
    _socketService.initSocket(
      token: _authToken!,
      listingId: widget.thread.id,
    );

    _isConnected = _socketService.isConnected;

    // Listen to real-time incoming messages
    _messageSubscription = _socketService.onMessageReceived.listen((msg) {
      if (msg.listingId == widget.thread.id) {
        if (mounted) {
          setState(() {
            _messages.add(msg);

            // Update funding progress card dynamically if system message contains progress metadata
            if (msg.type == 'SYSTEM' && msg.metadata != null) {
              if (msg.metadata!['fundingPercentage'] != null) {
                _fundingPercentage = (msg.metadata!['fundingPercentage'] as num).toInt();
              }
              if (msg.metadata!['totalRaised'] != null) {
                _currentFunding = (msg.metadata!['totalRaised'] as num).toDouble();
              }
            }
          });

          _scrollToBottom();
        }
      }
    });

    // Listen to connection state changes
    _connSubscription = _socketService.onConnectionStateChanged.listen((connected) {
      if (mounted) {
        setState(() {
          _isConnected = connected;
        });
      }
    });
  }

  void _scrollToBottom({bool force = false}) {
    if (_userHasScrolled && !force) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _clearSelectedAttachment() {
    setState(() {
      _selectedFileName = null;
      _selectedFileBytes = null;
    });
  }

  Future<void> _handleAttachMedia() async {
    try {
      final picked = await pickDeviceFile();
      if (picked != null && picked.bytes.isNotEmpty) {
        setState(() {
          _selectedFileName = picked.name;
          _selectedFileBytes = picked.bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting file: $e')),
        );
      }
    }
  }

  Future<void> _handleSendMessage({String type = 'TEXT', String? mediaUrl}) async {
    if (_isUploadingAttachment) return;

    // Handle sending selected attachment if present
    if (_selectedFileBytes != null && _selectedFileName != null && mediaUrl == null) {
      setState(() {
        _isUploadingAttachment = true;
      });

      final uploadedUrl = await _apiService.uploadMedia(
        fileName: _selectedFileName!,
        bytes: _selectedFileBytes!,
      );

      if (!mounted) return;

      if (uploadedUrl != null) {
        final text = _messageController.text.trim();

        _socketService.sendMessage(
          listingId: widget.thread.id,
          content: text,
          type: 'MEDIA',
          mediaUrl: uploadedUrl,
        );

        _messageController.clear();
        setState(() {
          _selectedFileName = null;
          _selectedFileBytes = null;
          _isUploadingAttachment = false;
          _userHasScrolled = false;
        });

        _scrollToBottom(force: true);
        return;
      } else {
        setState(() {
          _isUploadingAttachment = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload file. Please try again.')),
        );
        return;
      }
    }

    final text = _messageController.text.trim();
    if (text.isEmpty && mediaUrl == null) return;

    _socketService.sendMessage(
      listingId: widget.thread.id,
      content: text,
      type: type,
      mediaUrl: mediaUrl,
    );

    _messageController.clear();
    _userHasScrolled = false;
    _scrollToBottom(force: true);
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _connSubscription?.cancel();
    _socketService.leaveRoom(widget.thread.id);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.thread.assetName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              children: [
                Text(
                  widget.thread.category,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _isConnected
                        ? const Color(0xFF10B981).withValues(alpha: 0.2)
                        : Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 3,
                        backgroundColor: _isConnected ? const Color(0xFF10B981) : Colors.amber,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isConnected ? 'Connected' : 'Connecting...',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _isConnected ? const Color(0xFF34D399) : Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () => AuthService.logout(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Funding Progress Context Card (Single Source of Truth)
          _buildFundingProgressCard(),

          // Connection warning banner if offline
          if (!_isConnected)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              color: const Color(0xFFFEF3C7),
              child: const Row(
                children: [
                  Icon(Icons.wifi_off, size: 16, color: Color(0xFFB45309)),
                  SizedBox(width: 8),
                  Text(
                    'Reconnecting to syndicate chat...',
                    style: TextStyle(fontSize: 12, color: Color(0xFFB45309), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

          // 2. Chat Messages Timeline
          Expanded(
            child: _isLoadingHistory
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification is ScrollStartNotification && notification.dragDetails != null) {
                            _userHasScrolled = true;
                          }
                          return false;
                        },
                        child: ListView.builder(
                          key: const PageStorageKey('syndicate_chat_messages_scroll'),
                          controller: _scrollController,
                          physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            if (msg.type == 'SYSTEM') {
                              return _buildSystemMessageTile(msg);
                            }

                            final isMe = (msg.senderId != null && _currentUserId != null && msg.senderId == _currentUserId) ||
                                (_currentUserName != null && _currentUserName!.isNotEmpty && msg.senderName == _currentUserName) ||
                                (_currentUserEmail.isNotEmpty &&
                                    msg.senderName.isNotEmpty &&
                                    _currentUserEmail.toLowerCase().contains(msg.senderName.toLowerCase().split(' ')[0]));

                            return _buildMessageTile(msg, isMe);
                          },
                        ),
                      ),
          ),

          // 3. Message Input Bar
          _buildMessageInputBar(),
        ],
      ),
    );
  }

  Widget _buildFundingProgressCard() {
    final target = widget.thread.fundingTarget;
    final progress = (_currentFunding / target).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'FUNDING PROGRESS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Color(0xFF64748B),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Text(
                  '$_fundingPercentage% funded',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF047857),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '৳${_currentFunding.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} Raised',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              Text(
                'Target: ৳${target.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} BDT',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSystemMessageTile(ChatMessageModel msg) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Container(height: 1, color: const Color(0xFFCBD5E1))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.show_chart, size: 14, color: Color(0xFF1D4ED8)),
                      const SizedBox(width: 6),
                      Text(
                        msg.content,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(child: Container(height: 1, color: const Color(0xFFCBD5E1))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageTile(ChatMessageModel msg, bool isMe) {
    final timeStr = DateFormat('hh:mm a').format(msg.createdAt);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: isMe ? null : Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  msg.senderName,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),

            if (msg.type == 'MEDIA' && msg.mediaUrl != null)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.black12,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    msg.mediaUrl!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      padding: const EdgeInsets.all(12),
                      color: const Color(0xFFF1F5F9),
                      child: const Row(
                        children: [
                          Icon(Icons.insert_drive_file, color: Color(0xFF2563EB)),
                          SizedBox(width: 8),
                          Text('Shared Attachment Document', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            if (msg.content.isNotEmpty)
              Text(
                msg.content,
                style: TextStyle(
                  fontSize: 14,
                  color: isMe ? Colors.white : const Color(0xFF0F172A),
                ),
              ),

            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                timeStr,
                style: TextStyle(
                  fontSize: 10,
                  color: isMe ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          const Text(
            'No messages yet in this syndicate thread.',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Start the discussion with prospective co-owners.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInputBar() {
    final isImage = _selectedFileName != null &&
        (_selectedFileName!.toLowerCase().endsWith('.jpg') ||
            _selectedFileName!.toLowerCase().endsWith('.jpeg') ||
            _selectedFileName!.toLowerCase().endsWith('.png') ||
            _selectedFileName!.toLowerCase().endsWith('.gif') ||
            _selectedFileName!.toLowerCase().endsWith('.webp'));

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Selected attachment preview bar (Facebook Messenger style)
            if (_selectedFileName != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFFF1F5F9),
                child: Row(
                  children: [
                    if (isImage && _selectedFileBytes != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.memory(
                          Uint8List.fromList(_selectedFileBytes!),
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      const Icon(Icons.insert_drive_file, color: Color(0xFF2563EB), size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedFileName!,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Text(
                            'Ready to send attachment',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    if (_isUploadingAttachment)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                        onPressed: _clearSelectedAttachment,
                        tooltip: 'Remove attachment',
                      ),
                  ],
                ),
              ),

            // Input Control Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file, color: Color(0xFF2563EB)),
                    onPressed: _isUploadingAttachment ? null : _handleAttachMedia,
                    tooltip: 'Attach photo or document',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      enabled: !_isUploadingAttachment,
                      decoration: InputDecoration(
                        hintText: _selectedFileName != null ? 'Add a caption (optional)...' : 'Type a message...',
                        hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Color(0xFF2563EB)),
                        ),
                      ),
                      onSubmitted: (_) => _handleSendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: const Color(0xFF0F172A),
                    child: _isUploadingAttachment
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : IconButton(
                            icon: const Icon(Icons.send, color: Colors.white, size: 18),
                            onPressed: () => _handleSendMessage(),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
