import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/listing_provider.dart';
import 'providers/home_stats_provider.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/add_item_screen.dart';
import 'screens/your_items_screen.dart';
import 'screens/item_details_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      child: MaterialApp(
        title: 'Ekota Builder',
        theme: appTheme,
        debugShowCheckedModeBanner: false,
        initialRoute: '/home',
        routes: {
          '/home': (_) => const HomeScreen(),
          '/producer/items': (_) => const YourItemsScreen(),
          '/producer/items/create': (_) => const AddItemScreen(),
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
      ),
    );
  }
}
