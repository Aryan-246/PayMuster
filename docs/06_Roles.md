# Roles & Permissions

## Overview

PayMuster enforces strict Role-Based Access Control (RBAC). Every API request is checked against the user's role before any business logic executes. There are no implicit permissions — if a role is not explicitly granted access, it is denied.

## The 6 Roles

| Role | Description | Typical User |
| --- | --- | --- |
| **Owner** | Full system control. Can manage billing, delete the organization, and override any action. | Business owner, contractor proprietor |
| **Admin** | Full operational control. Can manage all modules, users, and configurations. Cannot manage billing or delete the organization. | Office manager, operations head |
| **Supervisor** | Site-level operational access. Can mark attendance, manage workers at assigned sites, and submit expenses. | Site foreman, floor manager, team lead |
| **Accountant** | Financial access. Can process payroll, approve payments, manage expenses, and generate financial reports. | In-house accountant, external bookkeeper |
| **Staff** | Self-service access. Can view own attendance and payments, submit correction requests, and update personal details. | Daily laborer, welder, electrician, helper |
| **Viewer** | Read-only access. Can view dashboards and reports but cannot create, edit, or approve anything. | Investor, auditor, silent partner |

---

## Permission Matrix

**Legend**: ✅ Full Access | 👁️ View Only | 🔒 Own Data Only | ⛔ No Access | ⚡ Scoped (site-level only)

| Module / Action | Owner | Admin | Supervisor | Accountant | Staff | Viewer |
| --- | --- | --- | --- | --- | --- | --- |
| **Dashboard** | ✅ | ✅ | ⚡ | ✅ (financial) | 🔒 | 👁️ |
| **Staff — View All** | ✅ | ✅ | ⚡ | 👁️ | ⛔ | 👁️ |
| **Staff — Create/Edit** | ✅ | ✅ | ⛔ | ⛔ | ⛔ | ⛔ |
| **Staff — Deactivate** | ✅ | ✅ | ⛔ | ⛔ | ⛔ | ⛔ |
| **Staff — View Own Profile** | ✅ | ✅ | ✅ | ✅ | 🔒 | ⛔ |
| **Sites — CRUD** | ✅ | ✅ | ⛔ | ⛔ | ⛔ | ⛔ |
| **Sites — View** | ✅ | ✅ | ⚡ | 👁️ | ⛔ | 👁️ |
| **Sites — Assign Workers** | ✅ | ✅ | ⛔ | ⛔ | ⛔ | ⛔ |
| **Attendance — Mark** | ✅ | ✅ | ⚡ | ⛔ | ⛔ | ⛔ |
| **Attendance — View All** | ✅ | ✅ | ⚡ | 👁️ | ⛔ | 👁️ |
| **Attendance — View Own** | ✅ | ✅ | ✅ | ✅ | 🔒 | ⛔ |
| **Attendance — Submit Correction** | ⛔ | ⛔ | ⛔ | ⛔ | 🔒 | ⛔ |
| **Attendance — Approve Correction** | ✅ | ✅ | ⚡ | ⛔ | ⛔ | ⛔ |
| **Payroll — Configure Rates** | ✅ | ✅ | ⛔ | ⛔ | ⛔ | ⛔ |
| **Payroll — Run Calculation** | ✅ | ✅ | ⛔ | ✅ | ⛔ | ⛔ |
| **Payroll — Approve** | ✅ | ✅ | ⛔ | ⛔ | ⛔ | ⛔ |
| **Payroll — View Pay Slips** | ✅ | ✅ | ⛔ | ✅ | 🔒 | 👁️ |
| **Payments — Create** | ✅ | ✅ | ⛔ | ✅ | ⛔ | ⛔ |
| **Payments — Approve** | ✅ | ✅ | ⛔ | ⛔ | ⛔ | ⛔ |
| **Payments — View All** | ✅ | ✅ | ⛔ | ✅ | ⛔ | 👁️ |
| **Payments — View Own** | ✅ | ✅ | ✅ | ✅ | 🔒 | ⛔ |
| **Payments — Delete** | ⛔ | ⛔ | ⛔ | ⛔ | ⛔ | ⛔ |
| **Payments — Edit Approved** | ⛔ | ⛔ | ⛔ | ⛔ | ⛔ | ⛔ |
| **Payments — Request Correction** | ⛔ | ⛔ | ⛔ | ⛔ | 🔒 | ⛔ |
| **Expenses — Submit** | ✅ | ✅ | ✅ | ✅ | ⛔ | ⛔ |
| **Expenses — Approve** | ✅ | ✅ | ⛔ | ⛔ | ⛔ | ⛔ |
| **Expenses — View All** | ✅ | ✅ | ⚡ | ✅ | ⛔ | 👁️ |
| **Assets — CRUD** | ✅ | ✅ | ⛔ | ⛔ | ⛔ | ⛔ |
| **Assets — Issue/Return** | ✅ | ✅ | ⚡ | ⛔ | ⛔ | ⛔ |
| **Assets — View** | ✅ | ✅ | ⚡ | 👁️ | ⛔ | 👁️ |
| **Materials — CRUD** | ✅ | ✅ | ⛔ | ⛔ | ⛔ | ⛔ |
| **Materials — Record Transactions** | ✅ | ✅ | ⚡ | ⛔ | ⛔ | ⛔ |
| **Materials — View Stock** | ✅ | ✅ | ⚡ | 👁️ | ⛔ | 👁️ |
| **Clients — CRUD** | ✅ | ✅ | ⛔ | ⛔ | ⛔ | ⛔ |
| **Vendors — CRUD** | ✅ | ✅ | ⛔ | ✅ | ⛔ | ⛔ |
| **Reports — View** | ✅ | ✅ | ⚡ | ✅ | ⛔ | 👁️ |
| **Reports — Export** | ✅ | ✅ | ⛔ | ✅ | ⛔ | 👁️ |
| **Audit Logs — Read** | ✅ | ✅ | ⛔ | ⛔ | ⛔ | ⛔ |
| **Settings — Organization** | ✅ | ✅ | ⛔ | ⛔ | ⛔ | ⛔ |
| **Settings — User Management** | ✅ | ✅ | ⛔ | ⛔ | ⛔ | ⛔ |
| **Settings — Billing** | ✅ | ⛔ | ⛔ | ⛔ | ⛔ | ⛔ |
| **AI Assistant** | ✅ | ✅ | ✅ | ✅ | 🔒 | 👁️ |
| **Notifications** | ✅ | ✅ | ✅ | ✅ | 🔒 | 🔒 |

