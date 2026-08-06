import 'package:flutter/material.dart';

void main() => runApp(EkotaSyndicateApp());

class EkotaSyndicateApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ekota Syndicate',
      home: Scaffold(
        appBar: AppBar(title: Text('Ekota Syndicate')),
        body: Center(child: Text('Ekota Syndicate mobile app')),
      ),
    );
  }
}
