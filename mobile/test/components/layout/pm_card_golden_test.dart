import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:paymuster_mobile/components/layout/pm_card.dart';
import 'package:paymuster_mobile/theme/paymuster_theme.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
  });

  group('PMCard Golden Tests', () {
    testGoldens('PMCard standard light and dark', (tester) async {
      final builder = GoldenBuilder.column()
        ..addScenario(
          'Light Theme',
          ThemeProvider(
            theme: PayMusterTheme.lightTheme(),
            child: PMCard.standard(child: const Text('Card Content')),
          ),
        )
        ..addScenario(
          'Dark Theme',
          ThemeProvider(
            theme: PayMusterTheme.darkTheme(),
            child: PMCard.standard(child: const Text('Card Content')),
          ),
        );

      await tester.pumpWidgetBuilder(builder.build());
      await screenMatchesGolden(tester, 'pm_card_golden');
    });
  });
}

class ThemeProvider extends StatelessWidget {
  final ThemeData theme;
  final Widget child;

  const ThemeProvider({super.key, required this.theme, required this.child});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: theme,
      child: Container(
        color: theme.scaffoldBackgroundColor,
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}
