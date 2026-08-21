import { useState } from 'react';
import { useI18n } from '../../i18n/I18nProvider';
import { GlassPanel } from '../ui/GlassPanel';
import { DataTable } from '../ui/DataTable';

interface PayrollRecord {
  id: string;
  publicId: string;
  name: string;
  period: string;
  baseSalary: string;
  overtime: string;
  deductions: string;
  netPay: string;
  status: 'paid' | 'pending' | 'processed';
}

const mockPayroll: PayrollRecord[] = [
  { id: '1', publicId: 'USR-001', name: 'Aisha Patel', period: 'Jul 2026', baseSalary: '₹42,000', overtime: '₹3,200', deductions: '₹4,200', netPay: '₹41,000', status: 'paid' },
  { id: '2', publicId: 'USR-002', name: 'Raj Singh', period: 'Jul 2026', baseSalary: '₹28,000', overtime: '₹1,800', deductions: '₹2,800', netPay: '₹27,000', status: 'paid' },
  { id: '3', publicId: 'USR-003', name: 'Priya Sharma', period: 'Jul 2026', baseSalary: '₹35,000', overtime: '₹0', deductions: '₹3,500', netPay: '₹31,500', status: 'processed' },
  { id: '4', publicId: 'USR-004', name: 'Karan Mehta', period: 'Jul 2026', baseSalary: '₹30,000', overtime: '₹2,500', deductions: '₹3,000', netPay: '₹29,500', status: 'pending' },
  { id: '5', publicId: 'USR-005', name: 'Sana Ali', period: 'Jul 2026', baseSalary: '₹25,000', overtime: '₹1,200', deductions: '₹2,500', netPay: '₹23,700', status: 'pending' },
];

export function PayrollPage() {
  const { t } = useI18n();
  const [payroll] = useState<PayrollRecord[]>(mockPayroll);

  const paidCount = payroll.filter((p) => p.status === 'paid').length;
  const pendingCount = payroll.filter((p) => p.status === 'pending').length;
  const totalPay = payroll.reduce((sum, p) => sum + parseFloat(p.netPay.replace(/[₹,]/g, '')), 0);

  return (
    <div className="space-y-pm-4">
      <GlassPanel>
        <p className="text-[11px] uppercase tracking-[0.34em] text-pm-brand">{t('dashboard.payroll')}</p>
        <h2 className="mt-pm-2 text-2xl font-semibold tracking-tight text-pm-text-primary">{t('admin.payrollRecords')}</h2>
        <p className="mt-pm-3 text-sm text-pm-text-secondary">{t('admin.payrollDescription')}</p>
      </GlassPanel>

      <section className="grid gap-pm-4 md:grid-cols-3">
        <GlassPanel>
          <p className="text-sm text-pm-text-secondary">{t('admin.totalPayroll')}</p>
          <p className="mt-pm-2 text-2xl font-semibold text-pm-text-primary">₹{totalPay.toLocaleString()}</p>
        </GlassPanel>
        <GlassPanel>
          <p className="text-sm text-pm-text-secondary">{t('admin.paid')}</p>
          <p className="mt-pm-2 text-2xl font-semibold text-pm-success">{paidCount}</p>
        </GlassPanel>
        <GlassPanel>
          <p className="text-sm text-pm-text-secondary">{t('admin.pending')}</p>
          <p className="mt-pm-2 text-2xl font-semibold text-pm-warning">{pendingCount}</p>
        </GlassPanel>
      </section>

      <GlassPanel>
        <div className="flex items-center justify-between">
          <div>
            <p className="text-sm font-semibold text-pm-text-primary">{t('admin.payrollList')}</p>
            <p className="text-sm text-pm-text-secondary">{t('admin.payrollListDescription')}</p>
          </div>
        </div>
        <div className="mt-pm-4">
          <DataTable
            rows={payroll.map((p) => ({
              id: p.id,
              name: p.name,
              status: p.status,
              value: p.netPay,
            }))}
          />
        </div>
      </GlassPanel>
    </div>
  );
}