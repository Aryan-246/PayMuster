import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Multi-company active-company override (blueprint §L).
///
/// `null` — the session's primary organization (user.organizationId) is active;
/// a non-null value — the user switched to that company id, which is sent as
/// `x-company-id` on every tenant-scoped request. The backend remains the
/// security boundary: it re-authorizes each request against the active company
/// (single-org check by default, or an ACTIVE Membership row when
/// MULTI_COMPANY_ENABLED is on).
///
/// The switching UI is only reachable when the backend reports the
/// multi-company flag as enabled, so with the flag OFF this stays null and
/// single-company behavior is unchanged.
class ActiveCompanyNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  /// Switch to a company id, or pass null to return to the primary org.
  void setCompany(String? orgId) {
    state = orgId;
  }
}

final activeCompanyProvider = NotifierProvider<ActiveCompanyNotifier, String?>(
  ActiveCompanyNotifier.new,
);
