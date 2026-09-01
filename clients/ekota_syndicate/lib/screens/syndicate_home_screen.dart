import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'investment_marketplace_screen.dart';
import 'my_investments_screen.dart';
import 'rental_management_screen.dart';
import 'warehouse_screen.dart';
import 'live_location_screen.dart';
import 'wallet_screen.dart';
import 'syndicate_chat_list_screen.dart';
import 'login_screen.dart';

class SyndicateHomeScreen extends StatefulWidget {
  const SyndicateHomeScreen({super.key});

  @override
  State<SyndicateHomeScreen> createState() => _SyndicateHomeScreenState();
}

class _SyndicateHomeScreenState extends State<SyndicateHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    InvestmentMarketplaceScreen(), // 0: Marketplace
    LiveLocationScreen(),          // 1: Location
    RentalManagementScreen(),      // 2: Rentals
    SyndicateChatListScreen(),     // 3: Syndicate Chat
    WalletScreen(),                // 4: Wallet
    MyInvestmentsScreen(),         // 5: Portfolio
    WarehouseScreen(),             // 6: Warehouse
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
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () {
              setState(() => _currentIndex = 3); // Switch to Syndicate Chat tab
            },
            tooltip: 'Syndicate Chat',
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            onPressed: () {
              setState(() => _currentIndex = 4); // Switch to Wallet tab
            },
            tooltip: 'My Wallet',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1A1A2E),
        selectedItemColor: const Color(0xFF00D2FF),
        unselectedItemColor: Colors.white70,
        selectedFontSize: 12,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront_outlined),
            activeIcon: Icon(Icons.storefront),
            label: 'Marketplace',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.location_on_outlined),
            activeIcon: Icon(Icons.location_on),
            label: 'Location',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.swap_horiz_outlined),
            activeIcon: Icon(Icons.swap_horiz),
            label: 'Rentals',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Syndicate Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: 'Wallet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart_outline),
            activeIcon: Icon(Icons.pie_chart),
            label: 'Portfolio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.warehouse_outlined),
            activeIcon: Icon(Icons.warehouse),
            label: 'Warehouse',
          ),
        ],
      ),
    );
  }
}
