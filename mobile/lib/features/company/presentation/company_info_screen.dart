import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../components/feedback/pm_list_skeleton.dart';
import '../../../components/foundation/pm_button.dart';
import '../../../components/layout/pm_card.dart';
import '../../../theme/paymuster_tokens.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/company_provider.dart';

/// Company identity card (owner.txt dashboard section): name, public IDs,
/// join code with a QR workers can scan to join. All values come from the
/// company overview API — nothing is fabricated.
class CompanyInfoScreen extends ConsumerStatefulWidget {
  const CompanyInfoScreen({super.key});

  @override
  ConsumerState<CompanyInfoScreen> createState() =>
      _CompanyInfoScreenState();
}

class _CompanyInfoScreenState extends ConsumerState<CompanyInfoScreen> {
  CompanyOverview? _overview;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final user = ref.read(authControllerProvider).user;
    final organizationId = user?.organizationId;
    if (organizationId == null) {
      if (!mounted) return;
      setState(() {
        _error = 'Your account is not attached to a company yet.';
        _isLoading = false;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final overview = await ref
          .read(companyProvider)
          .getOverview(organizationId);
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background =
        isDark ? PMColors.bgPrimaryDark : PMColors.bgPrimaryLight;
    final surface = isDark ? PMColors.bgSurfaceDark : PMColors.bgSurfaceLight;
    final textColor =
        isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text(
          'Company & Join Code',
          style: PMTypography.title.copyWith(color: textColor),
        ),
        backgroundColor: surface,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const PMListSkeleton(itemCount: 4)
          : _error != null || _overview == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(PMSpacing.s8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off_outlined,
                          size: 48,
                          color: PMColors.statusDangerLight,
                        ),
                        const SizedBox(height: PMSpacing.s4),
                        Text(
                          _error ?? 'Company information is unavailable.',
                          textAlign: TextAlign.center,
                          style: PMTypography.body.copyWith(color: textColor),
                        ),
                        const SizedBox(height: PMSpacing.s4),
                        PMButton.secondary(
                          label: 'Try again',
                          icon: Icons.refresh,
                          onPressed: _load,
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(PMSpacing.s5),
                    children: [
                      PMCard.standard(
                        child: Column(
                          children: [
                            Text(
                              _overview!.name,
                              textAlign: TextAlign.center,
                              style: PMTypography.title
                                  .copyWith(color: textColor),
                            ),
                            const SizedBox(height: PMSpacing.s2),
                            Text(
                              'Company ID: ${_overview!.publicId ?? _overview!.id}',
                              style: PMTypography.caption.copyWith(
                                color: isDark
                                    ? PMColors.textSecondaryDark
                                    : PMColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: PMSpacing.s5),
                      _JoinCodeCard(overview: _overview!),
                      const SizedBox(height: PMSpacing.s5),
                      PMCard.stat(
                        accentColor: PMColors.brandPrimaryLight,
                        child: Row(
                          children: [
                            const Icon(Icons.people_outline),
                            const SizedBox(width: PMSpacing.s3),
                            Expanded(
                              child: Text(
                                '${_overview!.staffCount} workers · '
                                '${_overview!.userCount} users · '
                                '${_overview!.siteCount} sites',
                                style: PMTypography.body
                                    .copyWith(color: textColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _JoinCodeCard extends StatelessWidget {
  const _JoinCodeCard({required this.overview});

  final CompanyOverview overview;

  Future<void> _copyCode(BuildContext context, String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Join code copied')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight;
    final secondary = isDark
        ? PMColors.textSecondaryDark
        : PMColors.textSecondaryLight;
    final code = overview.joinCode;

    if (code == null || code.isEmpty) {
      return PMCard.standard(
        child: Column(
          children: [
            Icon(Icons.qr_code, size: 40, color: secondary),
            const SizedBox(height: PMSpacing.s3),
            Text(
              'Join code not available',
              style: PMTypography.headline.copyWith(color: textColor),
            ),
            const SizedBox(height: PMSpacing.s2),
            Text(
              'Your company does not have an active join code. Contact platform support to issue one.',
              textAlign: TextAlign.center,
              style: PMTypography.body.copyWith(color: secondary),
            ),
          ],
        ),
      );
    }

    return PMCard.standard(
      child: Column(
        children: [
          Text(
            'Worker join code',
            style: PMTypography.headline.copyWith(color: textColor),
          ),
          const SizedBox(height: PMSpacing.s2),
          Text(
            'Share this code — or let workers scan the QR — to request joining your company. '
            'You approve each request.',
            textAlign: TextAlign.center,
            style: PMTypography.caption.copyWith(color: secondary),
          ),
          const SizedBox(height: PMSpacing.s5),
          Container(
            padding: const EdgeInsets.all(PMSpacing.s4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: PMRadius.md,
            ),
            child: QrImageView(
              key: const Key('company-join-qr'),
              data: code,
              version: QrVersions.auto,
              size: 180,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: PMSpacing.s4),
          SelectableText(
            code,
            textAlign: TextAlign.center,
            style: PMTypography.title.copyWith(
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: PMSpacing.s4),
          PMButton.secondary(
            key: const Key('company-copy-join-code'),
            label: 'Copy code',
            icon: Icons.copy,
            onPressed: () => _copyCode(context, code),
          ),
        ],
      ),
    );
  }
}
