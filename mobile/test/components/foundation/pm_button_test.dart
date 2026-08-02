import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paymuster_mobile/components/foundation/pm_button.dart';

void main() {
  group('PMButton Tests', () {
    testWidgets('renders primary button and responds to taps', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PMButton.primary(
              label: 'Test Button',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Test Button'), findsOneWidget);
      expect(find.byType(GestureDetector), findsWidgets);

      await tester.tap(find.text('Test Button'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('renders disabled button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PMButton.primary(
              label: 'Disabled',
              onPressed: null,
            ),
          ),
        ),
      );

      final button = tester.widget<PMButton>(find.byType(PMButton));
      expect(button.onPressed, isNull);
    });
  });
}
