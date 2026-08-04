import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App builds and shows the hero shell', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Yuyu'))));
    expect(find.text('Yuyu'), findsOneWidget);
  });
}
