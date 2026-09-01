import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/feedback/pm_list_skeleton.dart';
import '../../../components/foundation/pm_button.dart';
import '../../../components/layout/pm_card.dart';
import '../../../core/network/tenant_api_client.dart';
import '../../../theme/paymuster_tokens.dart';

class JoinRequest {
  const JoinRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.requestedAt,
  });

  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final DateTime requestedAt;

  factory JoinRequest.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    return JoinRequest(
      id: json['id'] is String ? json['id'] as String : '',
      userId: user is Map<String, dynamic> && user['id'] is String
          ? user['id'] as String
          : '',
      userName: user is Map<String, dynamic> && user['firstName'] is String
          ? user['firstName'] as String
          : 'Applicant',
      userEmail: user is Map<String, dynamic> && user['email'] is String
          ? user['email'] as String
          : '',
      requestedAt: json['createdAt'] is String
          ? (DateTime.tryParse(json['createdAt'] as String) ?? DateTime(1970))
          : DateTime(1970),
    );
  }
}

class JoinRequestsApi {
  const JoinRequestsApi(this._client);

  final TenantApiClient _client;

  /// Pending join requests for the caller's company (manage_staff-gated).
  Future<List<JoinRequest>> listPending() async {
    final data = await _client.get('/company/join');
    if (data is! List) {
      throw const TenantApiException(
        'The server returned invalid join request data.',
        code: 'INVALID_RESPONSE',
      );
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(JoinRequest.fromJson)
        .toList(growable: false);
  }

  Future<void> approve(String requestId) async {
    await _client.post('/company/join/$requestId/approve', body: const {});
  }

  Future<void> reject(String requestId) async {
    await _client.post('/company/join/$requestId/reject', body: const {});
  }
}

final joinRequestsApiProvider = Provider<JoinRequestsApi>((ref) {
  return JoinRequestsApi(ref.watch(tenantApiClientProvider));
});

/// Owner/ADMIN queue of workers requesting to join the company (owner.txt:
/// join via code/QR with owner verification).
class JoinRequestsScreen extends ConsumerStatefulWidget {
  const JoinRequestsScreen({super.key});

  @override
  ConsumerState<JoinRequestsScreen> createState() =>
      _JoinRequestsScreenState();
}

class _JoinRequestsScreenState extends ConsumerState<JoinRequestsScreen> {
  List<JoinRequest> _requests = const [];
  bool _isLoading = true;
  String? _error;
  final _actingOn = <String>{};

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final requests = await ref
          .read(joinRequestsApiProvider)
          .listPending();
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = error is TenantApiException
            ? error.message
            : 'Join requests could not be loaded.';
      });
    }
  }

  Future<void> _act(JoinRequest request, bool approve) async {
    if (!_actingOn.add(request.id)) return;
    setState(() {});
    try {
      final api = ref.read(joinRequestsApiProvider);
      if (approve) {
        await api.approve(request.id);
      } else {
        await api.reject(request.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approve
                  ? '${request.userName} joined the company'
                  : 'Request from ${request.userName} rejected',
            ),
          ),
        );
      }
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is TenantApiException
                  ? error.message
                  : 'The request could not be updated.',
            ),
          ),
        );
      }
    } finally {
      _actingOn.remove(request.id);
      if (mounted) setState(() {});
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
          'Join Requests',
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
          ? const PMListSkeleton(itemCount: 3)
          : _error != null
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
                          _error!,
                          textAlign: TextAlign.center,
                          style: PMTypography.body
                              .copyWith(color: textColor),
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
                  child: _requests.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 120),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.person_search_outlined,
                                    size: 48,
                                    color: secondary,
                                  ),
                                  const SizedBox(height: PMSpacing.s4),
                                  Text(
                                    'No pending requests',
                                    style: PMTypography.headline
                                        .copyWith(color: textColor),
                                  ),
                                  const SizedBox(height: PMSpacing.s2),
                                  Text(
                                    'Share your company join code to receive worker requests.',
                                    textAlign: TextAlign.center,
                                    style: PMTypography.body
                                        .copyWith(color: secondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(PMSpacing.s5),
                          itemCount: _requests.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: PMSpacing.s3),
                          itemBuilder: (context, index) {
                            final request = _requests[index];
                            final acting = _actingOn.contains(request.id);
                            return PMCard.standard(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor:
                                            PMColors.brandPrimaryLight
                                                .withValues(alpha: 0.12),
                                        child: Text(
                                          request.userName
                                              .substring(0, 1)
                                              .toUpperCase(),
                                          style: PMTypography.headline
                                              .copyWith(
                                            color:
                                                PMColors.brandPrimaryLight,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: PMSpacing.s4),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              request.userName,
                                              style: PMTypography.headline
                                                  .copyWith(
                                                      color: textColor),
                                            ),
                                            Text(
                                              request.userEmail,
                                              style: PMTypography.caption
                                                  .copyWith(
                                                      color: secondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: PMSpacing.s4),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: PMButton.primary(
                                          label: 'Approve',
                                          icon: Icons.check,
                                          isLoading: acting,
                                          onPressed: acting
                                              ? null
                                              : () =>
                                                  _act(request, true),
                                        ),
                                      ),
                                      const SizedBox(width: PMSpacing.s3),
                                      Expanded(
                                        child: PMButton.secondary(
                                          label: 'Reject',
                                          icon: Icons.close,
                                          onPressed: acting
                                              ? null
                                              : () =>
                                                  _act(request, false),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
