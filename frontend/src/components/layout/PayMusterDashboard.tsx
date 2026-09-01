import { useI18n } from '../../i18n/I18nProvider';
import { BrandButton } from '../ui/BrandButton';
import { GlassPanel } from '../ui/GlassPanel';
import { LoadingState } from '../ui/LoadingState';
import { PayMusterSidebar } from './PayMusterSidebar';
import { PayMusterTopbar } from './PayMusterTopbar';
import { BrowserRouter, Routes, Route, Link, useNavigate } from 'react-router-dom';
import { useQuery, useMutation } from '@tanstack/react-query';
import { useState } from 'react';
import { ActiveCompanyContext, useActiveCompany } from '../../lib/active-company';
import { authenticatedGetJson, authenticatedPostJson, ApiError } from '../../lib/api';
import { hasPermission } from '../../lib/permissions';
import type { AuthSession } from '../../lib/auth-session';
import { OwnerRequestsPage } from '../admin/OwnerRequestsPage';
import { UserSearchPage } from '../admin/UserSearchPage';
import { UserProfilePage } from '../admin/UserProfilePage';
import { AnnouncementsPage } from '../dashboard/AnnouncementsPage';
import { AttendancePage } from '../dashboard/AttendancePage';
import { MailSupplyPage } from '../dashboard/MailSupplyPage';
import { PayrollPage } from '../dashboard/PayrollPage';
import { StaffPage } from '../dashboard/StaffPage';
import { SubscriptionPage } from '../dashboard/SubscriptionPage';

// Shape of the fields we render from GET /api/v1/company (company.service.getOverview).
// Every value shown on this page is derived from this real response — no demo data.
interface CompanyOverview {
  id: string;
  name: string;
  _count: { users: number; sites: number; staff: number };
  financialSummary: {
    expenses: { includedStatuses: string[]; siteLinkedTotal: string; companyLevelTotal: string };
    payRuns: { recordedCount: number; recordedTotal: string };
  };
}

interface ApiEnvelope<T> {
  success: boolean;
  data: T;
}

// Financial totals arrive as decimal strings to preserve precision; format for display only.
function formatInr(value: string): string {
  const amount = Number(value);
  if (!Number.isFinite(amount)) return '₹0';
  return new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    maximumFractionDigits: 0,
  }).format(amount);
}

