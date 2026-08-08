import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/notification_model.dart';

String get defaultNotificationApiUrl {
  if (!kIsWeb && Platform.isAndroid) {
    return 'http://10.0.2.2:5000/api/notifications';
  }
  return 'http://localhost:5000/api/notifications';
}

class NotificationService {
  final String baseUrl;

  NotificationService({String? baseUrl}) : baseUrl = baseUrl ?? defaultNotificationApiUrl;

  Future<List<NotificationModel>> fetchNotifications(String token) async {
    try {
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List list = data['notifications'] ?? [];
        return list.map((item) => NotificationModel.fromJson(item)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<bool> markAllAsRead(String token) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/read-all'),
        headers: {'Authorization': 'Bearer $token'},
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
