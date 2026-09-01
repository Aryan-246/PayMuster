import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useI18n } from '../../i18n/I18nProvider';
import { authenticatedGetJson } from '../../lib/api';
import type { AuthSession } from '../../lib/auth-session';
import { useActiveCompany } from '../../lib/active-company';

interface MembershipCompany {
  orgId: string;
  name: string;
  publicId: string | null;
  role: string;
  status: string;
}

interface MembershipsResponse {
  success: boolean;
  data: {
    multiCompanyEnabled: boolean;
    primary: { orgId: string; name: string; publicId: string | null } | null;
    memberships: MembershipCompany[];
  };
  meta: { requestId: string };
}

/**
 * Company switcher (blueprint §L). Renders NOTHING while the multi-company
 * feature flag is OFF server-side (the default) — the endpoint honestly
 * reports the flag and an empty switchable list, so this stays dormant
 * without any client-side configuration. When enabled and the user holds
 * additional ACTIVE memberships, switching re-points every dashboard query at
 * the selected company (the backend re-authorizes each request) and
 * invalidates all cached data so no cross-company data leaks between views.
 */
export function CompanySwitcher({ session }: { session: AuthSession }) {
  const { t } = useI18n();
  const { activeOrgId, setActiveOrgId } = useActiveCompany();
  const queryClient = useQueryClient();

  const membershipsQuery = useQuery({
    queryKey: ['company-memberships', session.user.id],
    queryFn: () => authenticatedGetJson<MembershipsResponse>('/api/v1/company/memberships', session.accessToken),
    staleTime: 5 * 60 * 1000,
  });

  const data = membershipsQuery.data?.data;
  // Dormant by default: no flag, no memberships → nothing rendered.
  if (!data?.multiCompanyEnabled || data.memberships.length === 0 || !data.primary) {
    return null;
  }

  const options = [data.primary, ...data.memberships];

  return (
    <label className="flex items-center gap-pm-2">
      <span className="sr-only">{t('topbar.activeCompany')}</span>
      <select
        value={activeOrgId || data.primary.orgId}
        onChange={(event) => {
          const next = event.target.value;
          setActiveOrgId(next === data.primary?.orgId ? data.primary.orgId : next);
          // Drop every cached query — switching companies must never show the
          // previous company's data in the new context.
          void queryClient.invalidateQueries();
        }}
        className="min-h-10 rounded-pm-md border border-pm-border bg-pm-card px-pm-3 text-sm text-pm-text-primary focus-visible:outline focus-visible:outline-2 focus-visible:outline-pm-brand"
      >
        {options.map((option) => (
          <option key={option.orgId} value={option.orgId}>
            {option.name}
          </option>
        ))}
      </select>
    </label>
  );
}
