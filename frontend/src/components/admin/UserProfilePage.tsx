import { useState } from 'react';
import { useI18n } from '../../i18n/I18nProvider';
import { GlassPanel } from '../ui/GlassPanel';
import { BrandButton } from '../ui/BrandButton';
import { postJson } from '../../lib/api';

interface UserProfile {
  id: string;
  publicId: string;
  name: string;
  email: string;
  role: string;
  orgId: string;
  status: 'active' | 'inactive' | 'suspended';
  lastLogin: string;
}

const profile: UserProfile = {
  id: 'usr_abc123',
  publicId: 'USR-001',
  name: 'Aisha Patel',
  email: 'aisha@example.com',
  role: 'Owner',
  orgId: 'org_xyz789',
  status: 'active',
  lastLogin: '2026-08-05T14:30:00Z',
};

export function UserProfilePage() {
  const { t } = useI18n();
  const [actionMessage, setActionMessage] = useState<string | null>(null);

  const handleAction = async (action: string) => {
    setActionMessage(null);
    try {
      await postJson<{ message: string }>('/action', { action, userId: profile.id });
      setActionMessage(`${t('admin.actionSuccess')}: ${action}`);
    } catch {
      setActionMessage(`${t('admin.actionFailed')}: ${action}`);
    }
  };

  const statusColors: Record<UserProfile['status'], string> = {
    active: 'bg-pm-success/10 text-pm-success',
    inactive: 'bg-pm-warning/10 text-pm-warning',
    suspended: 'bg-pm-error/10 text-pm-error',
  };

  return (
    <div className="space-y-pm-4">
      <GlassPanel>
        <p className="text-[11px] uppercase tracking-[0.34em] text-pm-brand">{t('admin.userProfile')}</p>
        <h2 className="mt-pm-2 text-2xl font-semibold tracking-tight text-pm-text-primary">{t('admin.userProfileTitle')}</h2>
      </GlassPanel>

      <section className="grid gap-pm-4 md:grid-cols-2">
        <GlassPanel>
          <p className="text-sm font-semibold text-pm-text-primary">{t('admin.userDetails')}</p>
          <div className="mt-pm-4 space-y-pm-3">
            <div className="flex justify-between text-sm">
              <span className="text-pm-text-secondary">{t('admin.name')}</span>
              <span className="font-medium text-pm-text-primary">{profile.name}</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-pm-text-secondary">{t('admin.email')}</span>
              <span className="font-medium text-pm-text-primary">{profile.email}</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-pm-text-secondary">{t('admin.publicId')}</span>
              <span className="font-mono text-sm font-medium text-pm-brand">{profile.publicId}</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-pm-text-secondary">{t('admin.role')}</span>
              <span className="font-medium text-pm-text-primary">{profile.role}</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-pm-text-secondary">{t('admin.status')}</span>
              <span className={`rounded-pm-max px-2.5 py-1 text-xs font-medium ${statusColors[profile.status]}`}>{profile.status}</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-pm-text-secondary">{t('admin.lastLogin')}</span>
              <span className="font-medium text-pm-text-primary">{new Date(profile.lastLogin).toLocaleString()}</span>
            </div>
          </div>
        </GlassPanel>

        <GlassPanel>
          <p className="text-sm font-semibold text-pm-text-primary">{t('admin.actions')}</p>
          <p className="mt-pm-2 text-sm text-pm-text-secondary">{t('admin.actionsDescription')}</p>
          <div className="mt-pm-5 flex flex-wrap gap-pm-3">
            <BrandButton onClick={() => handleAction('activate')}>{t('admin.activate')}</BrandButton>
            <BrandButton tone="secondary" onClick={() => handleAction('suspend')}>{t('admin.suspend')}</BrandButton>
            <BrandButton tone="secondary" onClick={() => handleAction('reset_password')}>{t('admin.resetPassword')}</BrandButton>
            <BrandButton tone="secondary" onClick={() => handleAction('send_email')}>{t('admin.sendEmail')}</BrandButton>
          </div>
          {actionMessage && (
            <div className="mt-pm-4 rounded-pm-lg border border-pm-border bg-pm-raised p-pm-3">
              <p className="text-sm text-pm-text-primary">{actionMessage}</p>
            </div>
          )}
        </GlassPanel>
      </section>
    </div>
  );
}