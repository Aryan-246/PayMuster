// Live-usage tracker for provider health truthfulness.
//
// A provider that is configured but has never been exercised in this process
// cannot honestly claim CONNECTED — the old health model reported
// UNAVAILABLE + readiness READY for exactly that case, which read as a
// contradiction. This module records the last *successful* real use of a
// provider (API call, SMTP delivery, FCM push) so health() can distinguish:
//
//   configured + never used        → ENABLED (ready, unverified live)
//   configured + used successfully → CONNECTED (verified live, with timestamp)
//   configured + use failed        → UNAVAILABLE (last error recorded)
//
// State is in-process by design: it answers "has this instance actually talked
// to the provider", not "is the provider up globally". Health reports always
// carry checkedAt/lastSuccessAt so the distinction is visible to the admin.

interface ProviderUseRecord {
    lastSuccessAt: Date;
    lastFailureAt: Date | null;
    lastError: string | null;
    successCount: number;
    failureCount: number;
}

const records = new Map<string, ProviderUseRecord>();

export function recordProviderSuccess(provider: string): void {
    const existing = records.get(provider);
    records.set(provider, {
        lastSuccessAt: new Date(),
        lastFailureAt: existing?.lastFailureAt ?? null,
        lastError: existing?.lastError ?? null,
        successCount: (existing?.successCount ?? 0) + 1,
        failureCount: existing?.failureCount ?? 0,
    });
}

export function recordProviderFailure(provider: string, error: string): void {
    const existing = records.get(provider);
    records.set(provider, {
        lastSuccessAt: existing?.lastSuccessAt ?? new Date(0),
        lastFailureAt: new Date(),
        lastError: error.slice(0, 300),
        successCount: existing?.successCount ?? 0,
        failureCount: (existing?.failureCount ?? 0) + 1,
    });
}

export function getProviderUse(provider: string): Readonly<ProviderUseRecord> | null {
    const record = records.get(provider);
    if (!record) return null;
    return { ...record };
}

/** True when the provider has completed at least one real operation successfully. */
export function hasVerifiedLiveUse(provider: string): boolean {
    const record = records.get(provider);
    return Boolean(record && record.lastSuccessAt.getTime() > 0 && record.successCount > 0);
}

/** Test/teardown hook — clears tracked usage state. */
export function resetProviderUsage(): void {
    records.clear();
}
