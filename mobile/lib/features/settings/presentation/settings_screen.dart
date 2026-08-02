import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../../theme/paymuster_tokens.dart';
import '../../../theme/theme_controller.dart';
import '../../../l10n/language_controller.dart';
import '../../../l10n/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : PMColors.textPrimaryLight;
    final bgColor = isDark ? PMColors.bgPrimaryDark : PMColors.bgPrimaryLight;
    final cardColor = isDark ? PMColors.bgSurfaceDark : PMColors.bgSurfaceLight;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Settings', style: PMTypography.title.copyWith(color: textColor)),
        backgroundColor: cardColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionHeader('Preferences', isDark),
          _buildSettingsTile(
            icon: Icons.dark_mode_outlined,
            title: 'Theme',
            subtitle: themePreferenceLabel(ThemeScope.of(context).preference),
            onTap: () => _showThemeDialog(context, ThemeScope.of(context)),
            isDark: isDark,
            cardColor: cardColor,
            textColor: textColor,
          ),
          _buildSettingsTile(
            icon: Icons.language,
            title: 'Language',
            subtitle: LanguageScope.of(context).language.label,
            onTap: () => _showLanguageDialog(context, LanguageScope.of(context)),
            isDark: isDark,
            cardColor: cardColor,
            textColor: textColor,
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Account', isDark),
          _buildSettingsTile(
            icon: Icons.person_outline,
            title: 'Profile',
            subtitle: 'Manage your personal information',
            onTap: () {
              context.go('/app/settings/profile');
            },
            isDark: isDark,
            cardColor: cardColor,
            textColor: textColor,
          ),
          _buildSettingsTile(
            icon: Icons.logout,
            title: 'Logout',
            subtitle: 'Sign out of your account',
            onTap: () async {
              await ref.read(authControllerProvider.notifier).signOut();
              // UI should not route manually. GoRouter handles state changes.
            },
            isDark: isDark,
            cardColor: cardColor,
            textColor: PMColors.statusDangerDark,
            iconColor: PMColors.statusDangerDark,
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Danger Zone', isDark),
          _buildSettingsTile(
            icon: Icons.delete_forever,
            title: 'Delete Account',
            subtitle: 'Permanently delete your account',
            onTap: () => _showDeleteConfirmation(context, ref),
            isDark: isDark,
            cardColor: cardColor,
            textColor: PMColors.statusDangerDark,
            iconColor: PMColors.statusDangerDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8, top: 16),
      child: Text(
        title.toUpperCase(),
        style: PMTypography.caption.copyWith(
          color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
    required Color cardColor,
    required Color textColor,
    Color? iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? PMColors.borderDefaultDark : PMColors.borderDefaultLight,
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor ?? textColor),
        title: Text(title, style: PMTypography.bodyLarge.copyWith(color: textColor)),
        subtitle: Text(
          subtitle,
          style: PMTypography.caption.copyWith(
            color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showThemeDialog(BuildContext context, ThemeController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ThemePreference.values.map((pref) {
            return ListTile(
              title: Text(themePreferenceLabel(pref)),
              trailing: controller.preference == pref ? const Icon(Icons.check) : null,
              onTap: () {
                controller.setPreference(pref);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, LanguageController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: AppLanguage.values.map((lang) {
              return ListTile(
                title: Text(lang.label),
                trailing: controller.language == lang ? const Icon(Icons.check) : null,
                onTap: () {
                  controller.setLanguage(lang);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This action is permanent.\n\nYour account, profile, OTP history, active sessions and personal data will be permanently deleted.\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showNameConfirmation(context, ref);
            },
            child: Text('Delete', style: TextStyle(color: PMColors.statusDangerDark)),
          ),
        ],
      ),
    );
  }

  void _showNameConfirmation(BuildContext context, WidgetRef ref) {
    final user = ref.read(authControllerProvider).user;
    final expectedName = user?.name ?? '';
    
    // If the user somehow has no name, we can skip the typed check or ask for email.
    // For safety, let's require the exact name if it exists, otherwise email.
    final requiredString = expectedName.isNotEmpty ? expectedName : (user?.email ?? 'DELETE');
    
    String typedText = '';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final isMatch = typedText == requiredString;
            return AlertDialog(
              title: const Text('Confirm Deletion'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('To permanently delete your account, please type:'),
                  const SizedBox(height: 8),
                  SelectableText(
                    requiredString,
                    style: PMTypography.title.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Type here to confirm',
                    ),
                    onChanged: (value) {
                      setState(() {
                        typedText = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: isMatch
                      ? () async {
                          Navigator.pop(ctx);
                          await ref.read(authControllerProvider.notifier).deleteAccount();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Your account has been permanently deleted.')),
                            );
                            context.go('/welcome');
                          }
                        }
                      : null,
                  child: Text(
                    'Delete',
                    style: TextStyle(
                      color: isMatch ? PMColors.statusDangerDark : Colors.grey,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
