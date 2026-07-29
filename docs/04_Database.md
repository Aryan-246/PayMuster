# Database & Data Architecture

## Overview

PayMuster operates across two data layers: a **cloud-hosted PostgreSQL database** (Supabase) for the authoritative source of truth, and a **local SQLite database** (via Drift in Flutter) on every mobile device for offline-first operation. A deterministic sync engine bridges the two.

## 1. Cloud Database — PostgreSQL (Supabase)

### Why Supabase
- **Managed PostgreSQL**: Production-grade Postgres with automated backups, point-in-time recovery, and connection pooling (PgBouncer) — without managing infrastructure.
- **Row-Level Security (RLS)**: Multi-tenant data isolation enforced at the database level. Every query is automatically scoped to the authenticated user's organization.
- **Realtime**: Built-in WebSocket subscriptions for live data updates (attendance changes, payment approvals).
- **Storage**: Integrated object storage for photos, documents, and receipts with fine-grained access policies.
- **Auth**: Native JWT-based auth that integrates directly with RLS policies.

### Multi-Tenancy Strategy
- Every table includes an `org_id` column referencing `organizations.id`.
- RLS policies enforce that users can only read/write rows where `org_id` matches their JWT claim.
- Cross-tenant queries are **impossible** at the database level — not just forbidden in application code.

### Schema Design Rules
- **Primary Keys**: `UUID v4` for all tables. Never auto-incrementing integers (prevents enumeration attacks, simplifies offline ID generation).
- **Timestamps**: Every table includes `created_at TIMESTAMPTZ DEFAULT now()` and `updated_at TIMESTAMPTZ DEFAULT now()`.
- **Soft Deletes**: Tables containing business data use `deleted_at TIMESTAMPTZ NULL`. Hard deletes are prohibited for financial records.
- **Foreign Keys**: Mandatory for all relationships. `ON DELETE CASCADE` is **strictly prohibited** for any financial or user data. Use `ON DELETE RESTRICT` or `ON DELETE SET NULL`.
- **Enums**: Stored as PostgreSQL `TEXT` with `CHECK` constraints (not PG enum types, which are painful to migrate).

---

## 2. Core Schema Domains

### Identity & Access

| Table | Purpose |
|---|---|
| `organizations` | Tenant entity — name, logo, GSTIN, settings (JSON), subscription tier |
| `users` | Login accounts — email, phone, password hash, role, linked org_id |
| `sessions` | Active JWT sessions with device info, IP, and revocation support |
| `audit_logs` | Immutable append-only log of every mutation in the system |

### Staff & Sites

| Table | Purpose |
|---|---|
| `staff` | Worker profiles — identity, contact, employment type, rates, advance limit |
| `staff_documents` | Uploaded documents (Aadhaar, PAN, etc.) with type, file URL, expiry date |
| `salary_rules` | Per-worker rate configuration — rate type, amount, effective date, max_advance_deduction_percent, is_active |
| `shifts` | Shift definitions — name, start_time, end_time, grace_period_mins |
| `holidays` | Org-level holiday calendar — date, name, multiplier |
| `sites` | Job site registry — name, address, GPS, geo-fence radius, status, client_id |
| `site_assignments` | Many-to-many: which workers are assigned to which sites, with date ranges |

### Attendance

| Table | Purpose |
|---|---|
| `attendance_records` | Daily records — worker, site, date, status, check-in/out times, GPS, photo URLs, shift type, overtime hours, marked_by |
| `correction_requests` | Worker-submitted corrections — original record, requested change, reason, status (Pending/Approved/Rejected), resolved_by |

### Payroll & Payments

| Table | Purpose |
|---|---|
| `pay_cycles` | Pay period definitions — start date, end date, status (Draft/Calculated/Approved/Paid) |
| `pay_runs` | Org-level payroll batch — linked to pay_cycle, total amount, approved_by, approved_at |
| `pay_run_items` | Per-worker line items — gross pay, deductions breakdown (JSON), additions breakdown (JSON), arrears (JSON), net pay |
| `payments` | Individual payment records — worker, amount, mode (UPI/Bank/Cash), reference ID, status (Draft/Approved/Processing/Failed/Paid), approved_by |
| `payment_approvals` | Approval workflow log — payment_id, action (Submitted/Approved/Rejected/Failed), actor, timestamp, notes |
| `advances` | Salary advances — worker, amount, status (Requested/Approved/Disbursed/Deducted), linked deduction |

