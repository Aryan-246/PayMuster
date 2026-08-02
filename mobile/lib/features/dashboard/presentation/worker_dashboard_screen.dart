import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/paymuster_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';

class WorkerDashboardScreen extends ConsumerWidget {
  const WorkerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : PMColors.textPrimaryLight;
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: isDark ? PMColors.bgPrimaryDark : PMColors.bgPrimaryLight,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // Simulated refresh
            await Future.delayed(const Duration(seconds: 1));
          },
          child: ListView(
            padding: const EdgeInsets.all(PMSpacing.s4),
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${loc.text('today')}, ${DateTime.now().day} ${_getMonth(DateTime.now().month)}',
                        style: PMTypography.caption.copyWith(
                          color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: PMSpacing.s1),
                      Text(
                        user?.name ?? 'Worker',
                        style: PMTypography.title.copyWith(color: textColor),
                      ),
                    ],
                  ),
                  CircleAvatar(
                    backgroundColor: PMColors.brandPrimaryLight,
                    child: Text(
                      user?.name?.substring(0, 1).toUpperCase() ?? 'W',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: PMSpacing.s6),
              // Worker specific stats (e.g. today's hours, pending payments)
              Container(
                padding: const EdgeInsets.all(PMSpacing.s4),
                decoration: BoxDecoration(
                  color: PMColors.brandPrimaryDark,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(loc.text('totalEarnings'), style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: PMSpacing.s2),
                    const Text('₹ 12,450', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                    const SizedBox(height: PMSpacing.s4),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: PMColors.brandPrimaryDark,
                      ),
                      child: Text(loc.text('viewPayslips')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getMonth(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}
