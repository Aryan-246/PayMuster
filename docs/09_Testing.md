# Testing Strategy

## Overview

PayMuster is a financial application where incorrect calculations result in workers being underpaid or overpaid. Testing is not optional — it is a primary engineering discipline. Every feature is shipped with tests, and untested code does not merge.

## Testing Pyramid

```
        ┌─────────┐
        │   E2E   │   ← Few, expensive, critical paths only
       ┌┴─────────┴┐
       │Integration │  ← API + DB, offline sync, approval workflows
      ┌┴───────────┴┐
      │  Unit Tests  │ ← Salary engine, RBAC, validation, utilities
     └──────────────┘
```

---

## 1. Unit Tests

### Scope
Individual pure functions, utility methods, validation schemas, and calculation engines.

### Tools
| Platform | Tool |
|---|---|
| **Backend (Node.js)** | Jest or Vitest |
| **Frontend (React)** | Jest + React Testing Library |
| **Mobile (Flutter)** | `flutter_test` (built-in) |

### Coverage Targets
| Module | Target | Rationale |
|---|---|---|
| **Salary Engine** | > 95% | Financial calculations must be mathematically verifiable |
| **RBAC / Permission Logic** | > 95% | Security logic must be exhaustively tested |
| **Zod Validation Schemas** | > 90% | Every API input must be validated |
| **Date/Time Utilities** | > 90% | Timezone and calendar math is notoriously error-prone |
| **Sync Conflict Resolution** | > 90% | Data integrity depends on correct merge logic |
| **All other business logic** | > 80% | General coverage baseline |

### Salary Engine Test Cases (Examples)
These are the kind of property-based tests the salary engine must pass:

| Scenario | Expected Behavior |
|---|---|
| Daily worker, 22 days present, no overtime | Gross = daily_rate × 22 |
| Hourly worker, 8 hrs/day, 20 days, 10 hrs overtime | Gross = (hourly_rate × 8 × 20) + (overtime_rate × 10) |
| Daily worker, worked on Sunday (2x rule) | Sunday pay = daily_rate × 2 |
| Daily worker, worked on gazetted holiday (2x rule) | Holiday pay = daily_rate × 2 |
| Night shift worker, 15 nights, 1.25x multiplier | Gross = daily_rate × 1.25 × 15 |
| Double shift worker, 5 double days | Gross = daily_rate × 2 × 5 |
| Worker with ₹5,000 advance pending | Net = Gross − ₹5,000 |
| Worker added mid-cycle (joined on day 15 of 30-day cycle) | Pro-rated: only 15 days calculated |
| Worker with rate change mid-cycle (rate increased on day 10) | Days 1–9 at old rate, days 10–30 at new rate |
| Zero attendance days | Gross = ₹0, no payment record generated |
| All rate types combined on a single day (holiday + night + overtime) | Rates are applied in the correct precedence order defined by business rules |

---

## 2. Integration Tests

### Scope
API endpoints tested against a real database (not mocks). Verifies that the full request pipeline works: validation → auth → RBAC → business logic → database → response.

### Tools
| Platform | Tool |
|---|---|
| **Backend** | Supertest + Testcontainers (ephemeral Postgres) |
| **Mobile** | `integration_test` package (Flutter) |

### Key Integration Test Scenarios

