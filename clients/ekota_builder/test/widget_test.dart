import 'package:flutter_test/flutter_test.dart';
import 'package:ekota_builder/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const EkotaBuilderApp());
    expect(find.byType(EkotaBuilderApp), findsOneWidget);
  });
}
