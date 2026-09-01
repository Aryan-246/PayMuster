import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/active_company_provider.dart';
import '../../../theme/paymuster_tokens.dart';
import '../data/membership_api.dart';

/// Company switch screen (blueprint §L). Only reachable when the backend
/// reports the multi-company feature flag as enabled AND the user holds
/// additional ACTIVE memberships — the More screen hides the entry otherwise.
/// Switching updates the active-company override used for every tenant-scoped
/// request; the backend re-authorizes each request against the new company.
class CompanySwitchScreen extends ConsumerStatefulWidget {
  const CompanySwitchScreen({super.key});

  @override
  ConsumerState<CompanySwitchScreen> createState() =>
      _CompanySwitchScreenState();
}

class _CompanySwitchScreenState extends ConsumerState<CompanySwitchScreen> {
  late Future<UserCompanies> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(membershipApiProvider).listUserCompanies();
  }

  Future<void> _switch(BuildContext context, String? orgId) async {
    final messenger = ScaffoldMessenger.of(context);
    ref.read(activeCompanyProvider.notifier).setCompany(orgId);
    messenger.showSnackBar(
      SnackBar(content: Text(orgId == null ? 'Back to primary company' : 'Company switched')),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgSurface = isDark ? PMColors.bgSurfaceDark : PMColors.bgSurfaceLight;
    final textColor = isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight;
    final borderCol = isDark ? PMColors.borderDefaultDark : PMColors.borderDefaultLight;
    final activeOrgId = ref.watch(activeCompanyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Switch Company'),
        backgroundColor: bgSurface,
        elevation: 0,
        centerTitle: false,
      ),
      body: FutureBuilder<UserCompanies>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(PMSpacing.s6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Unable to load your companies right now.'),
                  const SizedBox(height: PMSpacing.s4),
                  FilledButton(
                    onPressed: () => setState(() {
                      _future = ref.read(membershipApiProvider).listUserCompanies();
                    }),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final companies = snapshot.data!;
          final effectiveActive = activeOrgId ?? companies.primary?.orgId;
          final options = [
            if (companies.primary != null) companies.primary!,
            ...companies.memberships,
          ];

          return ListView.separated(
            padding: const EdgeInsets.all(PMSpacing.s6),
            itemCount: options.length,
            separatorBuilder: (_, _) => const SizedBox(height: PMSpacing.s3),
            itemBuilder: (context, index) {
              final company = options[index];
              final isActive = company.orgId == effectiveActive;
              return Container(
                decoration: BoxDecoration(
                  color: bgSurface,
                  borderRadius: BorderRadius.circular(PMSpacing.s4),
                  border: Border.all(
                    color: isActive ? PMColors.brandPrimaryLight : borderCol,
                    width: isActive ? 2 : 1,
                  ),
                ),
                child: ListTile(
                  leading: Icon(
                    isActive ? Icons.check_circle : Icons.business,
                    color: isActive ? PMColors.brandPrimaryLight : textColor,
                  ),
                  title: Text(
                    company.name,
                    style: PMTypography.title.copyWith(color: textColor),
                  ),
                  subtitle: Text(
                    company.orgId == companies.primary?.orgId
                        ? 'Primary company'
                        : 'Member · ${company.role.toLowerCase()}',
                    style: PMTypography.caption.copyWith(
                      color: textColor.withValues(alpha: 0.7),
                    ),
                  ),
                  onTap: () => _switch(
                    context,
                    company.orgId == companies.primary?.orgId
                        ? null // primary = clear the override
                        : company.orgId,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
