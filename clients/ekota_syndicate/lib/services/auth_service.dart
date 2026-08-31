import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_socket_service.dart';
import '../screens/login_screen.dart';

class AuthService {
  /// Safely logout authenticated user:
  /// 1. Disconnects Socket.io WebSocket connection
  /// 2. Clears SharedPreferences auth token and user state
  /// 3. Resets active socket state
  /// 4. Navigates back to LoginScreen
  static Future<void> logout(BuildContext context) async {
    try {
      // 1. Disconnect Socket.io real-time connection & clean room listeners
      ChatSocketService().dispose();

      // 2. Clear all user session keys from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_logged_in');
      await prefs.remove('auth_token');
      await prefs.remove('user_id');
      await prefs.remove('user_email');
      await prefs.remove('user_name');
      await prefs.remove('user_role');
      await prefs.clear();
    } catch (e) {
      debugPrint('Error during auth logout: $e');
    }

    // 3. Navigate back to LoginScreen and clear route stack
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }
}
