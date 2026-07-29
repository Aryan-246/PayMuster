# Engineering Roadmap

## Development Philosophy

PayMuster is built **feature-by-feature**, not layer-by-layer. Every feature follows this strict lifecycle before the next one begins:

```
Planning → Database → API → Backend → Frontend → Testing → Review
```

If at any point the architecture needs improvement, we **stop, explain, and improve the architecture first** — then resume. We never rush implementation. This software will be maintained for 10 years.

---

## Phase 1: Foundation & Identity (Weeks 1–3)

**Goal**: Authentication, organization setup, and role-based access control.

### Deliverables
- **Authentication System**: Email/phone login with JWT + Refresh Tokens. Secure token storage. Logout and session invalidation.
- **Organization Onboarding**: Create organization with name, logo, address, GSTIN. Configure default settings (currency, date format, financial year).
- **User Management**: Invite users, assign roles (Owner, Admin, Supervisor, Accountant, Staff, Viewer). Deactivate users.
- **RBAC Middleware**: Every API endpoint enforces role-based permission checks. Unauthorized access returns `403` and logs a security event.
- **Audit Log Foundation**: The audit log table and service are deployed from Day 1. Every mutation is logged.

### Database
- `organizations`, `users`, `roles`, `permissions`, `sessions`, `audit_logs`

### Testing
- Auth flow: login, token refresh, logout, expired token handling.
- RBAC: verify every role can/cannot access expected endpoints.

---

## Phase 2: Staff & Sites (Weeks 4–6)

**Goal**: The two foundational entities — workers and job sites.

### Deliverables
- **Staff CRUD**: Create, read, update, deactivate workers with full profile (identity, rates, bank details, documents).
- **Staff Search & Filter**: Search by name/phone. Filter by status, site, worker type.
- **Document Upload**: Secure upload and storage of Aadhaar, PAN, bank passbook, and other documents.
- **Sites CRUD**: Create, read, update, archive job sites with geo-coordinates and geo-fence radius.
- **Worker-Site Assignment**: Assign/reassign workers to sites. Track assignment history.
- **Offline Sync V1**: Staff and site data available offline on mobile. Create operations queued locally and synced when online.

### Database
- `staff`, `staff_documents`, `sites`, `site_assignments`

### Testing
- Staff CRUD operations with validation (duplicate phone numbers, required fields).
- Site geo-fence boundary calculations.
- Offline queue: create a staff record offline, verify it syncs correctly.

---

## Phase 3: Attendance (Weeks 7–9)

**Goal**: The field-critical module. GPS + photo + supervisor-verified attendance.

### Deliverables
- **Daily Attendance Marking**: Supervisor marks attendance for all workers at a site — Present, Absent, Half Day, Leave.
- **GPS Capture**: Automatic GPS coordinate capture at check-in and check-out.
- **Photo Proof**: Camera integration for timestamped attendance photos.
- **Overtime Tracking**: Automatic calculation when hours exceed the worker's configured threshold.
- **Shift Types**: Support for Regular, Night, and Double shifts.
- **Correction Requests**: Staff can submit correction requests. Supervisor/Admin approve or reject.
- **Offline Attendance**: Full attendance marking workflow works offline. Sync with conflict resolution when online.

### Database
- `attendance_records`, `correction_requests`

### Testing
- Attendance record creation with GPS validation.
- Overtime calculation accuracy for edge cases (exactly at threshold, one minute over, etc.).
- Offline conflict: two supervisors mark attendance for the same worker — verify conflict resolution.

---

## Phase 4: Payroll & Salary Engine (Weeks 10–13)

**Goal**: The mathematical core — accurate pay calculation for every rate combination.

### Deliverables
- **Salary Rules Configuration**: Per-worker rate setup (hourly, daily, monthly, overtime, night, holiday, Sunday, custom).
- **Pay Cycle Management**: Create pay cycles (weekly, bi-weekly, monthly, custom range).
- **Auto-Calculation Engine**: Generate gross pay from attendance records + salary rules. Handle all rate types, deductions (advances, penalties), and additions (bonuses, allowances).
- **Pay Run Workflow**: Generate → Review (editable with notes) → Approve → Process.
- **Pay Slips**: Generate per-worker pay slips showing line-item breakdown.

### Database
- `salary_rules`, `pay_cycles`, `pay_runs`, `pay_run_items`, `deductions`, `additions`

### Testing
- **Property-based salary tests**: Test every rate combination (hourly worker with overtime on a holiday night shift with a pending advance).
- Pay run idempotency: running the calculation twice produces identical results.
- Edge cases: zero attendance days, worker added mid-cycle, rate changed mid-cycle.

