import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/chat_message_model.dart';
import '../config/app_config.dart';

class ChatSocketService {
  static final ChatSocketService _instance = ChatSocketService._internal();
  factory ChatSocketService() => _instance;
  ChatSocketService._internal();

  IO.Socket? _socket;
  String? _activeListingId;
  String? _authToken;
  String? get authToken => _authToken;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  final StreamController<ChatMessageModel> _messageStreamController =
      StreamController<ChatMessageModel>.broadcast();
  Stream<ChatMessageModel> get onMessageReceived => _messageStreamController.stream;

  final StreamController<bool> _connectionStateController =
      StreamController<bool>.broadcast();
  Stream<bool> get onConnectionStateChanged => _connectionStateController.stream;

  final Set<String> _processedMessageIds = {};

  void initSocket({required String token, required String listingId}) {
    _authToken = token;
    _activeListingId = listingId;

    if (_socket != null) {
      if (_socket!.connected) {
        _joinRoom(listingId);
        return;
      } else {
        _socket!.disconnect();
        _socket!.dispose();
      }
    }

    // Connect to Express Socket.io backend
    final socketUrl = AppConfig.apiBaseUrl.replaceAll('/api', '');

    _socket = IO.io(
      socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .build(),
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      _connectionStateController.add(true);
      if (_activeListingId != null) {
        _joinRoom(_activeListingId!);
      }
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      _connectionStateController.add(false);
    });

    _socket!.onConnectError((data) {
      _isConnected = false;
      _connectionStateController.add(false);
    });

    _socket!.on('new_message', (data) {
      if (data is Map<String, dynamic>) {
        final msg = ChatMessageModel.fromJson(data);
        // Prevent duplicate message rendering
        if (!_processedMessageIds.contains(msg.id)) {
          _processedMessageIds.add(msg.id);
          _messageStreamController.add(msg);
        }
      }
    });

    _socket!.connect();
  }

  void _joinRoom(String listingId) {
    if (_socket != null && _socket!.connected) {
      _activeListingId = listingId;
      _socket!.emit('join_room', {'listingId': listingId});
    }
  }

  void sendMessage({
    required String listingId,
    required String content,
    String type = 'TEXT',
    String? mediaUrl,
  }) {
    if (_socket != null && _socket!.connected) {
      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      _socket!.emit('send_message', {
        'listingId': listingId,
        'content': content,
        'type': type,
        'mediaUrl': mediaUrl,
        'tempId': tempId,
      });
    }
  }

  void leaveRoom(String listingId) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('leave_room', {'listingId': listingId});
    }
    if (_activeListingId == listingId) {
      _activeListingId = null;
    }
  }

  void dispose() {
    if (_activeListingId != null) {
      leaveRoom(_activeListingId!);
    }
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _processedMessageIds.clear();
  }
}
