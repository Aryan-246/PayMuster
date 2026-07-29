# API Architecture

## Overview

PayMuster exposes a RESTful JSON API that serves both the React web dashboard and the Flutter mobile app. The API is the single gateway to all business logic and data. There is no direct database access from any client.

## Tech Stack

| Component | Technology |
|---|---|
| **Runtime** | Node.js (LTS) |
| **Validation** | Zod — runtime schema validation for all request payloads |
| **Auth** | Web: JWT (15-min) + Refresh. Mobile: 30-day device-bound session token |
| **Database Client** | Supabase JS Client or Prisma (for type-safe queries) |
| **File Uploads** | Multer → Supabase Storage |
| **Logging** | Pino (structured JSON logs) |

## Base URL & Versioning

```
https://api.paymuster.app/v1/
```

All endpoints are versioned under `/v1/`. Breaking changes require a new version (`/v2/`). Non-breaking additions (new optional fields, new endpoints) are deployed under the existing version.

---

## 1. Authentication Endpoints

| Method | Endpoint | Description | Auth |
|---|---|---|---|
| `POST` | `/auth/register` | Register organization + owner account | Public |
| `POST` | `/auth/login` | Login with email/phone + password → returns JWT | Public |
| `POST` | `/auth/refresh` | Exchange refresh token for new access token | Cookie |
| `POST` | `/auth/logout` | Revoke refresh token and invalidate session | Authenticated |
| `POST` | `/auth/forgot-password` | Send password reset OTP | Public |
| `POST` | `/auth/reset-password` | Reset password with OTP verification | Public |

---

## 2. Resource Endpoints (CRUD)

All resource endpoints follow a consistent pattern:

```
GET    /v1/{resource}          → List (paginated, filterable)
GET    /v1/{resource}/:id      → Get single record
POST   /v1/{resource}          → Create new record
PATCH  /v1/{resource}/:id      → Update fields on existing record
DELETE /v1/{resource}/:id      → Soft delete (set deleted_at)
```

### Module Endpoints

| Module | Base Path | Special Endpoints |
|---|---|---|
| **Dashboard**| `/v1/dashboard`| `GET /v1/dashboard/summary` — aggregate counts (attendance, sites, pending approvals) |
| **Staff** | `/v1/staff` | `GET /v1/staff/:id/ledger` — full financial history |
| | | `POST /v1/staff/:id/documents` — upload document |
| | | `GET /v1/staff/:id/attendance` — attendance history |
| | | `GET /v1/staff/:id/payments` — payment history |
| **Sites** | `/v1/sites` | `POST /v1/sites/:id/assign` — assign workers |
| | | `DELETE /v1/sites/:id/assign/:staffId` — unassign worker |
| | | `GET /v1/sites/:id/summary` — site cost summary |
| **Attendance** | `/v1/attendance` | `POST /v1/attendance/bulk` — mark attendance for multiple workers |
| | | `GET /v1/attendance/daily?date=&siteId=` — daily site view |
| | | `POST /v1/attendance/:id/correction` — submit correction request |
| | | `PATCH /v1/attendance/corrections/:id` — approve/reject correction |
| **Payroll** | `/v1/payroll` | `POST /v1/payroll/cycles` — create pay cycle |
| | | `POST /v1/payroll/cycles/:id/calculate` — run salary calculation |
| | | `PATCH /v1/payroll/cycles/:id/approve` — approve pay run |
| | | `GET /v1/payroll/cycles/:id/items` — list pay run items |
| | | `GET /v1/payroll/cycles/:id/slips/:staffId` — individual pay slip |
| **Payments** | `/v1/payments` | `PATCH /v1/payments/:id/approve` — approve payment |
| | | `PATCH /v1/payments/:id/reject` — reject payment |
| | | `GET /v1/payments/:id/audit` — audit trail for payment |
| **Expenses** | `/v1/expenses` | `POST /v1/expenses/:id/receipt` — upload receipt photo |
| | | `PATCH /v1/expenses/:id/approve` — approve expense |
| **Assets** | `/v1/assets` | `POST /v1/assets/:id/issue` — issue to worker |
| | | `POST /v1/assets/:id/return` — return from worker |
| | | `POST /v1/assets/:id/report-damage` — log damage |
| **Materials** | `/v1/materials` | `POST /v1/materials/transactions` — record stock movement |
| | | `GET /v1/materials/stock?siteId=` — current stock at site |
| **Clients** | `/v1/clients` | Standard CRUD |
| **Vendors** | `/v1/vendors` | `GET /v1/vendors/:id/payments` — vendor payment history |
| **Reports** | `/v1/reports` | `GET /v1/reports/attendance` — attendance report |
| | | `GET /v1/reports/payroll` — payroll report |
| | | `GET /v1/reports/expenses` — expense report |
| | | `GET /v1/reports/site-cost/:siteId` — site cost report |
| | | `GET /v1/reports/worker-ledger/:staffId` — worker ledger |
| | | `GET /v1/reports/compliance` — CSV export for PF/ESI/Labor law compliance |
| **AI** | `/v1/ai` | `POST /v1/ai/identify-material` — identifies material from uploaded photo |
| **Notifications** | `/v1/notifications` | `PATCH /v1/notifications/:id/read` — mark as read |
| | | `PATCH /v1/notifications/read-all` — mark all as read |
| **Settings** | `/v1/settings` | `GET /v1/settings/org` — get org settings |
| | | `PATCH /v1/settings/org` — update org settings |
| | | `GET /v1/settings/users` — list organization users |
| | | `POST /v1/settings/users/invite` — invite user |

