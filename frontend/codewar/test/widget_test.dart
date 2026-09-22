import 'package:flutter_test/flutter_test.dart';

import 'package:codewar/main.dart';

void main() {
  testWidgets('App boots and shows World Map', (WidgetTester tester) async {
    await tester.pumpWidget(const CodeWarApp());
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Sector Path'), findsWidgets);
  });
}
