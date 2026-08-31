import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  String? userId;
  String? role; // 'producer' | 'investor' | 'renter' | 'admin'
  String? name;
  String kycStatus = 'UNVERIFIED';
  bool isEmailVerified = false;
  bool isLoading = true;

  Future<void> loadFromStorage() async {
    isLoading = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('userId');
    role = prefs.getString('role');
    name = prefs.getString('name');
    kycStatus = prefs.getString('kycStatus') ?? 'UNVERIFIED';
    isEmailVerified = prefs.getBool('isEmailVerified') ?? false;
    isLoading = false;
    notifyListeners();
  }

  Future<void> updateKycStatus(String newStatus) async {
    kycStatus = newStatus;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('kycStatus', newStatus);
    notifyListeners();
  }

  Future<void> saveSession({
    required String userId,
    required String role,
    required String name,
    required String jwt,
    String? kycStatusValue,
    bool emailVerified = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', userId);
    await prefs.setString('role', role);
    await prefs.setString('name', name);
    await prefs.setString('jwt', jwt);
    if (kycStatusValue != null) {
      await prefs.setString('kycStatus', kycStatusValue);
      kycStatus = kycStatusValue;
    }
    await prefs.setBool('isEmailVerified', emailVerified);
    isEmailVerified = emailVerified;
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
    kycStatus = 'UNVERIFIED';
    isEmailVerified = false;
    notifyListeners();
  }

  bool get isLoggedIn => userId != null;
  bool get isProducer => role == 'producer';
  bool get isInvestor => role == 'investor';
}
