import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/language_controller.dart';
import '../../../theme/theme_controller.dart';
import '../data/admin_api_client.dart';
import 'theme/admin_tokens.dart';
import 'widgets/admin_ui_helpers.dart';

class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  ConsumerState<AdminSettingsScreen> createState() =>
      _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen> {
  List<Map<String, dynamic>> _providers = const [];
  bool _loadingProviders = true;
  String? _providerError;

  @override
  void initState() {
    super.initState();
    _loadProviderHealth();
  }

  Future<void> _loadProviderHealth() async {
    if (mounted) {
      setState(() {
        _loadingProviders = true;
        _providerError = null;
      });
    }
    try {
      final result = await ref.read(adminApiClientProvider).getProviderHealth();
      if (!mounted) return;
      setState(() {
        _providers =
            result['providers'] as List<Map<String, dynamic>>? ?? const [];
        _loadingProviders = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingProviders = false;
        _providerError = error.toString().replaceFirst(
          RegExp(r'^Exception: '),
          '',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeScope.of(context);
    final languageController = LanguageScope.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AdminColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AdminSpacing.gutterMobile),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.text('adminSettings.title'),
                  style: AdminTypography.headlineLgMobile.copyWith(
                    color: AdminColors.onSurface,
                  ),
                ),
                const SizedBox(height: AdminSpacing.xs),
                Text(
                  l10n.text('adminSettings.subtitle'),
                  style: AdminTypography.bodyMd.copyWith(
                    color: AdminColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AdminSpacing.lg),
                _PreferencePanel(
                  icon: Icons.palette_outlined,
                  title: l10n.text('adminSettings.appearance'),
                  child: DropdownButtonFormField<ThemePreference>(
                    initialValue: themeController.preference,
                    decoration: InputDecoration(
                      labelText: l10n.text('adminSettings.theme'),
                    ),
                    dropdownColor: AdminColors.surfaceContainerHigh,
                    items: ThemePreference.values
                        .map(
                          (preference) => DropdownMenuItem(
                            value: preference,
                            child: Text(themePreferenceLabel(preference)),
                          ),
                        )
                        .toList(),
                    onChanged: (preference) {
                      if (preference != null) {
                        themeController.setPreference(preference);
                      }
                    },
                  ),
                ),
                const SizedBox(height: AdminSpacing.md),
                _PreferencePanel(
                  icon: Icons.language_outlined,
                  title: l10n.text('adminSettings.language'),
                  child: DropdownButtonFormField<AppLanguage>(
                    initialValue: languageController.language,
                    decoration: InputDecoration(
                      labelText: l10n.text('adminSettings.applicationLanguage'),
                    ),
                    dropdownColor: AdminColors.surfaceContainerHigh,
                    items: AppLanguage.values
                        .map(
                          (language) => DropdownMenuItem(
                            value: language,
                            child: Text(language.label),
                          ),
                        )
                        .toList(),
                    onChanged: (language) {
                      if (language != null) {
                        languageController.setLanguage(language);
                      }
                    },
                  ),
                ),
                const SizedBox(height: AdminSpacing.md),
                _ProviderHealthPanel(
                  providers: _providers,
                  loading: _loadingProviders,
                  error: _providerError,
                  onRetry: _loadProviderHealth,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProviderHealthPanel extends StatelessWidget {
  const _ProviderHealthPanel({
    required this.providers,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final List<Map<String, dynamic>> providers;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _PreferencePanel(
      icon: Icons.health_and_safety_outlined,
      title: AppLocalizations.of(context).text('adminSettings.providerHealth'),
      child: loading
          ? const AdminLoadingState()
          : error != null
          ? AdminErrorState(error: error!, onRetry: onRetry)
          : providers.isEmpty
          ? AdminEmptyState(
              icon: Icons.cloud_off_outlined,
              title: AppLocalizations.of(
                context,
              ).text('adminSettings.noProviderData'),
              message: AppLocalizations.of(
                context,
              ).text('adminSettings.providerDataUnavailable'),
            )
          : Column(
              children: providers
                  .map((provider) => _ProviderRow(provider: provider))
                  .toList(),
            ),
    );
  }
}

class _ProviderRow extends StatelessWidget {
  const _ProviderRow({required this.provider});

  final Map<String, dynamic> provider;

  @override
  Widget build(BuildContext context) {
    final status = (provider['status'] as String? ?? 'UNAVAILABLE')
        .toUpperCase();
    final enabled = provider['enabled'] == true;
    final connected = status == 'CONNECTED';
    final color = connected
        ? AdminColors.success
        : enabled
        ? AdminColors.warning
        : AdminColors.onSurfaceVariant;
    final name = provider['provider'] as String? ?? 'provider';
    final fallback = provider['fallback'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: AdminSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            connected ? Icons.check_circle_outline : Icons.info_outline,
            color: color,
            size: 20,
          ),
          const SizedBox(width: AdminSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AdminTypography.titleSm.copyWith(
                    color: AdminColors.onSurface,
                  ),
                ),
                Text(
                  fallback == null ? status : '$status · fallback: $fallback',
                  style: AdminTypography.bodySm.copyWith(
                    color: AdminColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          AdminBadge(
            label: enabled ? 'Enabled' : 'Disabled',
            color: color,
            icon: Icons.toggle_on_outlined,
          ),
        ],
      ),
    );
  }
}

class _PreferencePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _PreferencePanel({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AdminSpacing.md),
      decoration: BoxDecoration(
        color: AdminColors.surfaceContainerLow,
        borderRadius: AdminRadius.lg,
        border: Border.all(color: AdminColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AdminColors.primaryContainer),
              const SizedBox(width: AdminSpacing.sm),
              Text(
                title,
                style: AdminTypography.titleMd.copyWith(
                  color: AdminColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: AdminSpacing.md),
          child,
        ],
      ),
    );
  }
}
