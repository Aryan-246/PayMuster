# Features & Module Specifications

## Application Structure

The PayMuster application is organized into 15 modules, each serving a distinct operational domain. Every module is accessible via the primary sidebar navigation.

| # | Module | Icon Context | Description |
|---|---|---|---|
| 1 | Dashboard | Home | High-level KPIs, quick actions, recent activity feed |
| 2 | Staff | People | Worker profiles, rates, documents, complete history |
| 3 | Attendance | Clock | GPS + photo check-in/out, supervisor verification, overtime tracking |
| 4 | Sites | Map Pin | Construction site registry, geo-fencing, worker assignment |
| 5 | Payroll | Calculator | Salary calculations, pay cycles, deductions, pay slips |
| 6 | Payments | Wallet | Payout processing (UPI/Bank/Cash), approval workflows |
| 7 | Expenses | Receipt | Petty cash, fuel, site supplies, reimbursement tracking |
| 8 | Assets | Wrench | Tool and equipment inventory, issuance, return, damage tracking |
| 9 | Materials | Package | Material procurement, delivery, site-level inventory, consumption |
| 10 | Clients | Building | Client companies, project contracts, billing relationships |
| 11 | Vendors | Truck | Material suppliers, vendor bills, payment tracking |
| 12 | Reports | Bar Chart | Custom reports, exportable dashboards, trend analytics |
| 13 | Notifications | Bell | Push alerts, approval reminders, system events |
| 14 | Settings | Gear | Organization config, integrations, user management, preferences |
| 15 | AI Assistant | Sparkle | Contextual AI copilot for queries, suggestions, and anomaly detection |

---

## 1. Dashboard

The first screen a user sees after login. Optimized for decision-making at a glance.

### Key Widgets
- **Today's Attendance Summary**: Present / Absent / Late / On Leave — real-time count with percentages.
- **Active Sites**: Count of sites with ongoing work today, with quick drill-down.
- **Pending Approvals**: Payment approvals, expense claims, correction requests awaiting action.
- **Upcoming Payroll**: Next payroll date, estimated total payout, number of workers.
- **Recent Activity Feed**: Chronological log of significant events (new staff added, payment approved, material delivered).
- **Quick Actions**: "Mark Attendance", "Add Staff", "Create Pay Run" — large, tappable cards.

### Role Visibility
- **Owner/Admin**: Full dashboard with financial summaries and org-wide metrics.
- **Supervisor**: Site-specific dashboard filtered to their assigned sites.
- **Accountant**: Financial-focused view (payroll, payments, expenses).
- **Staff**: Personal dashboard (own attendance, upcoming payments, pending requests).

---

## 2. Staff Module

The central registry of all workers, subcontractors, and field personnel.

### Worker Profile Fields

| Category | Fields |
|---|---|
| **Identity** | Full Name, Photo (mandatory), Phone Number (primary + alternate), Email (optional) |
| **Employment** | Worker Type (Daily / Monthly / Contract), Join Date, Status (Active / Inactive / Terminated) |
| **Financial** | Bank Account Number, IFSC Code, UPI ID, Preferred Payment Method |
| **Rates** | Hourly Rate, Daily Rate, Monthly Rate, Overtime Rate, Night Shift Rate, Holiday Rate, Custom Rates |
| **Rules** | Overtime Threshold (hours/day), Holiday Calendar, Sunday Rule (paid/unpaid/double), Advance Limit |
| **Documents** | Aadhaar, PAN, Bank Passbook, Photo ID, Skill Certificates — stored securely with expiry tracking |
| **Notes** | Free-text notes per worker (visible only to Admin/Owner) |

### Worker History Tabs
- **Attendance History**: Filterable log of all check-ins/check-outs with GPS and photo proof.
- **Payment History**: Every payment made to this worker with date, amount, mode, and approval status.
- **Site History**: Which sites this worker has been assigned to, and duration at each site.
- **Tool History**: All assets issued to and returned by this worker.
- **Advance History**: All salary advances given and deductions applied.

### Worker Actions
- Add / Edit / Deactivate (soft delete — never hard delete)
- Assign to Site
- Issue Advance
- View Full Ledger (all credits and debits for this worker)

---

## 3. Attendance Module

The most field-critical module. Designed for supervisors operating on job sites with gloves and unreliable connectivity.

### Check-In / Check-Out Flow
1. Supervisor opens the Attendance module on the Flutter mobile app.
2. Selects the site (auto-suggested based on GPS proximity).
3. Sees the list of workers assigned to that site.
4. For each worker: taps "Present", "Absent", "Half Day", or "Leave".
5. For present workers: the system captures GPS coordinates and a timestamped photo.
6. If offline, all data is stored locally and synced when connectivity returns.

### Attendance Record Fields
- Worker ID, Site ID, Date
- Check-In Time, Check-Out Time
- Status: Present / Absent / Half Day / Leave / Holiday / Overtime
- GPS Coordinates (check-in and check-out)
- Photo Proof (check-in and check-out)
- Marked By (Supervisor ID)
- Overtime Hours (calculated or manually entered)
- Shift Type: Regular / Night / Double
- Notes (optional free-text by Supervisor)
- Sync Status: Synced / Pending / Conflict

