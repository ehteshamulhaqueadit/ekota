import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'investment_marketplace_screen.dart';
import 'my_investments_screen.dart';
import 'rental_management_screen.dart';
import 'warehouse_screen.dart';
import 'live_location_screen.dart';
import 'login_screen.dart';

class SyndicateHomeScreen extends StatefulWidget {
  const SyndicateHomeScreen({super.key});

  @override
  State<SyndicateHomeScreen> createState() => _SyndicateHomeScreenState();
}

class _SyndicateHomeScreenState extends State<SyndicateHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    InvestmentMarketplaceScreen(),
    MyInvestmentsScreen(),
    RentalManagementScreen(),
    WarehouseScreen(),
    LiveLocationScreen(),
  ];

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ekota Syndicate'),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        backgroundColor: const Color(0xFF1A1A2E),
        indicatorColor: const Color(0xFF00D2FF).withOpacity(0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined, color: Colors.white70),
            selectedIcon: Icon(Icons.storefront, color: Color(0xFF00D2FF)),
            label: 'Marketplace',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined, color: Colors.white70),
            selectedIcon: Icon(Icons.account_balance_wallet, color: Color(0xFF00D2FF)),
            label: 'Portfolio',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_horiz_outlined, color: Colors.white70),
            selectedIcon: Icon(Icons.swap_horiz, color: Color(0xFF00D2FF)),
            label: 'Rentals',
          ),
          NavigationDestination(
            icon: Icon(Icons.warehouse_outlined, color: Colors.white70),
            selectedIcon: Icon(Icons.warehouse, color: Color(0xFF00D2FF)),
            label: 'Warehouse',
          ),
          NavigationDestination(
            icon: Icon(Icons.location_on_outlined, color: Colors.white70),
            selectedIcon: Icon(Icons.location_on, color: Color(0xFF00D2FF)),
            label: 'Location',
          ),
        ],
      ),
    );
  }
}
