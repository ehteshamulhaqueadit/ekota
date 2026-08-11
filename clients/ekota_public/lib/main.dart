import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'config/app_config.dart';
import 'services/notification_service.dart';
import 'screens/login_screen.dart';
import 'screens/public_home_screen.dart';

export 'screens/public_home_screen.dart';

/// Handles FCM messages while the app is in the background or terminated.
/// This must be a top-level function.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await NotificationService.init();
  await NotificationService.showNotification(
    id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
    title: message.notification?.title ?? 'Ekota Alert',
    body: message.notification?.body ?? '',
    payload: message.data['listingId'],
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp();
  await NotificationService.init();

  // Set background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const EkotaPublicApp());
}

class EkotaPublicApp extends StatefulWidget {
  const EkotaPublicApp({super.key});

  @override
  State<EkotaPublicApp> createState() => _EkotaPublicAppState();
}

class _EkotaPublicAppState extends State<EkotaPublicApp> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSession();
    });

    // Handle foreground FCM messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        NotificationService.showNotification(
          id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
          title: message.notification!.title ?? 'Ekota Alert',
          body: message.notification!.body ?? '',
          payload: message.data['listingId'],
        );
      }
    });
  }

  Future<void> _checkSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      final bool loggedIn = prefs.getBool('is_logged_in') ?? false;
      final String token = prefs.getString('auth_token') ?? '';

      if (loggedIn && token.isNotEmpty) {
        // Register the real FCM token with the backend
        _registerFcmToken(token);
      }

      setState(() {
        _isLoggedIn = loggedIn;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _registerFcmToken(String authToken) async {
    try {
      // Request permission first (important for iOS, optional prompt on Android 13+)
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) return;

      debugPrint('[FCM] Token: $fcmToken');

      await http.put(
        Uri.parse('${AppConfig.apiBaseUrl}/auth/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'fcmToken': fcmToken}),
      );
      debugPrint('[FCM] Token registered with backend');
    } catch (e) {
      debugPrint('[FCM] Failed to register token: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ekota Public',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C63FF)),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: _isLoading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _isLoggedIn
              ? const PublicHomeScreen()
              : const LoginScreen(),
    );
  }
}
