import { useState } from 'react';
import { useI18n } from '../../i18n/I18nProvider';
import { GlassPanel } from '../ui/GlassPanel';
import { BrandButton } from '../ui/BrandButton';
import { DataTable } from '../ui/DataTable';
import { postJson } from '../../lib/api';

interface User {
  id: string;
  publicId: string;
  name: string;
  email: string;
  role: string;
  status: 'active' | 'inactive';
}

const mockUsers: User[] = [
  { id: '1', publicId: 'USR-001', name: 'Aisha Patel', email: 'aisha@example.com', role: 'Owner', status: 'active' },
  { id: '2', publicId: 'USR-002', name: 'Raj Singh', email: 'raj@example.com', role: 'Worker', status: 'active' },
  { id: '3', publicId: 'USR-003', name: 'Priya Sharma', email: 'priya@example.com', role: 'Owner', status: 'active' },
  { id: '4', publicId: 'USR-004', name: 'Karan Mehta', email: 'karan@example.com', role: 'Admin', status: 'inactive' },
  { id: '5', publicId: 'USR-005', name: 'Sana Ali', email: 'sana@example.com', role: 'Worker', status: 'active' },
];

export function UserSearchPage() {
  const { t } = useI18n();
  const [query, setQuery] = useState('');
  const [users, setUsers] = useState<User[]>(mockUsers);
  const [searching, setSearching] = useState(false);

  const handleSearch = async () => {
    setSearching(true);
    try {
      const results = await postJson<{ users: User[] }>('/users/search', { query });
      setUsers(results.users);
    } catch {
      setUsers(mockUsers);
    } finally {
      setSearching(false);
    }
  };

  const filteredUsers = query
    ? users.filter(
        (u) =>
          u.name.toLowerCase().includes(query.toLowerCase()) ||
          u.publicId.toLowerCase().includes(query.toLowerCase()) ||
          u.email.toLowerCase().includes(query.toLowerCase()),
      )
    : users;

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
            className="flex-1 rounded-pm-md border border-pm-border bg-pm-background px-pm-4 py-pm-3 text-sm text-pm-text-primary outline-none placeholder:text-pm-text-tertiary focus:border-pm-brand/50"
          />
          <BrandButton onClick={handleSearch}>{searching ? t('admin.searching') : t('admin.search')}</BrandButton>
        </div>
      </GlassPanel>

      <GlassPanel>
        <div className="flex items-center justify-between">
          <div>
            <p className="text-sm font-semibold text-pm-text-primary">{t('admin.searchResults')}</p>
            <p className="text-sm text-pm-text-secondary">{filteredUsers.length} {t('admin.usersFound')}</p>
          </div>
        </div>
        <div className="mt-pm-4">
          <DataTable
            rows={filteredUsers.map((u) => ({
              id: u.id,
              name: u.name,
              status: u.status,
              value: u.publicId,
            }))}
          />
        </div>
        {filteredUsers.length === 0 && (
          <div className="mt-pm-4 rounded-pm-xl border border-dashed border-pm-border bg-pm-surface p-pm-8 text-center">
            <p className="text-sm text-pm-text-secondary">{t('admin.noUsersFound')}</p>
          </div>
        )}
      </GlassPanel>
    </div>
  );
}