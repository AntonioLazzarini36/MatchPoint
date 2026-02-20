// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_point/app/app.dart';

void main() {
  testWidgets('MatchPointApp builds correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const MatchPointApp());
    await tester.pump();

    // Verifica que la app se renderiza
    expect(find.byType(MatchPointApp), findsOneWidget);  });
}