---

## Scoped Access (⚡) Rules

The **Supervisor** role has scoped access — they can only operate on data related to **sites they are explicitly assigned to**.

- A Supervisor assigned to "Site Alpha" can mark attendance for workers at Site Alpha, but cannot see workers assigned to "Site Beta".
- Scoping is enforced at the API level by filtering queries: `WHERE site_id IN (SELECT site_id FROM site_assignments WHERE user_id = :supervisor_id)`.

---

## Payment-Specific Security Rules

These rules are **absolute and non-overridable**, even by the Owner role:

1. **No payment record can ever be hard-deleted**. Soft delete sets `deleted_at` and creates an audit log entry.
2. **No approved payment can be modified**. Once a payment status is `approved`, the record is locked. Any correction requires creating a new adjustment record.
3. **Every payment submission shows a confirmation dialog** on the client side with a full breakdown (worker name, amount, mode, period). The user must explicitly confirm.
4. **Every edit to any payment field creates an audit log entry** containing the old value, new value, editor identity, and timestamp.
5. **Staff can only view their own payment history** and submit correction requests. They cannot see other workers' payments.

---

## Authentication Flow

### Login

1. User submits email + password or a verified Google identity token.
2. Server verifies the identity and current account state against the `users` table.
3. Server creates one persisted `sessions` row and embeds that row's UUID in both the short-lived access JWT and the refresh JWT.
4. Client stores tokens securely. Current API responses return tokens in JSON; clients must use platform-appropriate protected storage.

### Token Refresh & Revocation

1. Every protected request validates the access JWT and its exact persisted session row. A revoked, expired, missing, user-mismatched, or organization-mismatched session is rejected immediately.
2. `/auth/refresh` validates the exact session UUID and refresh-token hash, then issues a new short-lived access JWT bound to the same session. Refresh-token rotation is not currently implemented.
3. Session revocation therefore invalidates both refresh and otherwise-unexpired access tokens on their next server request.
4. Role and organization authorization are loaded from the current user and session records, not trusted from stale token claims.

### Session-UUID Rollout

Access and refresh tokens issued before session UUID binding do not contain the required `sessionId` claim. They are intentionally rejected after this deployment, causing a one-time sign-in requirement for existing clients. No database reset or migration is required.

### Logout

1. Client calls `/auth/logout`; this endpoint remains available during maintenance mode.
2. Server revokes the matching refresh-token session in the `sessions` table.
3. Client discards both tokens from protected storage.

---

## Audit Trail Requirements

Every permission-related event is logged:

| Event | Logged Data |
| --- | --- |
| User login | user_id, IP, device, timestamp |
| Failed login attempt | email/phone attempted, IP, timestamp |
| Role change | user_id, old_role, new_role, changed_by, timestamp |
| User invited | inviter_id, invitee_email, assigned_role, timestamp |
| User deactivated | user_id, deactivated_by, reason, timestamp |
| Unauthorized access attempt | user_id, endpoint, role, timestamp |
