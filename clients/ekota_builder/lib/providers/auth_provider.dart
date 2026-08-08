import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  String? userId;
  String? role; // 'producer' | 'investor' | 'renter' | 'admin'
  String? name;
  bool isLoading = true;

  Future<void> loadFromStorage() async {
    isLoading = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('userId');
    role = prefs.getString('role');
    name = prefs.getString('name');
    isLoading = false;
    notifyListeners();
  }

  Future<void> saveSession({
    required String userId,
    required String role,
    required String name,
    required String jwt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', userId);
    await prefs.setString('role', role);
    await prefs.setString('name', name);
    await prefs.setString('jwt', jwt);
    this.userId = userId;
    this.role = role;
    this.name = name;
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    userId = null;
    role = null;
    name = null;
    notifyListeners();
  }

  bool get isLoggedIn => userId != null;
  bool get isProducer => role == 'producer';
  bool get isInvestor => role == 'investor';
}
