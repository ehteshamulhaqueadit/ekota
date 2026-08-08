import 'package:flutter/material.dart';
import 'screens/payment_screen.dart';
import 'screens/notifications_screen.dart';

void main() => runApp(EkotaPublicApp());

class EkotaPublicApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ekota Public',
      theme: ThemeData.dark().copyWith(
        primaryColor: Color(0xFF10131D),
        scaffoldBackgroundColor: Color(0xFF0A0D14),
      ),
      home: MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  @override
  _MainNavigationScreenState createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final String _demoToken = 'demo_renter_investor_jwt_token';

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      PaymentScreen(authToken: _demoToken),
      NotificationsScreen(authToken: _demoToken),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Ekota Member Portal'),
        elevation: 0,
        backgroundColor: Color(0xFF10131D),
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.greenAccent,
        unselectedItemColor: Colors.grey,
        backgroundColor: Color(0xFF10131D),
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.payment),
            label: 'SSLCommerz Pay',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
        ],
      ),
    );
  }
}
