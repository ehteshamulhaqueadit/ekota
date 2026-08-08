import 'package:flutter/foundation.dart';
import '../models/home_stats.dart';
import '../services/api_client.dart';

class HomeStatsProvider extends ChangeNotifier {
  final _api = ApiClient();

  HomeStats? stats;
  bool loading = false;
  String? error;

  Future<void> load(String producerId) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final data = await _api.get('/producers/$producerId/stats');
      stats = HomeStats.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
