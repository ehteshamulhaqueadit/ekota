import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/listing_provider.dart';
import 'providers/home_stats_provider.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/add_item_screen.dart';
import 'screens/your_items_screen.dart';
import 'screens/item_details_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/otp_verification_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/reset_password_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const EkotaBuilderApp());
}

class EkotaBuilderApp extends StatelessWidget {
  const EkotaBuilderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider()..loadFromStorage(),
        ),
        ChangeNotifierProvider(create: (_) => ListingProvider()),
        ChangeNotifierProvider(create: (_) => HomeStatsProvider()),
      ],
      child: Builder(
        builder: (context) {
          final auth = context.watch<AuthProvider>();
          return MaterialApp(
            title: 'Ekota Builder',
            theme: appTheme,
            debugShowCheckedModeBanner: false,
            home: auth.isLoading
                ? const Scaffold(body: Center(child: CircularProgressIndicator()))
                : auth.isLoggedIn
                    ? const HomeScreen()
                    : const LoginScreen(),
            routes: {
              '/home': (_) => const HomeScreen(),
              '/producer/items': (_) => const YourItemsScreen(),
              '/producer/items/create': (_) => const AddItemScreen(),
              '/signup': (_) => const SignupScreen(),
              '/verify-otp': (_) => const OtpVerificationScreen(),
              '/forgot-password': (_) => const ForgotPasswordScreen(),
              '/reset-password': (_) => const ResetPasswordScreen(),
            },
            onGenerateRoute: (settings) {
              final uri = Uri.parse(settings.name ?? '');
              // /listings/:id  →  ItemDetailsScreen
              if (uri.pathSegments.length == 2 &&
                  uri.pathSegments.first == 'listings') {
                return MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider(
                    create: (_) => ListingProvider(),
                    child: ItemDetailsScreen(
                        listingId: uri.pathSegments[1]),
                  ),
                );
              }
              return null;
            },
          );
        },
      ),
    );
  }
}
