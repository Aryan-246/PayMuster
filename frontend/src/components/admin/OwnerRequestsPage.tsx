import { useState } from 'react';
import { useI18n } from '../../i18n/I18nProvider';
import { GlassPanel } from '../ui/GlassPanel';
import { BrandButton } from '../ui/BrandButton';
import { DataTable } from '../ui/DataTable';

interface OwnerRequest {
  id: string;
  publicId: string;
  name: string;
  email: string;
  role: string;
  status: 'pending' | 'approved' | 'rejected';
  createdAt: string;
}

const mockRequests: OwnerRequest[] = [
  { id: '1', publicId: 'USR-001', name: 'Aisha Patel', email: 'aisha@example.com', role: 'Owner', status: 'pending', createdAt: '2026-07-28' },
  { id: '2', publicId: 'USR-002', name: 'Raj Singh', email: 'raj@example.com', role: 'Owner', status: 'pending', createdAt: '2026-07-29' },
  { id: '3', publicId: 'USR-003', name: 'Priya Sharma', email: 'priya@example.com', role: 'Owner', status: 'approved', createdAt: '2026-07-25' },
  { id: '4', publicId: 'USR-004', name: 'Karan Mehta', email: 'karan@example.com', role: 'Owner', status: 'rejected', createdAt: '2026-07-20' },
];

export function OwnerRequestsPage() {
  const { t } = useI18n();
  const [requests, setRequests] = useState<OwnerRequest[]>(mockRequests);

  const handleApprove = (id: string) => {
    setRequests((prev) =>
      prev.map((req) => (req.id === id ? { ...req, status: 'approved' } : req)),
    );
  };

  const handleReject = (id: string) => {
    setRequests((prev) =>
      prev.map((req) => (req.id === id ? { ...req, status: 'rejected' } : req)),
    );
  };

  const pendingRequests = requests.filter((r) => r.status === 'pending');

  return (
    <div className="space-y-pm-4">
      <GlassPanel>
        <p className="text-[11px] uppercase tracking-[0.34em] text-pm-brand">{t('admin.ownerRequests')}</p>
        <h2 className="mt-pm-2 text-2xl font-semibold tracking-tight text-pm-text-primary">{t('admin.ownerRequestsTitle')}</h2>
        <p className="mt-pm-3 text-sm text-pm-text-secondary">{t('admin.ownerRequestsDescription')}</p>
      </GlassPanel>

      <section className="grid gap-pm-4 md:grid-cols-3">
        <GlassPanel>
          <p className="text-sm text-pm-text-secondary">{t('admin.totalRequests')}</p>
          <p className="mt-pm-2 text-2xl font-semibold text-pm-text-primary">{requests.length}</p>
        </GlassPanel>
        <GlassPanel>
          <p className="text-sm text-pm-text-secondary">{t('admin.pending')}</p>
          <p className="mt-pm-2 text-2xl font-semibold text-pm-warning">{pendingRequests.length}</p>
        </GlassPanel>
        <GlassPanel>
          <p className="text-sm text-pm-text-secondary">{t('admin.approved')}</p>
          <p className="mt-pm-2 text-2xl font-semibold text-pm-success">{requests.filter((r) => r.status === 'approved').length}</p>
        </GlassPanel>
      </section>

      <GlassPanel>
        <div className="flex items-center justify-between">
          <div>
            <p className="text-sm font-semibold text-pm-text-primary">{t('admin.requestsList')}</p>
            <p className="text-sm text-pm-text-secondary">{t('admin.requestsListDescription')}</p>
          </div>
        </div>
        <div className="mt-pm-4">
          <DataTable
            rows={requests.map((req) => ({
              id: req.id,
              name: req.name,
              status: req.status,
              value: req.publicId,
            }))}
          />
        </div>
        <div className="mt-pm-4 flex flex-wrap gap-pm-3">
          {pendingRequests.map((req) => (
            <div key={req.id} className="flex items-center gap-pm-3 rounded-pm-lg border border-pm-border bg-pm-raised p-pm-3">
              <div className="flex-1">
                <p className="text-sm font-medium text-pm-text-primary">{req.name}</p>
                <p className="text-xs text-pm-text-secondary">{req.publicId} · {req.email}</p>
              </div>
              <BrandButton tone="primary" onClick={() => handleApprove(req.id)}>{t('admin.approve')}</BrandButton>
              <BrandButton tone="secondary" onClick={() => handleReject(req.id)}>{t('admin.reject')}</BrandButton>
            </div>
          ))}
          {pendingRequests.length === 0 && (
            <p className="text-sm text-pm-text-secondary">{t('admin.noPendingRequests')}</p>
          )}
        </div>
      </GlassPanel>
    </div>
  );
}