import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/paymuster_tokens.dart';
import '../../auth/presentation/auth_controller.dart';

class VerificationScreen extends ConsumerWidget {
  const VerificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : PMColors.textPrimaryLight;
    final bgColor = isDark ? PMColors.bgPrimaryDark : PMColors.bgPrimaryLight;
    final surfaceColor = isDark ? PMColors.bgSurfaceDark : PMColors.bgSurfaceLight;
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;

    if (user == null) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final verificationItems = <_VerificationItem>[
      _VerificationItem(
        title: 'Email Verification',
        subtitle: 'Verify your email address',
        isVerified: true,
        icon: Icons.email,
      ),
      _VerificationItem(
        title: 'Phone Verification',
        subtitle: 'Verify your phone number',
        isVerified: false,
        icon: Icons.phone,
      ),
      _VerificationItem(
        title: 'ID Verification',
        subtitle: 'Upload and verify your ID',
        isVerified: false,
        icon: Icons.badge,
      ),
      _VerificationItem(
        title: 'Address Verification',
        subtitle: 'Verify your address proof',
        isVerified: false,
        icon: Icons.home,
      ),
    ];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Verification', style: PMTypography.title.copyWith(color: textColor)),
        backgroundColor: surfaceColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(PMSpacing.s6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  PMColors.brandPrimaryLight,
                  PMColors.brandPrimaryDark,
                ],
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Verification Progress',
                  style: PMTypography.title.copyWith(color: Colors.white),
                ),
                const SizedBox(height: PMSpacing.s4),
                LinearProgressIndicator(
                  value: 0.25,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                const SizedBox(height: PMSpacing.s2),
                Text(
                  '1 of 4 completed',
                  style: PMTypography.caption.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(PMSpacing.s4),
              itemCount: verificationItems.length,
              itemBuilder: (context, index) {
                final item = verificationItems[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: PMSpacing.s3),
                  color: surfaceColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: PMRadius.md,
                    side: BorderSide(color: isDark ? PMColors.borderDefaultDark : PMColors.borderDefaultLight),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(PMSpacing.s4),
                    leading: Icon(
                      item.icon,
                      color: item.isVerified ? PMColors.statusSuccessDark : PMColors.textSecondaryLight,
                      size: 28,
                    ),
                    title: Text(item.title, style: PMTypography.headline.copyWith(color: textColor)),
                    subtitle: Text(item.subtitle, style: PMTypography.body.copyWith(color: textColor.withValues(alpha: 0.7))),
                    trailing: item.isVerified
                        ? const Icon(Icons.check_circle, color: PMColors.statusSuccessDark)
                        : IconButton(
                            icon: const Icon(Icons.arrow_forward_ios, size: 16),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${item.title} flow coming soon')),
                              );
                            },
                          ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationItem {
  final String title;
  final String subtitle;
  final bool isVerified;
  final IconData icon;

  const _VerificationItem({
    required this.title,
    required this.subtitle,
    required this.isVerified,
    required this.icon,
  });
}
