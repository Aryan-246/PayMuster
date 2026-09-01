import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/foundation/pm_button.dart';
import '../../../components/foundation/pm_text_input.dart';
import '../../../components/layout/pm_card.dart';
import '../../../core/network/tenant_api_client.dart';
import '../../../theme/paymuster_tokens.dart';
import '../data/announcement_dispatch_api.dart';

const _announcementTypes = [
  'WARNING',
  'EMERGENCY',
  'MEETING',
  'HOLIDAY',
  'INFORMATION',
];
const _audiences = ['ORGANIZATION', 'ROLE', 'USER'];
const _audienceRoles = [
  'OWNER',
  'ADMIN',
  'SUPERVISOR',
  'ACCOUNTANT',
  'STAFF',
  'VIEWER',
];

class AnnouncementDispatchScreen extends ConsumerStatefulWidget {
  const AnnouncementDispatchScreen({super.key});

  @override
  ConsumerState<AnnouncementDispatchScreen> createState() =>
      _AnnouncementDispatchScreenState();
}

class _AnnouncementDispatchScreenState
    extends ConsumerState<AnnouncementDispatchScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _deepLinkController = TextEditingController();
  final _userIdController = TextEditingController();
  String _type = 'INFORMATION';
  String _audience = 'ORGANIZATION';
  String _audienceRole = 'STAFF';
  bool _sending = false;
  AnnouncementDispatchResult? _lastResult;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Rebuild on typing so the Dispatch button tracks input validity.
    _titleController.addListener(_onInputChanged);
    _bodyController.addListener(_onInputChanged);
    _userIdController.addListener(_onInputChanged);
  }

  void _onInputChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _deepLinkController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  bool get _canSend =>
      !_sending &&
      _titleController.text.trim().isNotEmpty &&
      _bodyController.text.trim().isNotEmpty &&
      (_audience != 'USER' || _userIdController.text.trim().isNotEmpty);

  Future<void> _dispatch() async {
    if (!_canSend) return;

    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final result = await ref.read(announcementDispatchApiProvider).dispatch(
            title: _titleController.text.trim(),
            body: _bodyController.text.trim(),
            type: _type,
            audience: _audience,
            deepLink: _deepLinkController.text.trim(),
            audienceRole: _audienceRole,
            audienceUserId: _userIdController.text.trim(),
          );
      if (mounted) {
        setState(() {
          _lastResult = result;
          _titleController.clear();
          _bodyController.clear();
          _deepLinkController.clear();
          _userIdController.clear();
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is TenantApiException
              ? error.message
              : 'The announcement could not be sent. Please try again.';
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
    final secondary = isDark
        ? PMColors.textSecondaryDark
        : PMColors.textSecondaryLight;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text(
          'Send Announcement',
          style: PMTypography.title.copyWith(color: textColor),
        ),
        backgroundColor: surface,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(PMSpacing.s5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Deliver a notice to your organization. Targeting is limited to your own company — the server enforces this.',
                  style: PMTypography.caption.copyWith(color: secondary),
                ),
                const SizedBox(height: PMSpacing.s4),
                PMCard.standard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PMTextInput(
                        controller: _titleController,
                        labelText: 'Title',
                        hintText: 'Title of the announcement',
                        maxLength: 120,
                      ),
                      const SizedBox(height: PMSpacing.s3),
                      PMTextInput(
                        controller: _bodyController,
                        labelText: 'Body',
                        hintText: 'Message body',
                        maxLines: 6,
                        maxLength: 2000,
                      ),
                      const SizedBox(height: PMSpacing.s3),
                      Wrap(
                        spacing: PMSpacing.s4,
                        runSpacing: PMSpacing.s3,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _PickerDropdown(
                            label: 'Type',
                            value: _type,
                            items: _announcementTypes,
                            onChanged: (value) =>
                                setState(() => _type = value),
                          ),
                          _PickerDropdown(
                            label: 'Audience',
                            value: _audience,
                            items: _audiences,
                            onChanged: (value) =>
                                setState(() => _audience = value),
                          ),
                          if (_audience == 'ROLE')
                            _PickerDropdown(
                              label: 'Role',
                              value: _audienceRole,
                              items: _audienceRoles,
                              onChanged: (value) =>
                                  setState(() => _audienceRole = value),
                            ),
                        ],
                      ),
                      if (_audience == 'USER') ...[
                        const SizedBox(height: PMSpacing.s3),
                        PMTextInput(
                          controller: _userIdController,
                          labelText: 'Target user ID',
                          hintText: 'User ID of the recipient',
                        ),
                      ],
                      const SizedBox(height: PMSpacing.s3),
                      PMTextInput(
                        controller: _deepLinkController,
                        labelText: 'Deep link (optional)',
                        hintText: '/app/…',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: PMSpacing.s4),
                PMButton.primary(
                  label: 'Dispatch',
                  icon: Icons.campaign_outlined,
                  isLoading: _sending,
                  onPressed: _canSend ? _dispatch : null,
                ),
                if (_lastResult != null) ...[
                  const SizedBox(height: PMSpacing.s4),
                  PMCard.stat(
                    accentColor: isDark
                        ? PMColors.statusSuccessDark
                        : PMColors.statusSuccessLight,
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: isDark
                              ? PMColors.statusSuccessDark
                              : PMColors.statusSuccessLight,
                        ),
                        const SizedBox(width: PMSpacing.s3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dispatched to ${_lastResult!.recipientCount} recipients',
                                style: PMTypography.headline.copyWith(
                                  color: textColor,
                                ),
                              ),
                              Text(
                                '${_lastResult!.audience} · ${_formatDateTime(_lastResult!.createdAt)}',
                                style: PMTypography.caption.copyWith(
                                  color: secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: PMSpacing.s4),
                  PMCard.stat(
                    accentColor: isDark
                        ? PMColors.statusDangerDark
                        : PMColors.statusDangerLight,
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: isDark
                              ? PMColors.statusDangerDark
                              : PMColors.statusDangerLight,
                        ),
                        const SizedBox(width: PMSpacing.s3),
                        Expanded(
                          child: Text(
                            _error!,
                            style: PMTypography.body.copyWith(
                              color: textColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerDropdown extends StatelessWidget {  const _PickerDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
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
                    item,
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
