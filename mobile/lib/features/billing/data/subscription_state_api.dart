import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/tenant_api_client.dart';

final subscriptionStateApiProvider = Provider<SubscriptionStateApi>((ref) {
  return SubscriptionStateApi(ref.read(tenantApiClientProvider));
});

class SubscriptionPlanInfo {
  const SubscriptionPlanInfo({
    required this.code,
    required this.name,
    required this.interval,
  });

  final String code;
  final String name;
  final String interval;

  factory SubscriptionPlanInfo.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlanInfo(
      code: _requiredString(json, 'code'),
      name: _requiredString(json, 'name'),
      interval: _requiredString(json, 'interval'),
    );
  }
}

class SubscriptionInfo {
  const SubscriptionInfo({
    required this.status,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    this.trialEndsAt,
    required this.cancelAtPeriodEnd,
    required this.unlimitedAccess,
    required this.plan,
  });

  final String status;
  final DateTime currentPeriodStart;
  final DateTime currentPeriodEnd;
  final DateTime? trialEndsAt;
  final bool cancelAtPeriodEnd;
  final bool unlimitedAccess;
  final SubscriptionPlanInfo plan;

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) {
    return SubscriptionInfo(
      status: _requiredString(json, 'status'),
      currentPeriodStart: _requiredDate(json, 'currentPeriodStart'),
      currentPeriodEnd: _requiredDate(json, 'currentPeriodEnd'),
      trialEndsAt: _optionalDate(json['trialEndsAt']),
      cancelAtPeriodEnd: json['cancelAtPeriodEnd'] == true,
      unlimitedAccess: json['unlimitedAccess'] == true,
      plan: SubscriptionPlanInfo.fromJson(
        _requiredMap(json, 'plan'),
      ),
    );
  }
}

class SubscriptionEffectiveAccess {
  const SubscriptionEffectiveAccess({
    required this.allowed,
    required this.unlimited,
    required this.limit,
    required this.source,
  });

  final bool allowed;
  final bool unlimited;
  final int limit;
  final String source;

  factory SubscriptionEffectiveAccess.fromJson(Map<String, dynamic> json) {
    return SubscriptionEffectiveAccess(
      allowed: json['allowed'] == true,
      unlimited: json['unlimited'] == true,
      limit: _requiredInt(json, 'limit'),
      source: _requiredString(json, 'source'),
    );
  }
}

class SubscriptionState {
  const SubscriptionState({
    this.subscription,
    required this.effectiveAccess,
    // Null for roles that may not see the platform switch (manage_system /
    // manage_billing holders only — the backend omits the field entirely).
    this.enforcementEnabled,
  });

  final SubscriptionInfo? subscription;
  final SubscriptionEffectiveAccess effectiveAccess;
  final bool? enforcementEnabled;

  factory SubscriptionState.fromJson(Map<String, dynamic> json) {
    final rawSubscription = json['subscription'];
    return SubscriptionState(
      subscription: rawSubscription is Map<String, dynamic>
          ? SubscriptionInfo.fromJson(rawSubscription)
          : null,
      effectiveAccess: SubscriptionEffectiveAccess.fromJson(
        _requiredMap(json, 'effectiveAccess'),
      ),
      enforcementEnabled: json['enforcementEnabled'] is bool
          ? json['enforcementEnabled'] as bool
          : null,
    );
  }
}

/// Subscription state — GET /api/v1/subscription/state (requireAuth +
/// requireTenant(COMPANY); read-only, honest view of enforcement + plan).
class SubscriptionStateApi {
  SubscriptionStateApi(this._client);

  final TenantApiClient _client;

  Future<SubscriptionState> getState() async {
    final data = await _client.get('/subscription/state');
    if (data is! Map<String, dynamic>) {
      throw const TenantApiException(
        'The subscription state response was invalid.',
        code: 'INVALID_SUBSCRIPTION_RESPONSE',
      );
    }
    return SubscriptionState.fromJson(data);
  }
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map<String, dynamic>) return value;
  throw TenantApiException(
    'The subscription state response is missing $key.',
    code: 'INVALID_SUBSCRIPTION_RESPONSE',
  );
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  throw TenantApiException(
    'The subscription state response has an invalid $key.',
    code: 'INVALID_SUBSCRIPTION_RESPONSE',
  );
}

DateTime _requiredDate(Map<String, dynamic> json, String key) {
  final value = _optionalDate(json[key]);
  if (value != null) return value;
  throw TenantApiException(
    'The subscription state response has an invalid $key.',
    code: 'INVALID_SUBSCRIPTION_RESPONSE',
  );
}

DateTime? _optionalDate(dynamic value) {
  return value is String ? DateTime.tryParse(value) : null;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw TenantApiException(
    'The subscription state response is missing $key.',
    code: 'INVALID_SUBSCRIPTION_RESPONSE',
  );
}
