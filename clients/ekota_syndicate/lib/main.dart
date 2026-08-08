import 'package:flutter/material.dart';
import 'screens/producer_withdrawal_screen.dart';

void main() => runApp(EkotaSyndicateApp());

class EkotaSyndicateApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ekota Syndicate - Producer Portal',
      theme: ThemeData.dark().copyWith(
        primaryColor: Color(0xFF10131D),
        scaffoldBackgroundColor: Color(0xFF0A0D14),
      ),
      home: ProducerWithdrawalScreen(authToken: 'demo_producer_jwt_token'),
    );
  }
}
