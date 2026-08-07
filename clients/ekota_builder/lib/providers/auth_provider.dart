import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthProvider extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();

  String? userId;
  String? role; // 'producer' | 'investor' | 'renter' | 'admin'
  String? name;
  bool isLoading = true;

  Future<void> loadFromStorage() async {
    isLoading = true;
    notifyListeners();
    userId = await _storage.read(key: 'userId');
    role = await _storage.read(key: 'role');
    name = await _storage.read(key: 'name');
    isLoading = false;
    notifyListeners();
  }

  Future<void> saveSession({
    required String userId,
    required String role,
    required String name,
    required String jwt,
  }) async {
    await _storage.write(key: 'userId', value: userId);
    await _storage.write(key: 'role', value: role);
    await _storage.write(key: 'name', value: name);
    await _storage.write(key: 'jwt', value: jwt);
    this.userId = userId;
    this.role = role;
    this.name = name;
    notifyListeners();
  }

  Future<void> logout() async {
    await _storage.deleteAll();
    userId = null;
    role = null;
    name = null;
    notifyListeners();
  }

  bool get isLoggedIn => userId != null;
  bool get isProducer => role == 'producer';
  bool get isInvestor => role == 'investor';
}