function DashboardHome({ session }: { session: AuthSession }) {
  const { t } = useI18n();
  const { activeOrgId } = useActiveCompany();
  const navigate = useNavigate();
  const [aiPrompt, setAiPrompt] = useState('');
  const canUseAi = hasPermission(session.user.role, 'use_ai');
  const canViewAttendance = hasPermission(session.user.role, 'view_attendance');

  // Tenant scope travels in the x-company-id header — the same header requireTenant
  // reads server-side — so the API answers for exactly this user's organization.
  const overviewQuery = useQuery({
    queryKey: ['company-overview', activeOrgId],
    queryFn: () =>
      authenticatedGetJson<ApiEnvelope<CompanyOverview>>('/api/v1/company', session.accessToken, {
        'x-company-id': activeOrgId,
      }).then((response) => response.data),
    enabled: Boolean(activeOrgId),
  });

  // Real AI call — POST /api/v1/ai/insights (requirePermission('use_ai') +
  // tenant scope enforced server-side; the client check is cosmetic only).
  const aiMutation = useMutation({
    mutationFn: (prompt: string) =>
      authenticatedPostJson<{
        success: boolean;
        data: { analysis: string; metadata: { provider: string | null; model: string | null; generatedAt: string } };
      }>('/api/v1/ai/insights', session.accessToken, { prompt }).then((response) => response.data),
  });

  const overview = overviewQuery.data;
  const metricCards = overview
    ? [
        {
          label: t('metric.staff'),
          value: String(overview._count.staff),
          hint: `${overview._count.users} ${t('metric.accounts')}`,
        },
        {
          label: t('metric.payrollRecorded'),
          value: formatInr(overview.financialSummary.payRuns.recordedTotal),
          hint: `${overview.financialSummary.payRuns.recordedCount} ${t('metric.payRuns')}`,
        },
        {
          label: t('metric.sites'),
          value: String(overview._count.sites),
          hint: undefined as string | undefined,
        },
        {
          label: t('metric.expenses'),
          value: formatInr(
            String(
              Number(overview.financialSummary.expenses.siteLinkedTotal) +
                Number(overview.financialSummary.expenses.companyLevelTotal),
            ),
          ),
          hint: t('metric.reportable'),
        },
      ]
    : [];

  return (
    <>
      <section className="grid gap-pm-4 xl:grid-cols-[1.4fr_0.8fr]">
        <GlassPanel>
          <p className="text-[11px] uppercase tracking-[0.34em] text-pm-brand">{t('dashboard.operatingSystem')}</p>
          <h2 className="mt-pm-2 max-w-2xl text-3xl font-semibold tracking-tight text-pm-text-primary">{t('dashboard.heroTitle')}</h2>
          <p className="mt-pm-3 max-w-xl text-sm leading-6 text-pm-text-secondary">{t('dashboard.heroDescription')}</p>
          <div className="mt-pm-5 flex flex-wrap gap-pm-3">
            {canViewAttendance && (
              <BrandButton onClick={() => navigate('/dashboard/attendance')}>{t('dashboard.reviewToday')}</BrandButton>
            )}
          </div>
        </GlassPanel>
        <GlassPanel>
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-semibold text-pm-text-primary">{t('dashboard.companySnapshot')}</p>
              <p className="text-sm text-pm-text-secondary">{t('dashboard.snapshotDescription')}</p>
            </div>
          </div>
          {overviewQuery.isPending ? (
            <div className="mt-pm-5">
              <LoadingState />
            </div>
          ) : overviewQuery.isError ? (
            <p className="mt-pm-5 text-sm text-pm-text-secondary">{t('dashboard.overviewError')}</p>
          ) : overview ? (
            <div className="mt-pm-5 space-y-pm-3">
              {[
                [t('dashboard.staffOnRecord'), String(overview._count.staff)],
                [t('dashboard.sitesTracked'), String(overview._count.sites)],
                [t('dashboard.teamAccounts'), String(overview._count.users)],
              ].map(([label, value]) => (
                <div key={label} className="rounded-pm-lg border border-pm-border bg-pm-raised p-pm-3">
                  <p className="text-sm text-pm-text-secondary">{label}</p>
                  <p className="mt-1 font-medium text-pm-text-primary">{value}</p>
                </div>
              ))}
            </div>
          ) : null}
        </GlassPanel>
      </section>
      <section className="grid gap-pm-4 md:grid-cols-2 xl:grid-cols-4">
        {overviewQuery.isPending ? (
          [0, 1, 2, 3].map((item) => <LoadingState key={item} />)
        ) : overviewQuery.isError ? (
          <div className="md:col-span-2 xl:col-span-4">
            <GlassPanel>
              <p className="text-sm font-semibold text-pm-text-primary">{t('dashboard.overviewError')}</p>
              <div className="mt-pm-4">
                <BrandButton tone="secondary" onClick={() => void overviewQuery.refetch()}>
                  {t('common.retry')}
                </BrandButton>
              </div>
            </GlassPanel>
          </div>
        ) : (
          metricCards.map((card) => (
            <GlassPanel key={card.label}>
              <p className="text-sm text-pm-text-secondary">{card.label}</p>
              <div className="mt-pm-4 flex items-end justify-between">
                <p className="text-2xl font-semibold text-pm-text-primary">{card.value}</p>
                {card.hint ? (
                  <span className="rounded-pm-max bg-pm-brand/10 px-2.5 py-1 text-xs font-medium text-pm-brand">{card.hint}</span>
                ) : null}
              </div>
            </GlassPanel>
          ))
        )}
      </section>
      <section className="grid gap-pm-4 xl:grid-cols-[1.15fr_0.85fr]">
        <GlassPanel>
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-semibold text-pm-text-primary">{t('dashboard.todayWorkforce')}</p>
              <p className="text-sm text-pm-text-secondary">{t('dashboard.timelineDescription')}</p>
            </div>
            {canViewAttendance ? (
              <Link
                to="/dashboard/attendance"
                className="rounded-pm-max border border-pm-border bg-pm-raised px-3 py-1.5 text-sm text-pm-text-secondary transition duration-pm-fast hover:text-pm-text-primary"
              >
                {t('dashboard.openTimeline')}
              </Link>
            ) : null}
          </div>
          <div className="mt-pm-5 rounded-pm-lg border border-dashed border-pm-border bg-pm-raised p-pm-5 text-center">
            <p className="text-sm text-pm-text-secondary">{t('dashboard.activityEmpty')}</p>
          </div>
        </GlassPanel>
        <GlassPanel>
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-semibold text-pm-text-primary">{t('dashboard.aiInsight')}</p>
              <p className="text-sm text-pm-text-secondary">{t('dashboard.aiDescription')}</p>
            </div>
          </div>
          {canUseAi ? (
            <div className="mt-pm-5">
              <div className="flex gap-pm-3">
                <input
                  type="text"
                  value={aiPrompt}
                  onChange={(event) => setAiPrompt(event.target.value)}
                  placeholder={t('dashboard.aiPromptPlaceholder')}
                  aria-label={t('dashboard.aiInsight')}
                  className="flex-1 rounded-pm-md border border-pm-border bg-pm-background px-pm-4 py-pm-3 text-sm text-pm-text-primary outline-none placeholder:text-pm-text-tertiary focus:border-pm-brand/50"
                />
                <BrandButton
                  disabled={aiMutation.isPending || aiPrompt.trim().length === 0}
                  onClick={() => aiMutation.mutate(aiPrompt.trim())}
                >
                  {aiMutation.isPending ? '…' : t('dashboard.aiGenerate')}
                </BrandButton>
              </div>
              {aiMutation.isPending ? (
                <div className="mt-pm-4">
                  <LoadingState />
                </div>
              ) : aiMutation.isError ? (
                <div className="mt-pm-4 rounded-pm-xl border border-pm-danger/20 bg-pm-danger/10 p-pm-4">
                  <p className="text-sm text-pm-danger">
                    {aiMutation.error instanceof ApiError
                      ? aiMutation.error.message
                      : t('dashboard.aiError')}
                  </p>
                  <div className="mt-pm-3">
                    <BrandButton
                      tone="secondary"
                      onClick={() => aiMutation.mutate(aiMutation.variables ?? aiPrompt.trim())}
                    >
                      {t('common.retry')}
                    </BrandButton>
                  </div>
                </div>
              ) : aiMutation.data ? (
                <div className="mt-pm-4 rounded-pm-xl border border-pm-info/20 bg-pm-info/10 p-pm-4">
                  <p className="whitespace-pre-wrap text-sm leading-6 text-pm-text-secondary">{aiMutation.data.analysis}</p>
                  <p className="mt-pm-2 text-xs text-pm-text-tertiary">
                    {aiMutation.data.metadata.provider ?? 'ai'} · {new Date(aiMutation.data.metadata.generatedAt).toLocaleString()}
                  </p>
                </div>
              ) : (
                <div className="mt-pm-4 rounded-pm-xl border border-dashed border-pm-border bg-pm-raised p-pm-4 text-center">
                  <p className="text-sm text-pm-text-secondary">{t('dashboard.aiEmpty')}</p>
                </div>
              )}
            </div>
          ) : (
            <div className="mt-pm-5 rounded-pm-xl border border-dashed border-pm-border bg-pm-raised p-pm-4 text-center">
              <p className="text-sm text-pm-text-secondary">{t('dashboard.aiNotPermitted')}</p>
            </div>
          )}
        </GlassPanel>
      </section>
    </>
  );
}

