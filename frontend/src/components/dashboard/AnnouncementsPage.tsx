import { useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { useI18n } from '../../i18n/I18nProvider';
import { authenticatedPostJson, ApiError } from '../../lib/api';
import type { AuthSession } from '../../lib/auth-session';
import { GlassPanel } from '../ui/GlassPanel';
import { BrandButton } from '../ui/BrandButton';
import { useActiveCompany } from '../../lib/active-company';

// POST /api/v1/announcements/dispatch (manage_announcements + COMPANY tenant
// scope enforced server-side). The org is forced to the actor's org inside the
// service — the orgId field below is optional and never authoritative.
const ANNOUNCEMENT_TYPES = ['WARNING', 'EMERGENCY', 'MEETING', 'HOLIDAY', 'INFORMATION'] as const;
const AUDIENCES = ['ORGANIZATION', 'ROLE', 'USER'] as const;
const AUDIENCE_ROLES = ['OWNER', 'ADMIN', 'SUPERVISOR', 'ACCOUNTANT', 'STAFF', 'VIEWER'] as const;

interface DispatchResult {
  campaignId: string;
  audience: string;
  orgId: string;
  recipientCount: number;
  createdAt: string;
}

export function AnnouncementsPage({ session }: { session: AuthSession }) {
  const { t } = useI18n();
  const { activeOrgId } = useActiveCompany();
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [type, setType] = useState<(typeof ANNOUNCEMENT_TYPES)[number]>('INFORMATION');
  const [audience, setAudience] = useState<(typeof AUDIENCES)[number]>('ORGANIZATION');
  const [audienceRole, setAudienceRole] = useState<(typeof AUDIENCE_ROLES)[number]>('STAFF');
  const [audienceUserId, setAudienceUserId] = useState('');
  const [result, setResult] = useState<DispatchResult | null>(null);
  const [error, setError] = useState<string | null>(null);

  const canSubmit = title.trim().length >= 2 && body.trim().length >= 2
    && (audience !== 'ROLE' || audienceRole.length > 0)
    && (audience !== 'USER' || audienceUserId.trim().length > 0);

  const dispatchMutation = useMutation({
    mutationFn: () =>
      authenticatedPostJson<{ success: boolean; data: DispatchResult }>(
        '/api/v1/announcements/dispatch',
        session.accessToken,
        {
          title: title.trim(),
          body: body.trim(),
          type,
          audience,
          ...(audience === 'ROLE' ? { audienceRole } : {}),
          ...(audience === 'USER' ? { audienceUserId: audienceUserId.trim() } : {}),
        },
        { 'x-company-id': activeOrgId },
      ).then((response) => response.data),
    onSuccess: (data) => {
      setResult(data);
      setError(null);
    },
    onError: (mutationError) => {
      setResult(null);
      setError(mutationError instanceof ApiError ? mutationError.message : t('announcements.dispatchError'));
    },
  });

  return (
    <div className="space-y-pm-4">
      <GlassPanel>
        <p className="text-[11px] uppercase tracking-[0.34em] text-pm-brand">{t('announcements.supplyTitle')}</p>
        <h2 className="mt-pm-2 text-2xl font-semibold tracking-tight text-pm-text-primary">{t('announcements.title')}</h2>
        <p className="mt-pm-3 text-sm text-pm-text-secondary">{t('announcements.description')}</p>
      </GlassPanel>

      <GlassPanel>
        <div className="space-y-pm-4">
          <input
            type="text"
            value={title}
            onChange={(event) => setTitle(event.target.value)}
            placeholder={t('announcements.titlePlaceholder')}
            aria-label={t('announcements.titlePlaceholder')}
            maxLength={120}
            className="w-full rounded-pm-md border border-pm-border bg-pm-background px-pm-4 py-pm-3 text-sm text-pm-text-primary outline-none placeholder:text-pm-text-tertiary focus:border-pm-brand/50"
          />
          <textarea
            value={body}
            onChange={(event) => setBody(event.target.value)}
            placeholder={t('announcements.bodyPlaceholder')}
            aria-label={t('announcements.bodyPlaceholder')}
            rows={5}
            maxLength={2000}
            className="w-full rounded-pm-md border border-pm-border bg-pm-background px-pm-4 py-pm-3 text-sm leading-6 text-pm-text-primary outline-none placeholder:text-pm-text-tertiary focus:border-pm-brand/50"
          />
          <div className="flex flex-wrap items-center gap-pm-3">
            <label className="flex items-center gap-pm-2 text-sm text-pm-text-secondary">
              {t('announcements.type')}
              <select
                value={type}
                onChange={(event) => setType(event.target.value as (typeof ANNOUNCEMENT_TYPES)[number])}
                className="rounded-pm-md border border-pm-border bg-pm-raised px-3 py-1.5 text-sm text-pm-text-primary"
              >
                {ANNOUNCEMENT_TYPES.map((value) => (
                  <option key={value} value={value}>{t(`announcements.type_${value.toLowerCase()}`)}</option>
                ))}
              </select>
            </label>
            <label className="flex items-center gap-pm-2 text-sm text-pm-text-secondary">
              {t('announcements.audience')}
              <select
                value={audience}
                onChange={(event) => setAudience(event.target.value as (typeof AUDIENCES)[number])}
                className="rounded-pm-md border border-pm-border bg-pm-raised px-3 py-1.5 text-sm text-pm-text-primary"
              >
                {AUDIENCES.map((value) => (
                  <option key={value} value={value}>{t(`announcements.audience_${value.toLowerCase()}`)}</option>
                ))}
              </select>
            </label>
            {audience === 'ROLE' && (
              <label className="flex items-center gap-pm-2 text-sm text-pm-text-secondary">
                {t('mail.role')}
                <select
                  value={audienceRole}
                  onChange={(event) => setAudienceRole(event.target.value as (typeof AUDIENCE_ROLES)[number])}
                  className="rounded-pm-md border border-pm-border bg-pm-raised px-3 py-1.5 text-sm text-pm-text-primary"
                >
                  {AUDIENCE_ROLES.map((role) => (
                    <option key={role} value={role}>{role}</option>
                  ))}
                </select>
              </label>
            )}
            {audience === 'USER' && (
              <input
                type="text"
                value={audienceUserId}
                onChange={(event) => setAudienceUserId(event.target.value)}
                placeholder={t('announcements.userIdPlaceholder')}
                aria-label={t('announcements.userIdPlaceholder')}
                className="flex-1 rounded-pm-md border border-pm-border bg-pm-background px-pm-4 py-pm-3 text-sm text-pm-text-primary outline-none placeholder:text-pm-text-tertiary focus:border-pm-brand/50"
              />
            )}
          </div>
          <div className="flex items-center gap-pm-3">
            <BrandButton
              disabled={dispatchMutation.isPending || !canSubmit}
              onClick={() => void dispatchMutation.mutate()}
            >
              {dispatchMutation.isPending ? t('announcements.dispatching') : t('announcements.dispatch')}
            </BrandButton>
          </div>
          {result && (
            <div className="rounded-pm-lg border border-pm-success/30 bg-pm-success/10 p-pm-3">
              <p className="text-sm text-pm-success">
                {t('announcements.dispatched')}: {result.recipientCount} {t('mail.recipients')}
              </p>
            </div>
          )}
          {error && (
            <div className="rounded-pm-lg border border-pm-danger/30 bg-pm-danger/10 p-pm-3">
              <p className="text-sm text-pm-danger">{error}</p>
            </div>
          )}
        </div>
      </GlassPanel>
    </div>
  );
}
