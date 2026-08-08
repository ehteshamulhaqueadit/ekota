import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/notification_model.dart';

class NotificationService {
  final String baseUrl;

  NotificationService({String? customUrl}) : baseUrl = customUrl ?? ApiConfig.notificationApiUrl;

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