### Overtime & Shift Calculation
- The **Shift Start Rule** strictly applies: the calendar date on which the shift starts determines the pay multipliers (e.g., Sunday/Holiday rules) for the entire shift, even if it crosses midnight.
- System automatically flags when a worker exceeds the configured daily hour threshold (e.g., > 8 hours).
- Overtime hours are calculated and applied at the worker's configured overtime rate.
- Supervisors can manually override overtime hours with a mandatory note.

### Correction Requests
- Staff can view their own attendance records.
- Staff can submit a "Correction Request" if they believe a record is wrong.
- Correction requests are routed to the Supervisor/Admin for approval or rejection.
- All corrections are logged in the audit trail.

---

## 4. Sites Module

Construction sites are first-class entities — not just labels attached to attendance records.

### Site Profile Fields
- Site Name, Address, GPS Coordinates (center point)
- Geo-Fence Radius (meters) — used for GPS-based attendance validation
- Client (linked from Clients module)
- Start Date, Expected End Date, Status (Active / On Hold / Completed)
- Assigned Supervisor(s)
- Assigned Workers (dynamic list)
- Site Photos (progress tracking)
- Notes

### Site Operations
- Assign / Reassign workers to sites
- View site-level attendance summary (daily, weekly, monthly)
- View site-level material consumption
- View site-level asset allocation
- View site-level expense tracking
- Export site cost report (labor + materials + expenses)

---

## 5. Payroll Module

### Salary Engine

The salary engine is the mathematical core of PayMuster. It must handle every compensation model used in the construction industry.

| Rate Type | Description | Example |
|---|---|---|
| **Hourly** | Pay per hour worked | ₹150/hr |
| **Daily** | Pay per day marked present | ₹1,200/day |
| **Monthly** | Fixed monthly salary | ₹25,000/month |
| **Overtime** | Multiplied rate for hours beyond threshold | 1.5x hourly rate |
| **Night Shift** | Premium for night work (e.g., 7PM–7AM) | 1.25x daily rate |
| **Double Shift** | Premium for working two consecutive shifts | 2x daily rate |
| **Sunday** | Override for Sunday work (paid, unpaid, or multiplied) | 2x daily rate or ₹0 |
| **Holiday** | Override for gazetted/custom holidays | 2x daily rate |
| **Custom Rate** | Any worker-specific rate not covered above | Defined per worker |

### Pay Cycle Configuration
- Configurable cycles: Weekly, Bi-Weekly, Monthly, Custom Date Range
- Pay period start and end dates
- Deductions: Advances taken, penalties, deductions for damaged tools
- Additions: Bonuses, allowances, reimbursements

### Pay Run Workflow
1. **Generate**: System auto-calculates gross pay based on attendance records and salary rules. Monthly salaries are prorated by `(Monthly Salary / Actual Days in Month) * Days Present`.
2. **Review**: Accountant/Admin reviews the pay run. Line items are editable with mandatory reason notes.
3. **Arrears Application**: Any attendance corrections approved for locked past cycles are automatically applied here as Arrears.
4. **Approve**: Owner/Admin approves the final pay run.
5. **Process**: Payments are initiated (UPI/Bank/Cash) per worker's preferred method.
6. **Record**: Each payment is logged immutably with a timestamp and approver.

### Full & Final Settlement (FnF)
- Deactivating a worker triggers an optional "Full & Final Settlement" workflow.
- This creates an immediate, isolated pay cycle to clear all pending attendance and advance deductions for compliance.

---

## 6. Payments Module

### Payment Modes
- **UPI**: Direct transfer to worker's UPI ID.
- **Bank Transfer**: NEFT/IMPS to worker's bank account.
- **Cash**: Manual cash payment with photo proof of handover (optional).

### Payment Rules (Strictly Enforced)
1. Workers can **view** their own payments.
2. Workers can **request corrections** (e.g., "I was paid ₹200 less for last week").
3. Workers **cannot delete** any payment record.
4. Workers **cannot modify** approved payments.
5. Workers **cannot approve** payments.
6. Before submitting any payment: **show a confirmation dialog** with full breakdown.
7. Every edit to a payment record goes to the **Audit Log** with the editor's identity and timestamp.
8. **Failed Payments**: If a bank/UPI transfer fails, the payment status becomes `Failed`. The unpaid amount is automatically credited back to the worker's ledger as a pending payable. You cannot edit a failed payment; you must retry via a new payment record.

### Advance Management
- Workers can request salary advances (up to their configured limit).
- Advances are approved by Admin/Owner.
- Approved advances are automatically deducted from the next payroll cycle, capped at the `max_advance_deduction_percent` (e.g., max 50% of gross pay) so workers are not left with zero take-home pay.
- Advance balance is always visible on the worker's profile.

---

## 7. Expenses Module

Tracks all non-payroll spending — petty cash, fuel, site supplies, equipment rentals.

