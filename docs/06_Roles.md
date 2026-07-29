# Roles & Permissions

## Overview

PayMuster enforces strict Role-Based Access Control (RBAC). Every API request is checked against the user's role before any business logic executes. There are no implicit permissions — if a role is not explicitly granted access, it is denied.

## The 6 Roles

| Role | Description | Typical User |
|---|---|---|
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
|---|---|---|---|---|---|---|
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
1. User submits email/phone + password.
2. Server verifies credentials against the `users` table.
3. Server generates Auth tokens based on client type:
   - **Web**: JWT (15-minute expiry) + Refresh Token (7-day HTTP-only cookie).
   - **Mobile**: Persistent 30-day device-bound session token.
4. Client stores tokens securely.

### Token Refresh & Revocation
1. **Web**: When JWT expires, client sends the refresh token cookie to `/auth/refresh`. Server validates, issues new JWT, rotates refresh token.
2. **Mobile**: Uses the 30-day token. If the server revokes the session, the mobile app will be forced to log out on the next sync attempt.

### Logout
1. Client calls `/auth/logout`.
2. Server revokes the refresh token in the `sessions` table.
3. Client discards the JWT from memory.

---

## Audit Trail Requirements

Every permission-related event is logged:

| Event | Logged Data |
|---|---|
| User login | user_id, IP, device, timestamp |
| Failed login attempt | email/phone attempted, IP, timestamp |
| Role change | user_id, old_role, new_role, changed_by, timestamp |
| User invited | inviter_id, invitee_email, assigned_role, timestamp |
| User deactivated | user_id, deactivated_by, reason, timestamp |
| Unauthorized access attempt | user_id, endpoint, role, timestamp |
