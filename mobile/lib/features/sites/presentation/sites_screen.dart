import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/paymuster_tokens.dart';

class SitesScreen extends ConsumerStatefulWidget {
  const SitesScreen({super.key});

  @override
  ConsumerState<SitesScreen> createState() => _SitesScreenState();
}

class _SitesScreenState extends ConsumerState<SitesScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgSurface = isDark ? PMColors.bgSurfaceDark : PMColors.bgSurfaceLight;
    final textColor = isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sites'),
        backgroundColor: bgSurface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: Implement Create Site
            },
          ),
        ],
      ),
      body: Center(
        child: Text(
          'Sites Module\nSite Name | Site Code | Status | Address | Worker Count | Manager | Supervisor',
          textAlign: TextAlign.center,
          style: PMTypography.title.copyWith(color: textColor),
        ),
      ),
    );
  }
}
