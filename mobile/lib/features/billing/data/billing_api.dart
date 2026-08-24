import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/tenant_api_client.dart';

final billingApiProvider = Provider<BillingApi>((ref) {
  return BillingApi(ref.read(tenantApiClientProvider));
});

class BillingSummary {
  const BillingSummary({
    required this.subscriptionId,
    required this.status,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    required this.cancelAtPeriodEnd,
    required this.unlimitedAccess,
    required this.plan,
    this.trialEndsAt,
    this.latestInvoice,
  });

  final String subscriptionId;
  final String status;
  final DateTime currentPeriodStart;
  final DateTime currentPeriodEnd;
  final DateTime? trialEndsAt;
  final bool cancelAtPeriodEnd;
  final bool unlimitedAccess;
  final BillingPlan plan;
  final BillingInvoice? latestInvoice;

  factory BillingSummary.fromJson(Map<String, dynamic> json) {
    return BillingSummary(
      subscriptionId: _requiredString(json, 'subscriptionId'),
      status: _requiredString(json, 'status'),
      currentPeriodStart: _requiredDate(json, 'currentPeriodStart'),
      currentPeriodEnd: _requiredDate(json, 'currentPeriodEnd'),
      trialEndsAt: _optionalDate(json['trialEndsAt']),
      cancelAtPeriodEnd: json['cancelAtPeriodEnd'] == true,
      unlimitedAccess: json['unlimitedAccess'] == true,
      plan: BillingPlan.fromJson(_requiredMap(json, 'plan')),
      latestInvoice: json['latestInvoice'] is Map<String, dynamic>
          ? BillingInvoice.fromJson(json['latestInvoice'] as Map<String, dynamic>)
          : null,
    );
  }
}

class BillingPlan {
  const BillingPlan({
    required this.code,
    required this.name,
    required this.amountMinor,
    required this.currency,
    required this.interval,
    this.description,
  });

  final String code;
  final String name;
  final String? description;
  final int amountMinor;
  final String currency;
  final String interval;

  factory BillingPlan.fromJson(Map<String, dynamic> json) {
    return BillingPlan(
      code: _requiredString(json, 'code'),
      name: _requiredString(json, 'name'),
      description: json['description'] as String?,
      amountMinor: _minorAmount(json, 'amountMinor'),
      currency: _requiredString(json, 'currency'),
      interval: _requiredString(json, 'interval'),
    );
  }
}

class BillingInvoice {
  const BillingInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.status,
    required this.totalMinor,
    required this.currency,
    required this.createdAt,
    this.paidAt,
  });

  final String id;
  final String invoiceNumber;
  final String status;
  final int totalMinor;
  final String currency;
  final DateTime createdAt;
  final DateTime? paidAt;

  factory BillingInvoice.fromJson(Map<String, dynamic> json) {
    return BillingInvoice(
      id: _requiredString(json, 'id'),
      invoiceNumber: _requiredString(json, 'invoiceNumber'),
      status: _requiredString(json, 'status'),
      totalMinor: _minorAmount(json, 'totalMinor'),
      currency: _requiredString(json, 'currency'),
      createdAt: _requiredDate(json, 'createdAt'),
      paidAt: _optionalDate(json['paidAt']),
    );
  }
}

class CheckoutOrder {
  const CheckoutOrder({
    required this.orderId,
    required this.amountMinor,
    required this.currency,
    required this.keyId,
    required this.invoiceId,
    required this.subscriptionId,
    required this.planCode,
  });

  final String orderId;
  final int amountMinor;
  final String currency;
  final String keyId;
  final String invoiceId;
  final String subscriptionId;
  final String planCode;

  factory CheckoutOrder.fromJson(Map<String, dynamic> json) {
    return CheckoutOrder(
      orderId: _requiredString(json, 'orderId'),
      amountMinor: _minorAmount(json, 'amountMinor'),
      currency: _requiredString(json, 'currency'),
      keyId: _requiredString(json, 'keyId'),
      invoiceId: _requiredString(json, 'invoiceId'),
      subscriptionId: _requiredString(json, 'subscriptionId'),
      planCode: _requiredString(json, 'planCode'),
    );
  }
}

class CheckoutVerification {
  const CheckoutVerification({
    required this.verified,
    required this.awaitingWebhook,
    required this.invoiceId,
    required this.subscriptionId,
  });

  final bool verified;
  final bool awaitingWebhook;
  final String invoiceId;
  final String subscriptionId;

  factory CheckoutVerification.fromJson(Map<String, dynamic> json) {
    return CheckoutVerification(
      verified: json['verified'] == true,
      awaitingWebhook: json['awaitingWebhook'] == true,
      invoiceId: _requiredString(json, 'invoiceId'),
      subscriptionId: _requiredString(json, 'subscriptionId'),
    );
  }
}

class BillingApi {
  BillingApi(this._client);

  final TenantApiClient _client;

  Future<BillingSummary> getSummary() async {
    final data = await _client.get('/billing/summary');
    return BillingSummary.fromJson(_map(data));
  }

  Future<CheckoutOrder> createCheckoutOrder() async {
    final data = await _client.post('/billing/checkout/order', body: const {});
    return CheckoutOrder.fromJson(_map(data));
  }

  Future<CheckoutVerification> verifyCheckout({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    final data = await _client.post(
      '/billing/checkout/verify',
      body: {
        'orderId': orderId,
        'paymentId': paymentId,
        'signature': signature,
      },
    );
    return CheckoutVerification.fromJson(_map(data));
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    throw const TenantApiException(
      'The billing response was invalid.',
      code: 'INVALID_BILLING_RESPONSE',
    );
  }
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map<String, dynamic>) return value;
  throw TenantApiException(
    'The billing response is missing $key.',
    code: 'INVALID_BILLING_RESPONSE',
  );
}

int _minorAmount(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toInt();
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed != null && parsed >= 0) return parsed;
  throw TenantApiException(
    'The billing response has an invalid $key.',
    code: 'INVALID_BILLING_RESPONSE',
  );
}

DateTime _requiredDate(Map<String, dynamic> json, String key) {
  final value = _optionalDate(json[key]);
  if (value != null) return value;
  throw TenantApiException(
    'The billing response has an invalid $key.',
    code: 'INVALID_BILLING_RESPONSE',
  );
}

DateTime? _optionalDate(dynamic value) {
  return value is String ? DateTime.tryParse(value) : null;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw TenantApiException(
    'The billing response is missing $key.',
    code: 'INVALID_BILLING_RESPONSE',
  );
}
