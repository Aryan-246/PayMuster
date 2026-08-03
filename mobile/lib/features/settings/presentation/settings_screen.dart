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
          _buildSectionHeader('Appearance', isDark),
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
          _buildSectionHeader('Security', isDark),
          _buildSettingsTile(
            icon: Icons.lock_outline,
            title: 'Change Password',
            subtitle: 'Update your account password',
            onTap: () => _showComingSoon(context),
            isDark: isDark,
            cardColor: cardColor,
            textColor: textColor,
          ),
          _buildSettingsTile(
            icon: Icons.devices,
            title: 'Active Sessions',
            subtitle: 'Manage devices logged into your account',
            onTap: () => _showComingSoon(context),
            isDark: isDark,
            cardColor: cardColor,
            textColor: textColor,
          ),
          _buildSettingsTile(
            icon: Icons.phonelink_erase,
            title: 'Logout All Devices',
            subtitle: 'Sign out from all active sessions',
            onTap: () => _showComingSoon(context),
            isDark: isDark,
            cardColor: cardColor,
            textColor: textColor,
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Notifications', isDark),
          _buildSettingsTile(
            icon: Icons.notifications_active_outlined,
            title: 'Push Notifications',
            subtitle: 'Manage app notifications',
            onTap: () => _showComingSoon(context),
            isDark: isDark,
            cardColor: cardColor,
            textColor: textColor,
          ),
          _buildSettingsTile(
            icon: Icons.email_outlined,
            title: 'Email Notifications',
            subtitle: 'Manage email alerts',
            onTap: () => _showComingSoon(context),
            isDark: isDark,
            cardColor: cardColor,
            textColor: textColor,
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Privacy', isDark),
          _buildSettingsTile(
            icon: Icons.import_export,
            title: 'Export My Data',
            subtitle: 'Request a copy of your data',
            onTap: () => _showComingSoon(context),
            isDark: isDark,
            cardColor: cardColor,
            textColor: textColor,
          ),
          _buildSettingsTile(
            icon: Icons.download,
            title: 'Download Account Data',
            subtitle: 'Download your information archive',
            onTap: () => _showComingSoon(context),
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
            onTap: () => _startDeleteFlow(context, ref),
            isDark: isDark,
            cardColor: cardColor,
            textColor: PMColors.statusDangerDark,
            iconColor: PMColors.statusDangerDark,
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Feature coming soon!')),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDark ? PMColors.borderDefaultDark : PMColors.borderDefaultLight,
          ),
        ),
        clipBehavior: Clip.antiAlias,
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
        ),
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

  void _startDeleteFlow(BuildContext context, WidgetRef ref) {
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
              _showPasswordConfirmation(context, ref);
            },
            child: Text('Next', style: TextStyle(color: PMColors.statusDangerDark)),
          ),
        ],
      ),
    );
  }

  void _showPasswordConfirmation(BuildContext context, WidgetRef ref) {
    String password = '';
    bool isLoading = false;
    String? errorMsg;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Password Confirmation'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Please enter your password to continue:'),
                  const SizedBox(height: 16),
                  TextField(
                    obscureText: true,
                    autofocus: true,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: 'Password',
                      errorText: errorMsg,
                    ),
                    onChanged: (value) {
                      setState(() {
                        password = value;
                        errorMsg = null;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                if (!isLoading)
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  TextButton(
                    onPressed: password.isEmpty
                        ? null
                        : () async {
                            setState(() {
                              isLoading = true;
                              errorMsg = null;
                            });
                            
                            final success = await ref
                                .read(authControllerProvider.notifier)
                                .requestDeleteAccountOtp(password);
                            
                            if (success) {
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                _showOtpVerification(ctx, ref);
                              }
                            } else {
                              if (ctx.mounted) {
                                setState(() {
                                  isLoading = false;
                                  errorMsg = ref.read(authControllerProvider).errorMessage ?? 'Invalid password';
                                });
                              }
                            }
                          },
                    child: const Text('Next'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _showOtpVerification(BuildContext context, WidgetRef ref) {
    String otp = '';
    bool isLoading = false;
    String? errorMsg;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('OTP Verification'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('An OTP has been sent to your email. Enter it below:'),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorMsg!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: '123456',
                    ),
                    onChanged: (value) {
                      setState(() {
                        otp = value;
                        errorMsg = null;
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
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  TextButton(
                    onPressed: otp.length < 6
                        ? null
                        : () async {
                            setState(() {
                              isLoading = true;
                              errorMsg = null;
                            });

                            final success = await ref
                                .read(authControllerProvider.notifier)
                                .verifyDeleteAccountOtp(otp);

                            if (success) {
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                _showNameConfirmation(context, ref, otp);
                              }
                            } else {
                              if (ctx.mounted) {
                                setState(() {
                                  isLoading = false;
                                  errorMsg = ref.read(authControllerProvider).errorMessage ?? 'Invalid OTP';
                                });
                              }
                            }
                          },
                    child: const Text('Verify'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _showNameConfirmation(BuildContext context, WidgetRef ref, String otp) {
    final user = ref.read(authControllerProvider).user;
    final expectedName = user?.name ?? '';
    final requiredString = expectedName.isNotEmpty ? expectedName : (user?.email ?? 'DELETE');
    
    String typedText = '';
    bool isLoading = false;
    String? errorMsg;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final isMatch = typedText == requiredString;
            return AlertDialog(
              title: const Text('Final Confirmation'),
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
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: 'Type here to confirm',
                      errorText: errorMsg,
                    ),
                    onChanged: (value) {
                      setState(() {
                        typedText = value;
                        errorMsg = null;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                if (!isLoading)
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  TextButton(
                    onPressed: !isMatch
                        ? null
                        : () async {
                            setState(() {
                              isLoading = true;
                              errorMsg = null;
                            });

                            final success = await ref
                                .read(authControllerProvider.notifier)
                                .deleteAccount(otp);

                            if (success) {
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(content: Text('Your account has been permanently deleted.')),
                                );
                                ctx.go('/welcome');
                              }
                            } else {
                              if (ctx.mounted) {
                                setState(() {
                                  isLoading = false;
                                  errorMsg = ref.read(authControllerProvider).errorMessage ?? 'Invalid OTP or failed to delete';
                                });
                              }
                            }
                          },
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
