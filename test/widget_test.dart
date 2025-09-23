import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/main.dart';

void main() {
  testWidgets('App startup smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // The test passes if the app starts up without crashing.
    // You can add more specific assertions here if needed.
    expect(find.byType(MyApp), findsOneWidget);
  });
}
