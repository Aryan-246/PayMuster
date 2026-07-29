# Project Vision: PayMuster

## What We Are Building

PayMuster is an **AI-powered Contractor Operating System** — a production SaaS platform purpose-built for the construction, fabrication, and field services industry. It centralizes every operational concern a contractor business faces: managing workers, tracking attendance across job sites, calculating complex pay structures, processing payments, tracking assets and materials, and generating actionable reports.

This is not an attendance app with a payroll bolt-on. This is a unified operating system where every module — Staff, Sites, Attendance, Payroll, Payments, Expenses, Assets, Materials, Reports — is a first-class citizen, deeply interconnected, and designed to work offline in environments where connectivity is unreliable.

## The Problem Space

### 1. Pen-and-Paper Hell
Small and medium construction businesses track attendance in registers, calculate wages on paper, and pay workers in cash with no audit trail. This leads to disputes, wage theft claims, and zero financial visibility.

### 2. Software Built for Offices, Not Job Sites
Existing HR and payroll tools (Zoho, Keka, GreytHR) are designed for office employees with stable internet. They break down when a supervisor needs to mark attendance for 40 workers on a remote site with no signal.

### 3. Complex Pay Structures
Construction pay is not a fixed monthly salary. Workers have hourly rates, daily rates, overtime multipliers, night shift premiums, holiday rules, Sunday overrides, double-shift bonuses, and advance deductions — often varying per worker. No generic payroll tool handles this correctly.

### 4. No Material or Asset Accountability
Tools go missing. Materials are over-ordered. Deliveries are unverified. Without a system that tracks what went where, to which site, issued to which worker — businesses hemorrhage money silently.

### 5. Trust Deficit
Workers distrust employers on payment accuracy. Employers distrust workers on attendance honesty. The only solution is a transparent, auditable, proof-backed system that both sides can trust.

## The PayMuster Solution

### The 10 Core Pillars

| # | Pillar | Purpose |
|---|---|---|
| 1 | **Staff** | Complete worker lifecycle — profile, rates, documents, history |
| 2 | **Sites** | Job site management with geo-fencing, worker assignment, and progress tracking |
| 3 | **Attendance** | GPS + timestamped photo check-in/out with supervisor verification |
| 4 | **Payroll** | Flexible salary engine handling every rate combination in the construction industry |
| 5 | **Payments** | UPI, bank, cash payouts with multi-tier approvals and immutable audit trails |
| 6 | **Proofs** | Geo-tagged, timestamped photo evidence for attendance, delivery, and site progress |
| 7 | **Assets** | Tool and equipment tracking — issuance, return, damage, and loss logging |
| 8 | **Materials** | Site-level procurement, inventory, consumption, and wastage tracking |
| 9 | **Reports** | Real-time dashboards, trend analytics, exportable financial reports |
| 10 | **AI** | Intelligent assistant that suggests, never decides — learns patterns, flags anomalies |

### Design Inspirations
We draw UI/UX inspiration from the world's best software:
- **Stripe** — for dashboard clarity and data density
- **Linear** — for speed, keyboard shortcuts, and minimal UI
- **Notion** — for flexible views and clean information architecture
- **Arc Browser** — for bold, dark interfaces with personality
- **Raycast** — for command-palette interaction patterns
- **Framer** — for smooth micro-animations
- **Apple** — for hardware-level attention to spacing, typography, and touch

We do **NOT** copy any existing contractor or agri-tech product. PayMuster's design identity is original: **Industrial · Premium · Minimal · Dark · High Contrast**.

## Target Users

| Role | Who They Are | How They Use PayMuster |
|---|---|---|
| **Owner** | Business owner, contractor, fabrication shop proprietor | Full control — views reports, manages billing, oversees everything |
| **Admin** | Office manager, operations head | Manages staff records, sites, payroll configuration, integrations |
| **Supervisor** | Site foreman, floor manager, team lead | Marks attendance on-site, verifies work, manages assigned workers |
| **Accountant** | In-house or external accountant/bookkeeper | Processes payroll, approves payments, manages expenses, generates reports |
| **Staff** | Daily laborer, welder, electrician, helper, driver | Views own attendance and payments, submits correction requests |
| **Viewer** | Investor, auditor, silent partner | Read-only access to dashboards and reports |

## Non-Negotiable Principles

1. **Offline-First**: The app must work without internet on construction sites. Data syncs when connectivity returns, with deterministic conflict resolution.
2. **Proof-Backed Trust**: Attendance requires GPS coordinates and timestamped photos. No system should rely on self-reported data alone.
3. **AI Suggests, Never Decides**: AI can recommend an expense category or flag an attendance anomaly. It must never automatically change business data without human confirmation.
4. **Glove-Friendly UX**: Touch targets ≥ 48dp. Minimal text input. Workers wearing PPE must be able to operate the app.
5. **10-Year Maintainability**: Every architectural decision must justify itself against a decade of maintenance. No shortcuts.
6. **Immutable Audit Trail**: Every financial action — payment, correction, deletion — is permanently logged with who, what, when, and why.
7. **Offline-First Security**: Mobile devices use 30-day device-bound persistent sessions. Workers are never locked out of the app while offline in a dead zone, but sessions can be revoked on the next sync.
