import 'package:flutter_test/flutter_test.dart';
import 'package:ekota_syndicate/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(EkotaSyndicateApp());
    expect(find.byType(EkotaSyndicateApp), findsOneWidget);
  });
}
