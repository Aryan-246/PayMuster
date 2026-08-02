import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paymuster_mobile/components/foundation/pm_text_input.dart';

void main() {
  group('PMTextInput Tests', () {
    testWidgets('renders input and accepts text', (WidgetTester tester) async {
      String changedValue = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PMTextInput(
              hintText: 'Search...',
              onChanged: (val) => changedValue = val,
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search...'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Test query');
      await tester.pump();

      expect(changedValue, 'Test query');
    });
  });
}