### Expenses

| Table | Purpose |
|---|---|
| `expenses` | Expense records — amount, category, date, site, paid_by, status, receipt URL |

### Assets & Materials

| Table | Purpose |
|---|---|
| `assets` | Asset registry — name, category, serial number, condition, current location/assignee, purchase info |
| `asset_assignments` | Issuance/return log — asset, worker, issued_at, returned_at, condition notes, photos |
| `materials` | Material catalog — name, category, unit of measurement |
| `material_stock` | Per-site stock levels — material, site, current quantity, reorder level |
| `material_transactions` | Stock movements — material, site, type (Inward/Consumption/Transfer/Wastage/Return), quantity, date, vendor, notes |

### Business Relationships

| Table | Purpose |
|---|---|
| `clients` | Client companies — name, contact, GSTIN, billing address |
| `vendors` | Material suppliers — name, contact, GSTIN, bank details |
| `vendor_payments` | Payments to vendors — vendor, amount, date, reference, linked material transactions |

### System

| Table | Purpose |
|---|---|
| `notifications` | In-app notifications — user, title, body, type, deep_link, read_at |
| `sync_queue` | Offline sync tracking — operation type, table, payload (JSON), status, conflict_resolution |

---

## 3. Local Database — SQLite (Drift)

### Purpose
Every Flutter mobile client maintains a local SQLite database that mirrors a subset of the cloud data. This enables full offline operation on construction sites.

### What is Stored Locally
- Staff assigned to the supervisor's sites.
- Sites assigned to the supervisor.
- Attendance records (last 30 days + any unsynced records).
- Pending correction requests.
- Unsynced photos (queued for upload).

### Sync Metadata Columns
Every locally-created record includes:
- `local_id`: UUID generated on the device.
- `server_id`: UUID assigned by the server after sync (NULL until synced).
- `synced_at`: Timestamp of last successful sync (NULL if never synced).
- `sync_status`: `pending` | `synced` | `conflict` | `failed`.
- `version`: Integer counter incremented on every local edit (for conflict detection).

---

## 4. Sync Engine Architecture

### Write Path (Offline → Online)
1. User creates/edits a record locally (e.g., marks attendance).
2. Record is saved to SQLite with `sync_status = 'pending'`.
3. A background sync worker periodically attempts to push pending records to the server.
4. **Two-Phase Media Sync**: If operations include photos (e.g., attendance proof, expense receipts), the mobile app uploads photos to Supabase Storage first, retrieves URLs, and injects them into the JSON payload before the data sync call.
5. On success: `sync_status = 'synced'`, `server_id` is populated.
6. On failure (network): retry with exponential backoff.
7. On conflict (server has a newer version): `sync_status = 'conflict'`.

### Conflict Resolution Strategy
- **Last-Write-Wins (LWW)** for non-financial data (staff notes, site assignments).
- **Server-Wins** for financial data (payments, pay runs). The server is the authority for money.
- **Manual Resolution** for attendance conflicts (two supervisors mark the same worker differently). The conflict generates a `notification` push alert for the Admin to resolve manually.

### Sync Endpoint
- `POST /api/v1/sync` — accepts a batch of pending operations and returns results (success, conflict, or rejection) for each.

---

## 5. Audit Log Design

The audit log is the single most important table for trust and compliance.

### Fields
- `id` (UUID), `org_id`, `user_id`, `action` (CREATE / UPDATE / DELETE / APPROVE / REJECT)
- `entity_type` (e.g., 'payment', 'attendance_record', 'staff')
- `entity_id` (UUID of the affected record)
- `changes` (JSONB — `{ "field": "amount", "old": 1200, "new": 1400 }`)
- `ip_address`, `user_agent`, `created_at`

### Rules
- The audit log table has **no UPDATE or DELETE permissions** — even for Super Admins.
- Audit log entries are write-once, read-many.
- All financial mutations (payments, payroll, advances) MUST create an audit log entry within the same database transaction.

---

## 6. Data Security

- **Encryption at Rest**: Supabase encrypts all data at rest using AES-256.
- **Encryption in Transit**: All connections use TLS 1.3.
- **PII Handling**: Bank account numbers and Aadhaar numbers are encrypted at the application level before storage using envelope encryption.
- **Backup Strategy**: Automated daily backups with 30-day retention. Point-in-time recovery enabled.
- **Data Retention**: Financial records are retained for a minimum of 7 years as per Indian tax law compliance.
