import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const EkotaSyndicateApp());
}

class EkotaSyndicateApp extends StatefulWidget {
  const EkotaSyndicateApp({super.key});

  @override
  State<EkotaSyndicateApp> createState() => _EkotaSyndicateAppState();
}

class _EkotaSyndicateAppState extends State<EkotaSyndicateApp> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ekota Syndicate',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      home: _isLoading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _isLoggedIn
              ? const SyndicateHomeScreen()
              : const LoginScreen(),
    );
  }
}