---

## 3. Offline Sync Endpoint

```
POST /v1/sync
```
**Important**: The sync process is Two-Phase for records containing media. Mobile clients must first upload photos using the file upload endpoints (e.g. `/v1/attendance/photos`), retrieve the Supabase Storage URLs, and inject those URLs into the `payload` before calling `POST /v1/sync`.

### Request Body
```json
{
  "operations": [
    {
      "local_id": "uuid",
      "table": "attendance_records",
      "action": "CREATE",
      "payload": { ... },
      "version": 1,
      "timestamp": "2026-07-29T09:00:00Z"
    }
  ]
}
```

### Response Body
```json
{
  "results": [
    {
      "local_id": "uuid",
      "status": "synced",
      "server_id": "uuid"
    },
    {
      "local_id": "uuid",
      "status": "conflict",
      "conflict_details": {
        "server_version": 3,
        "client_version": 2,
        "server_data": { ... }
      }
    }
  ]
}
```

---

## 4. File Upload Endpoints

All file uploads use `multipart/form-data`.

| Endpoint | Max Size | Allowed Types | Purpose |
|---|---|---|---|
| `POST /v1/staff/:id/documents` | 5 MB | JPEG, PNG, PDF | ID documents, certificates |
| `POST /v1/attendance/photos` | 2 MB | JPEG, PNG | Attendance proof photos |
| `POST /v1/expenses/:id/receipt` | 3 MB | JPEG, PNG, PDF | Expense receipts |
| `POST /v1/assets/:id/photos` | 3 MB | JPEG, PNG | Asset condition photos |
| `POST /v1/materials/delivery-proof` | 3 MB | JPEG, PNG | Material delivery verification |

---

## 5. Pagination, Filtering & Sorting

### Pagination (Cursor-Based)
```
GET /v1/staff?cursor=<last_id>&limit=25
```
- Default `limit`: 25. Max `limit`: 100.
- Response includes `next_cursor` for fetching the next page.

### Filtering
```
GET /v1/staff?status=active&site_id=<uuid>&worker_type=daily
GET /v1/attendance?date=2026-07-29&site_id=<uuid>&status=present
```

### Sorting
```
GET /v1/staff?sort=name&order=asc
GET /v1/payments?sort=created_at&order=desc
```

---

## 6. Standard Error Response

All errors follow a consistent schema:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Request body validation failed.",
    "details": [
      {
        "field": "phone",
        "message": "Phone number must be 10 digits."
      }
    ]
  }
}
```

### Error Codes
| HTTP Status | Code | When |
|---|---|---|
| 400 | `VALIDATION_ERROR` | Request body fails Zod schema validation |
| 401 | `UNAUTHORIZED` | Missing or expired JWT |
| 403 | `FORBIDDEN` | User's role does not have permission for this action |
| 404 | `NOT_FOUND` | Resource does not exist or belongs to another org |
| 409 | `CONFLICT` | Duplicate entry (e.g., phone number already exists) |
| 422 | `BUSINESS_RULE_VIOLATION` | Valid request but violates business logic (e.g., advance exceeds limit) |
| 429 | `RATE_LIMITED` | Too many requests |
| 500 | `INTERNAL_ERROR` | Unexpected server error (logged, never leaked to client) |

---

## 7. Security & Middleware

### Request Pipeline
1. **Rate Limiter** — Redis-backed sliding window. 100 requests/minute per IP for public endpoints. 300/minute for authenticated endpoints.
2. **Auth Middleware** — Verify JWT, extract `user_id`, `org_id`, and `role` into request context.
3. **RBAC Middleware** — Check if the user's role has permission for the requested endpoint and action.
4. **Validation Middleware** — Validate request body/query/params against Zod schemas.
5. **Controller** — Execute business logic.
6. **Audit Logger** — Log the mutation to the audit trail.

### Security Headers
- `Strict-Transport-Security` — enforce HTTPS.
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `Content-Security-Policy` — restrictive CSP.
- CORS configured to allow only the web dashboard and mobile app origins.