function DashboardContent({ session }: { session: AuthSession }) {
  // The company the dashboard operates in — defaults to the session's primary
  // org and is only switchable when the multi-company flag is enabled
  // server-side (see CompanySwitcher). The backend re-authorizes every
  // request against this company id.
  const [activeOrgId, setActiveOrgId] = useState<string>(session.user.orgId);
  return (
    <ActiveCompanyContext.Provider value={{ activeOrgId, setActiveOrgId }}>
      <div className="min-h-screen bg-pm-background px-pm-4 py-pm-4 text-pm-text-primary md:px-pm-6 lg:px-pm-8 lg:py-pm-6">
        <div className="mx-auto flex max-w-7xl gap-pm-4">
          <PayMusterSidebar session={session} />
          <main className="flex-1 space-y-pm-4">
            <PayMusterTopbar session={session} />
            <Routes>
              <Route path="/" element={<DashboardHome session={session} />} />
              <Route path="/admin/owner-requests" element={<OwnerRequestsPage session={session} />} />
              <Route path="/admin/users" element={<UserSearchPage session={session} />} />
              <Route path="/admin/users/:id" element={<UserProfilePage session={session} />} />
              <Route path="/dashboard/attendance" element={<AttendancePage session={session} />} />
              <Route path="/dashboard/payroll" element={<PayrollPage session={session} />} />
              <Route path="/dashboard/staff" element={<StaffPage session={session} />} />
              <Route path="/dashboard/mail" element={<MailSupplyPage session={session} />} />
              <Route path="/dashboard/announcements" element={<AnnouncementsPage session={session} />} />
              <Route path="/dashboard/subscription" element={<SubscriptionPage session={session} />} />
            </Routes>
          </main>
        </div>
      </div>
    </ActiveCompanyContext.Provider>
  );
}

export function PayMusterDashboard({ session }: { session: AuthSession }) {
  return (
    <BrowserRouter>
      <DashboardContent session={session} />
    </BrowserRouter>
  );
}
