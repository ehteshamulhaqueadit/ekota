import 'package:flutter_test/flutter_test.dart';
import 'package:ekota_public/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(EkotaPublicApp());
    expect(find.byType(EkotaPublicApp), findsOneWidget);
  });
}
