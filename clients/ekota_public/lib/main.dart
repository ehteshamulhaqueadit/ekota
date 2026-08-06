import 'package:flutter/material.dart';

void main() => runApp(EkotaPublicApp());

class EkotaPublicApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ekota Public',
      home: Scaffold(
        appBar: AppBar(title: Text('Ekota Public')),
        body: Center(child: Text('Ekota Public mobile app')),
      ),
    );
  }
}
