import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paymuster_mobile/components/layout/pm_card.dart';

void main() {
  group('PMCard Tests', () {
    testWidgets('renders standard card with child', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PMCard.standard(
              child: const Text('Card Content'),
            ),
          ),
        ),
      );

      expect(find.text('Card Content'), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
    });
  });
}