---

## Phase 5: Payments & Expenses (Weeks 14–16)

**Goal**: Money movement with strict approval workflows and audit trails.

### Deliverables
- **Payment Processing**: Create payment records linked to pay runs. Support UPI, Bank Transfer, Cash.
- **Approval Workflow**: Payments require Admin/Owner approval. Confirmation dialog before submission.
- **Payment Rules Enforcement**: Workers can view, cannot modify/delete/approve. Every edit → audit log.
- **Advance Management**: Request, approve, disburse, and auto-deduct advances.
- **Expense Tracking**: Submit, approve, reimburse expenses. Mandatory receipt photo above threshold.
- **Expense Categories**: Fuel, Tools, Food, Transport, Rental, Miscellaneous (AI-suggested).

### Database
- `payments`, `payment_approvals`, `advances`, `expenses`, `expense_receipts`

### Testing
- Payment approval workflow: submit → approve → verify audit log entry.
- Advance deduction: verify correct amount is deducted from next payroll.
- Expense threshold: verify receipt photo is required above configured amount.

---

## Phase 6: Assets & Materials (Weeks 17–19)

**Goal**: Physical asset and material tracking at the site level.

### Deliverables
- **Asset Registry**: CRUD for tools, equipment, vehicles. Track condition, location, and assignment.
- **Asset Lifecycle**: Issue → Use → Return → Inspect → Retire. Photo proof at each stage.
- **Material Inventory**: Per-site stock tracking with inward, consumption, transfer, wastage, and return transactions.
- **Low-Stock Alerts**: Notifications when material stock falls below reorder level.
- **Vendor Linking**: Material inward records linked to vendor profiles.

### Database
- `assets`, `asset_assignments`, `asset_condition_logs`, `materials`, `material_transactions`

### Testing
- Asset issuance and return: verify condition state transitions are valid.
- Material stock calculations: verify inward − consumption − wastage − transfer = current stock.
- Low-stock alert trigger accuracy.

---

## Phase 7: Clients, Vendors & Reports (Weeks 20–22)

**Goal**: Complete the business relationship tracking and unlock analytics.

### Deliverables
- **Clients Module**: CRUD for client companies with linked sites and contract values.
- **Vendors Module**: CRUD for suppliers with linked materials and payment history.
- **Reports Engine**: All 8 standard reports (Attendance, Payroll, Payment, Expense, Asset, Material, Site Cost, Worker Ledger).
- **Export**: PDF and CSV export for all reports.
- **Dashboard Finalization**: Wire all dashboard widgets to live data.

### Database
- `clients`, `vendors`, `vendor_payments`

### Testing
- Report accuracy: verify report outputs match raw database queries.
- Export: verify PDF and CSV contain correct data and formatting.

---

## Phase 8: AI Assistant & Notifications (Weeks 23–25)

**Goal**: Intelligence layer and real-time alerting.

### Deliverables
- **AI Expense Categorization**: Auto-suggest categories based on description patterns.
- **AI Attendance Anomaly Detection**: Flag workers with unusual patterns.
- **AI Natural Language Queries**: "How much did we spend on Site Alpha in June?"
- **AI Payroll Estimation**: Forecast next payroll based on active workers and rates.
- **Push Notifications**: Attendance reminders, payment alerts, correction request updates, low-stock alerts.
- **In-App Notification Center**: Read/unread notifications with deep-linking.

### Database
- `ai_suggestions`, `ai_feedback`, `notifications`, `notification_preferences`

### Testing
- AI suggestion accuracy against labeled test data.
- AI confidence thresholds: verify suggestions below threshold are not auto-applied.
- Push notification delivery and deep-linking.

---

## Phase 9: Polish & Hardening (Weeks 26–28)

**Goal**: Production readiness — performance, security, edge cases.

### Deliverables
- **Offline Sync Hardening**: Stress-test sync engine with large offline queues and complex conflicts.
- **Performance Optimization**: Query optimization, index tuning, lazy loading, image compression.
- **Security Audit**: Review all endpoints for auth bypass, injection, and data leakage.
- **Accessibility Audit**: Verify WCAG compliance on web dashboard.
- **Onboarding Flow**: First-time user experience — guided setup wizard.
- **Error Handling Polish**: Every error state has a user-friendly message and recovery action.

---

## Continuous Mandates (Every Sprint)

- **Code Coverage**: > 80% on business logic (salary engine, RBAC, sync engine).
- **Audit Log Integrity**: Every sprint includes a manual review of audit log completeness.
- **Offline Testing**: Every feature is tested in airplane mode on a physical device.
- **Design Review**: Every UI change is reviewed against the MusterUI design system.
