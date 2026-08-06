import 'package:flutter/material.dart';

void main() => runApp(EkotaBuilderApp());

class EkotaBuilderApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ekota Builder',
      home: Scaffold(
        appBar: AppBar(title: Text('Ekota Builder')),
        body: Center(child: Text('Ekota Builder mobile app')),
      ),
    );
  }
}
