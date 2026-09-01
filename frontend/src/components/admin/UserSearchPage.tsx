import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useI18n } from '../../i18n/I18nProvider';
import { authenticatedGetJson } from '../../lib/api';
import type { AuthSession } from '../../lib/auth-session';
import { GlassPanel } from '../ui/GlassPanel';
import { LoadingState } from '../ui/LoadingState';
import { BrandButton } from '../ui/BrandButton';
import { DataTable } from '../ui/DataTable';

// Mirrors adminService.searchUsers' select shape — GET /api/v1/admin/users?q=
// (manage_system = SUPER_ADMIN-only server-side).
interface AdminUserRecord {
  id: string;
  publicId: string | null;
  email: string | null;
  phone: string | null;
  firstName: string | null;
  lastName: string | null;
  role: string;
  status: string;
  isDisabled: boolean;
  createdAt: string;
  lastLoginAt: string | null;
  org: { id: string; name: string; publicId: string | null; joinCode: string | null } | null;
}

interface AdminUsersEnvelope {
  success: boolean;
  data: AdminUserRecord[];
  meta: { requestId: string; total: number; page: number; totalPages: number };
}

export function UserSearchPage({ session }: { session: AuthSession }) {
  const { t } = useI18n();
  const [query, setQuery] = useState('');

  // Search runs server-side (searchUsers filters email/name/phone/publicId);
  // an empty query lists the most recent users. Pagination metadata is real.
  const usersQuery = useQuery({
    queryKey: ['admin-users', query],
    queryFn: () => {
      const search = query.trim() ? `?q=${encodeURIComponent(query.trim())}` : '';
      return authenticatedGetJson<AdminUsersEnvelope>(`/api/v1/admin/users${search}`, session.accessToken);
    },
  });

  const users = usersQuery.data?.data ?? [];
  const total = usersQuery.data?.meta.total ?? 0;

  return (
    <div className="space-y-pm-4">
      <GlassPanel>
        <p className="text-[11px] uppercase tracking-[0.34em] text-pm-brand">{t('admin.userSearch')}</p>
        <h2 className="mt-pm-2 text-2xl font-semibold tracking-tight text-pm-text-primary">{t('admin.userSearchTitle')}</h2>
        <p className="mt-pm-3 text-sm text-pm-text-secondary">{t('admin.userSearchDescription')}</p>
      </GlassPanel>

      <GlassPanel>
        <div className="flex gap-pm-3">
          <input
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder={t('admin.searchPlaceholder')}
            aria-label={t('admin.searchPlaceholder')}
            className="flex-1 rounded-pm-md border border-pm-border bg-pm-background px-pm-4 py-pm-3 text-sm text-pm-text-primary outline-none placeholder:text-pm-text-tertiary focus:border-pm-brand/50"
          />
          <BrandButton onClick={() => void usersQuery.refetch()}>
            {usersQuery.isFetching ? t('admin.searching') : t('admin.search')}
          </BrandButton>
        </div>
      </GlassPanel>

      {usersQuery.isPending ? (
        <LoadingState />
      ) : usersQuery.isError ? (
        <GlassPanel>
          <p className="text-sm font-semibold text-pm-text-primary">{t('admin.searchLoadError')}</p>
          <div className="mt-pm-4">
            <BrandButton tone="secondary" onClick={() => void usersQuery.refetch()}>
              {t('common.retry')}
            </BrandButton>
          </div>
        </GlassPanel>
      ) : users.length === 0 ? (
        <GlassPanel>
          <div className="rounded-pm-lg border border-dashed border-pm-border bg-pm-raised p-pm-5 text-center">
            <p className="text-sm text-pm-text-secondary">{t('admin.noUsersFound')}</p>
          </div>
        </GlassPanel>
      ) : (
        <GlassPanel>
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-semibold text-pm-text-primary">{t('admin.searchResults')}</p>
              <p className="text-sm text-pm-text-secondary">
                {total} {t('admin.usersFound')}
              </p>
            </div>
          </div>
          <div className="mt-pm-4">
            <DataTable
              rows={users.map((user) => ({
                id: user.id,
                name: `${user.firstName ?? ''} ${user.lastName ?? ''}`.trim() || user.email || user.publicId || user.id,
                status: user.isDisabled ? 'blocked' : user.status.toLowerCase(),
                statusLabel: user.isDisabled ? 'BLOCKED' : user.status.toLowerCase(),
                value: `${user.publicId ?? '—'} · ${user.role}${user.org ? ` · ${user.org.name}` : ''}`,
              }))}
            />
          </div>
        </GlassPanel>
      )}
    </div>
  );
}
