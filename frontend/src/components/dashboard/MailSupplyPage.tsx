import { useMemo, useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useI18n } from '../../i18n/I18nProvider';
import { authenticatedGetJson, authenticatedPostJson, ApiError } from '../../lib/api';
import type { AuthSession } from '../../lib/auth-session';
import { GlassPanel } from '../ui/GlassPanel';
import { LoadingState } from '../ui/LoadingState';
import { BrandButton } from '../ui/BrandButton';
import { useActiveCompany } from '../../lib/active-company';

// Mirrors mailSupplyService.getUsage / getHistory response shapes —
// GET /api/v1/mail-supply/{usage,history} (manage_mail + COMPANY tenant scope
// enforced server-side; orgId travels in x-company-id, never in the URL).
interface MailUsage {
  sent: number;
  limit: number;
  remaining: number;
  monthKey: string;
}

interface MailHistoryEntry {
  id: string;
  sentAt: string;
  subject: string;
  targetType: string;
  recipientCount: number;
  status: string;
  actorId: string;
}

interface MailSendResult {
  sent: number;
  failed: number;
  blocked: number;
  errors: Array<{ email: string; error: string }>;
  dispatchId: string;
  duplicate?: boolean;
}

const TARGET_TYPES = ['ORGANIZATION', 'ROLE', 'INDIVIDUAL'] as const;
const TARGET_ROLES = ['OWNER', 'ADMIN', 'SUPERVISOR', 'ACCOUNTANT', 'STAFF', 'VIEWER'] as const;