| Module | Test Case |
|---|---|
| **Auth** | Register → Login → Receive JWT → Access protected endpoint → Refresh token → Logout → Verify token is revoked |
| **RBAC** | Staff role attempts to approve a payment → Verify 403 response + audit log entry |
| **RBAC** | Supervisor accesses a site they're not assigned to → Verify 403 response |
| **Staff CRUD** | Create staff → Verify in DB → Update phone → Verify updated → Deactivate → Verify soft deleted |
| **Attendance** | Mark attendance for 5 workers → Verify records created → Verify overtime auto-calculated |
| **Payroll** | Create pay cycle → Calculate → Verify line items match manual calculation → Approve → Verify status locked |
| **Payment Workflow** | Create payment → Submit for approval → Approve → Verify audit log has 3 entries (create, submit, approve) |
| **Payment Rules** | Staff role attempts to delete a payment → Verify 403 |
| **Payment Rules** | Any role attempts to edit an approved payment → Verify 403 |
| **Advance** | Approve advance of ₹5,000 → Run payroll → Verify deduction appears in pay run item |
| **Sync** | Submit offline-created attendance records → Verify sync endpoint creates records correctly |
| **Sync Conflict** | Submit attendance with version 1 when server has version 2 → Verify conflict response |

---

## 3. End-to-End (E2E) Tests

### Scope
Full user journeys across the entire application stack (UI → API → DB). These test the critical paths that, if broken, would make the product unusable.

### Tools
| Platform | Tool |
|---|---|
| **Web** | Playwright |
| **Mobile** | Flutter `integration_test` on a physical device or emulator |

### Critical E2E Flows

| Flow | Steps |
|---|---|
| **Onboarding** | Register → Create org → Set up first site → Add first worker → Mark first attendance |
| **Payroll Cycle** | Mark attendance for a week → Create pay cycle → Calculate → Review → Approve → Verify pay slips |
| **Expense Claim** | Submit expense with receipt photo → Admin approves → Verify reimbursement record |
| **Offline Attendance** | Enable airplane mode → Mark attendance → Disable airplane mode → Verify sync completes |
| **Correction Request** | Staff views attendance → Submits correction → Supervisor approves → Verify record updated |

---

## 4. Offline & Sync Testing

This is a **dedicated test category** because offline-first is a core architectural feature.

### Test Scenarios

| Scenario | Verification |
|---|---|
| Create staff record while offline | Record saved locally → Sync when online → Verify server record matches |
| Mark attendance while offline for 3 consecutive days | All 3 days queued locally → Sync uploads all 3 → Verify server has all records |
| Edit a locally-created record before syncing | Latest version is synced → Only one server record exists |
| Two supervisors mark attendance for the same worker on the same day while offline | Conflict detected during sync → Both records flagged → Admin sees conflict resolution UI |
| Photo taken offline for attendance proof | Photo saved locally → Uploaded to Supabase Storage on sync → URL updated in attendance record |
| Network drops mid-sync | Partial sync is safe → Re-sync picks up where it left off → No duplicate records |

---

## 5. Security Testing

| Test Type | What We Check |
|---|---|
| **Auth Bypass** | Access any endpoint without a JWT → Verify 401 |
| **Cross-Tenant** | User from Org A tries to access Org B's data → Verify 404 (not 403 — don't reveal existence) |
| **Injection** | SQL injection in query params and body fields → Verify parameterized queries prevent execution |
| **Rate Limiting** | Send 200 requests in 60 seconds → Verify 429 after threshold |
| **File Upload** | Upload a `.exe` file to the receipt endpoint → Verify rejection |
| **JWT Tampering** | Modify the `role` claim in a JWT → Verify server rejects the tampered token |

---

## 6. CI/CD Test Execution

### Pipeline Stages

```
PR Opened → Lint → Unit Tests → Integration Tests → Build → Deploy to Staging → E2E Tests
```

| Stage | Blocking? | When |
|---|---|---|
| Lint (ESLint, Dart Analyzer) | ✅ Yes | Every PR |
| Unit Tests | ✅ Yes | Every PR |
| Integration Tests | ✅ Yes | Every PR |
| E2E Tests | ✅ Yes | Before merge to main |
| Offline Sync Tests | ✅ Yes | Before merge to main (Flutter) |
| Security Tests | ✅ Yes | Weekly scheduled run + before release |

### Fail Conditions
- Any test failure blocks merge.
- Coverage drops below thresholds → merge blocked.
- New endpoints without corresponding integration tests → merge blocked (enforced via code review checklist).
