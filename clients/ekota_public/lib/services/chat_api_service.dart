import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/chat_message_model.dart';

class ChatApiService {
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<List<SyndicateThreadModel>> fetchThreads() async {
    try {
      final token = await _getToken();
      final url = Uri.parse('${AppConfig.apiBaseUrl}/chat/threads');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token ?? 'dev-token'}',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['threads'] is List) {
          return (data['threads'] as List)
              .map((json) => SyndicateThreadModel.fromJson(json))
              .toList();
        }
      }
      return _getFallbackThreads();
    } catch (_) {
      return _getFallbackThreads();
    }
  }

  Future<List<ChatMessageModel>> fetchChatHistory(String listingId) async {
    try {
      final token = await _getToken();
      final url = Uri.parse('${AppConfig.apiBaseUrl}/chat/history/$listingId');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token ?? 'dev-token'}',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['messages'] is List) {
          return (data['messages'] as List)
              .map((json) => ChatMessageModel.fromJson(json))
              .toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<String?> uploadMedia({required String fileName, required List<int> bytes}) async {
    try {
      final token = await _getToken();
      final url = Uri.parse('${AppConfig.apiBaseUrl}/chat/upload');
      final base64String = base64Encode(bytes);

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token ?? 'dev-token'}',
        },
        body: jsonEncode({
          'fileName': fileName,
          'base64Data': base64String,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['mediaUrl'] != null) {
          return data['mediaUrl'];
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  List<SyndicateThreadModel> _getFallbackThreads() {
    return [
      SyndicateThreadModel(
        id: '20000000-0000-0000-0000-000000000001',
        assetName: 'Automatic Rice Harvester 5000',
        category: 'Agricultural Machinery',
        fundingTarget: 250000,
        rentalPrice: 1500,
        currentFunding: 187500,
        fundingPercentage: 75,
        imageUrls: ['https://images.unsplash.com/photo-1592982537447-7440770cbfc9'],
        producerName: 'Karim Agro',
        status: 'active',
      ),
      SyndicateThreadModel(
        id: '20000000-0000-0000-0000-000000000002',
        assetName: 'Solar Powered Cold Storage Facility',
        category: 'Storage & Logistics',
        fundingTarget: 500000,
        rentalPrice: 3000,
        currentFunding: 300000,
        fundingPercentage: 60,
        imageUrls: ['https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d'],
        producerName: 'Amina Organic Farms',
        status: 'active',
      ),
    ];
  }
}