// A send is retried with the SAME key → the server replays the original result
// without re-sending or re-charging quota (durable MailDispatch idempotency).
function newIdempotencyKey(): string {
  return typeof crypto !== 'undefined' && 'randomUUID' in crypto
    ? crypto.randomUUID()
    : `${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

export function MailSupplyPage({ session }: { session: AuthSession }) {
  const { t } = useI18n();
  const { activeOrgId } = useActiveCompany();
  const queryClient = useQueryClient();
  const [subject, setSubject] = useState('');
  const [body, setBody] = useState('');
  const [targetType, setTargetType] = useState<(typeof TARGET_TYPES)[number]>('ORGANIZATION');
  const [targetRole, setTargetRole] = useState<(typeof TARGET_ROLES)[number]>('STAFF');
  const [targetUserId, setTargetUserId] = useState('');
  const [idempotencyKey, setIdempotencyKey] = useState(newIdempotencyKey());
  const [sendResult, setSendResult] = useState<MailSendResult | null>(null);
  const [sendError, setSendError] = useState<string | null>(null);

  const usageQuery = useQuery({
    queryKey: ['mail-usage', activeOrgId],
    queryFn: () =>
      authenticatedGetJson<{ success: boolean; data: MailUsage }>('/api/v1/mail-supply/usage', session.accessToken, {
        'x-company-id': activeOrgId,
      }),
    enabled: Boolean(activeOrgId),
  });

  const historyQuery = useQuery({
    queryKey: ['mail-history', activeOrgId],
    queryFn: () =>
      authenticatedGetJson<{ success: boolean; data: MailHistoryEntry[] }>('/api/v1/mail-supply/history', session.accessToken, {
        'x-company-id': activeOrgId,
      }),
    enabled: Boolean(activeOrgId),
  });

  const usage = usageQuery.data?.data;
  const history = useMemo(() => historyQuery.data?.data ?? [], [historyQuery.data]);

  const canSubmit = subject.trim().length > 0 && body.trim().length > 0
    && (targetType !== 'ROLE' || targetRole.length > 0)
    && (targetType !== 'INDIVIDUAL' || targetUserId.trim().length > 0);

  const sendMutation = useMutation({
    mutationFn: () =>
      authenticatedPostJson<{ success: boolean; data: MailSendResult }>(
        '/api/v1/mail-supply/send',
        session.accessToken,
        {
          subject: subject.trim(),
          body: body.trim(),
          targetType,
          ...(targetType === 'ROLE' ? { targetRole } : {}),
          ...(targetType === 'INDIVIDUAL' ? { targetUserId: targetUserId.trim() } : {}),
        },
        {
          'x-company-id': activeOrgId,
          'Idempotency-Key': idempotencyKey,
        },
      ).then((response) => response.data),
    onSuccess: async (data) => {
      setSendResult(data);
      setSendError(null);
      // A completed dispatch consumed this key — a subsequent send is a fresh
      // dispatch and must mint a fresh idempotency key.
      setIdempotencyKey(newIdempotencyKey());
      // Authoritative refresh: usage + history re-read from the server after
      // the metered send.
      await queryClient.invalidateQueries({ queryKey: ['mail-usage'] });
      await queryClient.invalidateQueries({ queryKey: ['mail-history'] });
    },
    onError: (error) => {
      setSendResult(null);
      setSendError(error instanceof ApiError ? error.message : t('mail.sendError'));
    },
  });

  return (
    <div className="space-y-pm-4">
      <GlassPanel>
        <p className="text-[11px] uppercase tracking-[0.34em] text-pm-brand">{t('mail.supplyTitle')}</p>
        <h2 className="mt-pm-2 text-2xl font-semibold tracking-tight text-pm-text-primary">{t('mail.title')}</h2>
        <p className="mt-pm-3 text-sm text-pm-text-secondary">{t('mail.description')}</p>
      </GlassPanel>

      {usageQuery.isPending ? (
        <LoadingState />
      ) : usageQuery.isError ? (
        <GlassPanel>
          <p className="text-sm font-semibold text-pm-text-primary">{t('mail.usageError')}</p>
          <div className="mt-pm-4">
            <BrandButton tone="secondary" onClick={() => void usageQuery.refetch()}>
              {t('common.retry')}
            </BrandButton>
          </div>
        </GlassPanel>
      ) : usage ? (
        <section className="grid gap-pm-4 md:grid-cols-3">
          <GlassPanel>
            <p className="text-sm text-pm-text-secondary">{t('mail.sent')}</p>
            <p className="mt-pm-2 text-2xl font-semibold text-pm-text-primary">{usage.sent}</p>
          </GlassPanel>
          <GlassPanel>
            <p className="text-sm text-pm-text-secondary">{t('mail.quota')}</p>
            <p className="mt-pm-2 text-2xl font-semibold text-pm-text-primary">
              {usage.limit >= 999999 ? t('mail.unlimited') : `${usage.sent}/${usage.limit}`}
            </p>
          </GlassPanel>
          <GlassPanel>
            <p className="text-sm text-pm-text-secondary">{t('mail.remaining')}</p>
            <p className="mt-pm-2 text-2xl font-semibold text-pm-success">
              {usage.limit >= 999999 ? t('mail.unlimited') : usage.remaining}
            </p>
          </GlassPanel>
        </section>
      ) : null}

      <GlassPanel>
        <p className="text-sm font-semibold text-pm-text-primary">{t('mail.compose')}</p>
        <p className="mt-pm-2 text-sm text-pm-text-secondary">{t('mail.composeDescription')}</p>
        <div className="mt-pm-5 space-y-pm-4">
          <input
            type="text"
            value={subject}
            onChange={(event) => setSubject(event.target.value)}
            placeholder={t('mail.subjectPlaceholder')}
            aria-label={t('mail.subjectPlaceholder')}
            maxLength={200}
            className="w-full rounded-pm-md border border-pm-border bg-pm-background px-pm-4 py-pm-3 text-sm text-pm-text-primary outline-none placeholder:text-pm-text-tertiary focus:border-pm-brand/50"
          />
          <textarea
            value={body}
            onChange={(event) => setBody(event.target.value)}
            placeholder={t('mail.bodyPlaceholder')}
            aria-label={t('mail.bodyPlaceholder')}
            rows={6}
            maxLength={8000}
            className="w-full rounded-pm-md border border-pm-border bg-pm-background px-pm-4 py-pm-3 text-sm leading-6 text-pm-text-primary outline-none placeholder:text-pm-text-tertiary focus:border-pm-brand/50"
          />
          <div className="flex flex-wrap items-center gap-pm-3">
            <label className="flex items-center gap-pm-2 text-sm text-pm-text-secondary">
              {t('mail.target')}
              <select
                value={targetType}
                onChange={(event) => setTargetType(event.target.value as (typeof TARGET_TYPES)[number])}
                className="rounded-pm-md border border-pm-border bg-pm-raised px-3 py-1.5 text-sm text-pm-text-primary"
              >
                {TARGET_TYPES.map((type) => (
                  <option key={type} value={type}>{t(`mail.target_${type.toLowerCase()}`)}</option>
                ))}
              </select>
            </label>
            {targetType === 'ROLE' && (
              <label className="flex items-center gap-pm-2 text-sm text-pm-text-secondary">
                {t('mail.role')}
                <select
                  value={targetRole}
                  onChange={(event) => setTargetRole(event.target.value as (typeof TARGET_ROLES)[number])}
                  className="rounded-pm-md border border-pm-border bg-pm-raised px-3 py-1.5 text-sm text-pm-text-primary"
                >
                  {TARGET_ROLES.map((role) => (
                    <option key={role} value={role}>{role}</option>
                  ))}
                </select>
              </label>
            )}
            {targetType === 'INDIVIDUAL' && (
              <input
                type="text"
                value={targetUserId}
                onChange={(event) => setTargetUserId(event.target.value)}
                placeholder={t('mail.userIdPlaceholder')}
                aria-label={t('mail.userIdPlaceholder')}
                className="flex-1 rounded-pm-md border border-pm-border bg-pm-background px-pm-4 py-pm-3 text-sm text-pm-text-primary outline-none placeholder:text-pm-text-tertiary focus:border-pm-brand/50"
              />
            )}
          </div>
          <div className="flex items-center gap-pm-3">
            <BrandButton
              disabled={sendMutation.isPending || !canSubmit}
              onClick={() => void sendMutation.mutate()}
            >
              {sendMutation.isPending ? t('mail.sending') : t('mail.send')}
            </BrandButton>
            {sendResult && (
              <span className="text-sm text-pm-text-secondary">
                {sendResult.duplicate ? `${t('mail.duplicate')} · ` : ''}
                {t('mail.sentCount')}: {sendResult.sent}
                {sendResult.failed > 0 ? ` · ${t('mail.failedCount')}: ${sendResult.failed}` : ''}
              </span>
            )}
          </div>
          {sendError && (
            <div className="rounded-pm-lg border border-pm-danger/30 bg-pm-danger/10 p-pm-3">
              <p className="text-sm text-pm-danger">{sendError}</p>
            </div>
          )}
        </div>
      </GlassPanel>

      <GlassPanel>
        <p className="text-sm font-semibold text-pm-text-primary">{t('mail.history')}</p>
        <p className="mt-pm-2 text-sm text-pm-text-secondary">{t('mail.historyDescription')}</p>
        {historyQuery.isPending ? (
          <div className="mt-pm-4">
            <LoadingState />
          </div>
        ) : historyQuery.isError ? (
          <div className="mt-pm-4">
            <p className="text-sm text-pm-text-secondary">{t('mail.historyError')}</p>
            <BrandButton tone="secondary" onClick={() => void historyQuery.refetch()}>
              {t('common.retry')}
            </BrandButton>
          </div>
        ) : history.length === 0 ? (
          <div className="mt-pm-4 rounded-pm-lg border border-dashed border-pm-border bg-pm-raised p-pm-5 text-center">
            <p className="text-sm text-pm-text-secondary">{t('mail.historyEmpty')}</p>
          </div>
        ) : (
          <ul className="mt-pm-4 space-y-pm-3">
            {history.map((entry) => (
              <li key={entry.id} className="rounded-pm-lg border border-pm-border bg-pm-card p-pm-4">
                <div className="flex flex-wrap items-center justify-between gap-pm-2">
                  <p className="text-sm font-medium text-pm-text-primary">{entry.subject}</p>
                  <span className={`rounded-pm-max px-2.5 py-1 text-xs font-medium ${entry.status === 'SUCCESS' ? 'bg-pm-success/10 text-pm-success' : 'bg-pm-warning/10 text-pm-warning'}`}>
                    {entry.status}
                  </span>
                </div>
                <p className="mt-1 text-xs text-pm-text-secondary">
                  {entry.targetType} · {entry.recipientCount} {t('mail.recipients')} · {new Date(entry.sentAt).toLocaleString()}
                </p>
              </li>
            ))}
          </ul>
        )}
      </GlassPanel>
    </div>
  );
}
