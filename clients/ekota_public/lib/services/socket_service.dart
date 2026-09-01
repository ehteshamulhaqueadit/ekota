import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';
import '../config/app_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? socket;

  Future<void> connectAndAuthenticate() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null || token.isEmpty) return;

    // We need the user's ID to authenticate with the socket.
    // Fetch user profile to get ID
    String? userId;
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/auth/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        userId = data['id'];
      }
    } catch (e) {
      debugPrint('Failed to get user profile for socket: $e');
    }

    if (userId == null) return;

    // Use the base URL, remove api suffix if present
    final baseUrl = AppConfig.apiBaseUrl.replaceAll('/api', '');

    socket = IO.io(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket?.connect();

    socket?.onConnect((_) {
      debugPrint('[Socket] Connected');
      socket?.emit('authenticate', userId);
    });

    socket?.on('watchlistAlert', (data) {
      debugPrint('[Socket] Watchlist Alert received: $data');
      if (data != null && data['title'] != null && data['body'] != null) {
        NotificationService.showNotification(
          id: data['listingId']?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
          title: data['title'],
          body: data['body'],
          payload: data['listingId'],
        );
      }
    });

    socket?.onDisconnect((_) {
      debugPrint('[Socket] Disconnected');
    });
  }

  void disconnect() {
    socket?.disconnect();
    socket = null;
  }
}
