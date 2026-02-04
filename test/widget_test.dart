// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:compass/main.dart';

void main() {
  testWidgets('ShelterCompassApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ShelterCompassApp());

    // Verify that the title "Nearby Shelters" is present (it's in the AppBar).
    expect(find.text('Nearby Shelters'), findsOneWidget);

    // Verify that we start with a loading indicator or some initial state.
    // Since the app starts with _isLoading = true, we expect a CircularProgressIndicator.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