### Expense Record Fields
- Amount, Category (Fuel, Tools, Food, Transport, Rental, Miscellaneous)
- Date, Site (optional), Paid By (which user), Payment Method
- Receipt Photo (mandatory for amounts above a configurable threshold)
- Status: Draft / Submitted / Approved / Rejected / Reimbursed
- Notes

### Approval Workflow
- Submitted by any authorized user.
- Routed to Admin/Owner for approval.
- Approved expenses can be marked as "Reimbursed" with a linked payment record.

---

## 8. Assets Module

Tracks tools, equipment, vehicles, and any company-owned physical assets.

### Asset Record Fields
- Asset Name, Category (Power Tool, Hand Tool, Vehicle, Safety Equipment, Heavy Machinery)
- Serial Number / Asset Tag, Purchase Date, Purchase Cost
- Current Condition: New / Good / Fair / Damaged / Lost / Retired
- Current Location: Warehouse / Site (linked) / Issued to Worker (linked)
- Photo

### Asset Operations
- **Issue**: Assign an asset to a worker with date, condition notes, and acknowledgment.
- **Return**: Worker returns the asset; condition is inspected and logged.
- **Transfer**: Move an asset between sites.
- **Report Damage/Loss**: Log damage or loss with photo evidence and responsible worker. Sets status to `Pending Review`. Admins must review and can optionally trigger a deduction from the worker's next payroll.
- **Retire**: Mark an asset as decommissioned.

---

## 9. Materials Module

Tracks raw materials, consumables, and supplies at the site level.

### Material Record Fields
- Material Name, Category (Cement, Steel, Sand, Bricks, Paint, Electrical, Plumbing, Misc)
- Unit of Measurement (Bags, Kg, Tons, Pieces, Meters, Liters)
- Current Stock (per site)
- Reorder Level (threshold for low-stock alert)

### Material Transactions
- **Inward**: Material received at site — quantity, date, vendor (linked), delivery photo, receipt.
- **Consumption**: Material used — quantity, date, purpose note.
- **Transfer**: Material moved between sites.
- **Wastage**: Material lost/damaged — quantity, reason.
- **Return**: Material returned to vendor.

---

## 10. Clients Module

Tracks the businesses or individuals who contract PayMuster's users for work.

### Client Record Fields
- Company Name, Contact Person, Phone, Email
- GSTIN (optional), Billing Address
- Linked Sites
- Contract Value, Payment Terms
- Notes

---

## 11. Vendors Module

Tracks material suppliers and service providers.

### Vendor Record Fields
- Company Name, Contact Person, Phone, Email
- GSTIN, Bank Details
- Materials Supplied (linked categories)
- Linked Purchase Orders / Material Inward Records
- Payment History
- Notes

---

## 12. Reports Module

### Standard Reports
- **Attendance Report**: Daily / Weekly / Monthly attendance by worker, site, or organization.
- **Payroll Report**: Gross pay, deductions, net pay per worker per cycle.
- **Payment Report**: All payments with status, mode, date, and approver.
- **Expense Report**: Category-wise and site-wise expense breakdown.
- **Asset Report**: Current allocation, damage log, and utilization rates.
- **Material Report**: Stock levels, consumption rates, and wastage percentages.
- **Site Cost Report**: Total cost per site (labor + materials + expenses).
- **Worker Ledger**: Complete financial history of a single worker.

### Export Formats
- PDF (formatted for printing)
- CSV (for spreadsheet analysis)
- On-screen filterable tables with date range selectors

---

## 13. Notifications Module

### Push Notification Triggers
- Attendance not marked by configured cutoff time.
- Payment approved or rejected.
- Correction request submitted or resolved.
- Material stock below reorder level.
- Asset overdue for return.
- Payroll cycle approaching — reminder to review.

### In-App Notification Center
- Chronological list of all notifications with read/unread status.
- Deep-link to the relevant record (e.g., tapping a payment notification opens that payment).

---

## 14. Settings Module

### Organization Settings
- Organization Name, Logo, Address, GSTIN
- Default Currency (INR), Date Format, Financial Year Start
- Configurable thresholds (overtime hours, advance limits, expense receipt threshold)

### User Management
- Invite users via phone/email.
- Assign roles (Owner, Admin, Supervisor, Accountant, Staff, Viewer).
- Deactivate users (never hard delete).

### Integrations (Future)
- Tally Export
- WhatsApp Notifications
- Google Sheets Sync

---

## 15. AI Assistant Module

### What AI Does
- **Smart Categorization**: Auto-suggests expense categories based on description and historical patterns.
- **Attendance Anomaly Detection**: Flags unusual patterns (e.g., "Worker X has been absent every Monday for 4 weeks").
- **Payroll Estimation**: "If all currently active workers work a full month, estimated payroll is ₹X."
- **Natural Language Reports**: "Show me total expenses for Site Alpha last month."
- **Photo-Based Material ID**: Identifies material type from a photo and suggests quantity estimation.

### What AI Does NOT Do
- AI never **approves** or **rejects** anything.
- AI never **modifies** attendance, payment, or financial records.
- AI never **deletes** data.
- AI always shows a **confidence percentage** with every suggestion.
- AI always requires **explicit human confirmation** before any data is written.
