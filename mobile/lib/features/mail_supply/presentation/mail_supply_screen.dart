import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/feedback/pm_list_skeleton.dart';
import '../../../components/foundation/pm_button.dart';
import '../../../components/foundation/pm_text_input.dart';
import '../../../components/layout/pm_card.dart';
import '../../../core/network/tenant_api_client.dart';
import '../../../theme/paymuster_tokens.dart';
import '../data/mail_supply_api.dart';

final _mailUsageProvider = FutureProvider<MailUsage>((ref) {
  return ref.watch(mailSupplyApiProvider).getUsage();
});

final _mailHistoryProvider = FutureProvider<List<MailDispatchEntry>>((ref) {
  return ref.watch(mailSupplyApiProvider).getHistory();
});

const _targetTypes = ['ORGANIZATION', 'ROLE', 'INDIVIDUAL'];
const _targetRoles = [
  'OWNER',
  'ADMIN',
  'SUPERVISOR',
  'ACCOUNTANT',
  'STAFF',
  'VIEWER',
];

class MailSupplyScreen extends ConsumerStatefulWidget {
  const MailSupplyScreen({super.key});

  @override
  ConsumerState<MailSupplyScreen> createState() => _MailSupplyScreenState();
}

class _MailSupplyScreenState extends ConsumerState<MailSupplyScreen> {
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  final _userIdController = TextEditingController();
  String _targetType = 'ORGANIZATION';
  String _targetRole = 'STAFF';
  bool _sending = false;
  // A retry with the same key replays the original result without re-sending
  // or re-charging quota (durable MailDispatch idempotency server-side).
  String _idempotencyKey = _newIdempotencyKey();
  MailSendResult? _lastResult;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Rebuild on typing so the Send button's enabled state tracks the inputs.
    _subjectController.addListener(_onInputChanged);
    _bodyController.addListener(_onInputChanged);
    _userIdController.addListener(_onInputChanged);
  }

  void _onInputChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  static String _newIdempotencyKey() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final random = Object().hashCode;
    return 'mail-$now-$random';
  }

  Future<void> _refresh() async {
    ref.invalidate(_mailUsageProvider);
    ref.invalidate(_mailHistoryProvider);
  }

  Future<void> _send() async {
    final subject = _subjectController.text.trim();
    final body = _bodyController.text.trim();
    final targetUserId = _userIdController.text.trim();
    if (subject.isEmpty || body.isEmpty) return;
    if (_targetType == 'INDIVIDUAL' && targetUserId.isEmpty) return;

    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final result = await ref.read(mailSupplyApiProvider).send(
            subject: subject,
            body: body,
            targetType: _targetType,
            targetRole: _targetRole,
            targetUserId: targetUserId,
            idempotencyKey: _idempotencyKey,
          );
      // A completed dispatch consumed this key — the next send is fresh.
      _idempotencyKey = _newIdempotencyKey();
      await _refresh();
      if (mounted) {
        setState(() {
          _lastResult = result;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is TenantApiException
              ? error.message
              : 'The mail could not be sent. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
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
    final usage = ref.watch(_mailUsageProvider);
    final history = ref.watch(_mailHistoryProvider);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text(
          'Mail Supply',
          style: PMTypography.title.copyWith(color: textColor),
        ),
        backgroundColor: surface,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh mail supply',
            onPressed: _sending ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Padding(
                  padding: const EdgeInsets.all(PMSpacing.s5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      usage.when(
                        loading: () => const PMListSkeleton(itemCount: 1),
                        error: (error, _) => _MailErrorState(
                          message: error is TenantApiException
                              ? error.message
                              : 'Mail usage could not be loaded.',
                          onRetry: _refresh,
                        ),
                        data: (usage) => _UsageSummary(usage: usage),
                      ),
                      const SizedBox(height: PMSpacing.s5),
                      _ComposeCard(
                        subjectController: _subjectController,
                        bodyController: _bodyController,
                        userIdController: _userIdController,
                        targetType: _targetType,
                        targetRole: _targetRole,
                        sending: _sending,
                        lastResult: _lastResult,
                        error: _error,
                        onTargetTypeChanged: (value) =>
                            setState(() => _targetType = value),
                        onTargetRoleChanged: (value) =>
                            setState(() => _targetRole = value),
                        onSend: _send,
                      ),
                      const SizedBox(height: PMSpacing.s5),
                      Text(
                        'History',
                        style: PMTypography.headline.copyWith(color: textColor),
                      ),
                      const SizedBox(height: PMSpacing.s3),
                    ],
                  ),
                ),
              ),
            ),
          ),
          history.when(
            loading: () => const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(PMSpacing.s5),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
            error: (error, _) => SliverToBoxAdapter(
              child: _MailErrorState(
                message: error is TenantApiException
                    ? error.message
                    : 'Mail history could not be loaded.',
                onRetry: _refresh,
              ),
            ),
            data: (entries) => entries.isEmpty
                ? const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _HistoryEmptyState(),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      PMSpacing.s5,
                      0,
                      PMSpacing.s5,
                      PMSpacing.s8,
                    ),
                    sliver: SliverList.separated(
                      itemCount: entries.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: PMSpacing.s3),
                      itemBuilder: (context, index) => Center(
                        child: ConstrainedBox(
                          constraints:
                              const BoxConstraints(maxWidth: 900),
                          child: _HistoryCard(entry: entries[index]),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _UsageSummary extends StatelessWidget {
  const _UsageSummary({required this.usage});

  final MailUsage usage;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight;
    final secondary = isDark
        ? PMColors.textSecondaryDark
        : PMColors.textSecondaryLight;
    final accent =
        isDark ? PMColors.brandPrimaryDark : PMColors.brandPrimaryLight;

    return PMCard.stat(
      accentColor: accent,
      child: Row(
        children: [
          Icon(Icons.email_outlined, color: accent),
          const SizedBox(width: PMSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  usage.unlimited
                      ? 'Unlimited mail'
                      : '${usage.remaining} remaining',
                  style: PMTypography.headline.copyWith(color: textColor),
                ),
                Text(
                  usage.unlimited
                      ? 'Mail is not metered for your plan'
                      : '${usage.sent}/${usage.limit} sent this month (${usage.monthKey})',
                  style: PMTypography.caption.copyWith(color: secondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposeCard extends StatelessWidget {
  const _ComposeCard({
    required this.subjectController,
    required this.bodyController,
    required this.userIdController,
    required this.targetType,
    required this.targetRole,
    required this.sending,
    required this.lastResult,
    required this.error,
    required this.onTargetTypeChanged,
    required this.onTargetRoleChanged,
    required this.onSend,
  });

  final TextEditingController subjectController;
  final TextEditingController bodyController;
  final TextEditingController userIdController;
  final String targetType;
  final String targetRole;
  final bool sending;
  final MailSendResult? lastResult;
  final String? error;
  final ValueChanged<String> onTargetTypeChanged;
  final ValueChanged<String> onTargetRoleChanged;
  final VoidCallback onSend;

  bool get _canSend =>
      !sending &&
      subjectController.text.trim().isNotEmpty &&
      bodyController.text.trim().isNotEmpty &&
      (targetType != 'INDIVIDUAL' ||
          userIdController.text.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight;
    final secondary = isDark
        ? PMColors.textSecondaryDark
        : PMColors.textSecondaryLight;

    return PMCard.standard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Compose',
            style: PMTypography.headline.copyWith(color: textColor),
          ),
          const SizedBox(height: PMSpacing.s2),
          Text(
            'The subject and body you write are exactly what gets delivered. '
            'Targeting is limited to your own organization.',
            style: PMTypography.caption.copyWith(color: secondary),
          ),
          const SizedBox(height: PMSpacing.s4),
          PMTextInput(
            controller: subjectController,
            labelText: 'Subject',
            hintText: 'Subject of your message',
            maxLength: 200,
          ),
          const SizedBox(height: PMSpacing.s3),
          PMTextInput(
            controller: bodyController,
            labelText: 'Body',
            hintText: 'Message body',
            maxLines: 6,
            maxLength: 8000,
          ),
          const SizedBox(height: PMSpacing.s3),
          Wrap(
            spacing: PMSpacing.s3,
            runSpacing: PMSpacing.s2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _TargetDropdown(
                label: 'Target',
                value: targetType,
                items: _targetTypes,
                display: _targetLabel,
                onChanged: onTargetTypeChanged,
              ),
              if (targetType == 'ROLE')
                _TargetDropdown(
                  label: 'Role',
                  value: targetRole,
                  items: _targetRoles,
                  display: (value) => value,
                  onChanged: onTargetRoleChanged,
                ),
            ],
          ),
          if (targetType == 'INDIVIDUAL') ...[
            const SizedBox(height: PMSpacing.s3),
            PMTextInput(
              controller: userIdController,
              labelText: 'Target user ID',
              hintText: 'User ID of the recipient',
            ),
          ],
          const SizedBox(height: PMSpacing.s4),
          PMButton.primary(
            label: 'Send',
            icon: Icons.send_outlined,
            isLoading: sending,
            onPressed: _canSend ? onSend : null,
          ),
          if (lastResult != null) ...[
            const SizedBox(height: PMSpacing.s3),
            Text(
              lastResult!.duplicate
                  ? 'Already sent (idempotent replay) — sent: ${lastResult!.sent}'
                  : 'Sent: ${lastResult!.sent}'
                      '${lastResult!.failed > 0 ? ', failed: ${lastResult!.failed}' : ''}',
              style: PMTypography.caption.copyWith(
                color: lastResult!.failed > 0
                    ? PMColors.statusWarningLight
                    : PMColors.statusSuccessLight,
              ),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: PMSpacing.s3),
            Text(
              error!,
              style: PMTypography.caption.copyWith(
                color: PMColors.statusDangerLight,
              ),
            ),
          ],
          const SizedBox(height: PMSpacing.s2),
          Text(
            'Delivered through your organization\'s monthly quota.',
            style: PMTypography.caption.copyWith(
              color: isDark ? PMColors.textTertiaryDark : PMColors.textTertiaryLight,
            ),
          ),
        ],
      ),
    );
  }

  String _targetLabel(String value) {
    return switch (value) {
      'ORGANIZATION' => 'Whole organization',
      'ROLE' => 'By role',
      'INDIVIDUAL' => 'Individual',
      _ => value,
    };
  }
}

class _TargetDropdown extends StatelessWidget {
  const _TargetDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final String Function(String) display;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight;
    final secondary = isDark
        ? PMColors.textSecondaryDark
        : PMColors.textSecondaryLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: PMTypography.caption.copyWith(color: secondary)),
        const SizedBox(height: PMSpacing.s1),
        DropdownButton<String>(
          value: value,
          items: items
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(
                    display(item),
                    style: PMTypography.body.copyWith(color: textColor),
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry});

  final MailDispatchEntry entry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight;
    final secondary = isDark
        ? PMColors.textSecondaryDark
        : PMColors.textSecondaryLight;

    return PMCard.standard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.subject,
                  style: PMTypography.headline.copyWith(color: textColor),
                ),
                const SizedBox(height: PMSpacing.s1),
                Text(
                  '${entry.targetType} · ${entry.recipientCount} recipients · ${_formatDateTime(entry.sentAt)}',
                  style: PMTypography.caption.copyWith(color: secondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: PMSpacing.s3),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: PMSpacing.s3,
              vertical: PMSpacing.s1,
            ),
            decoration: BoxDecoration(
              color: entry.status == 'SUCCESS'
                  ? PMColors.statusSuccessLight.withValues(alpha: 0.12)
                  : PMColors.statusWarningLight.withValues(alpha: 0.12),
              borderRadius: PMRadius.sm,
            ),
            child: Text(
              entry.status,
              style: PMTypography.caption.copyWith(
                color: entry.status == 'SUCCESS'
                    ? PMColors.statusSuccessLight
                    : PMColors.statusWarningLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight;
    final secondary = isDark
        ? PMColors.textSecondaryDark
        : PMColors.textSecondaryLight;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PMSpacing.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mark_email_read_outlined, size: 48, color: secondary),
            const SizedBox(height: PMSpacing.s4),
            Text(
              'No mail sent yet',
              style: PMTypography.headline.copyWith(color: textColor),
            ),
            const SizedBox(height: PMSpacing.s2),
            Text(
              'Your sent mail will appear here.',
              textAlign: TextAlign.center,
              style: PMTypography.body.copyWith(color: secondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _MailErrorState extends StatelessWidget {
  const _MailErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight;
    return Padding(
      padding: const EdgeInsets.all(PMSpacing.s5),
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
            message,
            textAlign: TextAlign.center,
            style: PMTypography.body.copyWith(color: textColor),
          ),
          const SizedBox(height: PMSpacing.s4),
          PMButton.secondary(
            label: 'Try again',
            icon: Icons.refresh,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[local.month - 1]} ${local.day}, ${local.year}';
}
