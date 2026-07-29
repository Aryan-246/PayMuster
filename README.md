# PayMuster

> The Contractor Operating System — Built for Construction. Designed for the Field.

## What is PayMuster?

PayMuster is an AI-powered contractor management platform purpose-built for **fabrication shops, construction firms, and field service operations**. It is not an attendance app — it is a complete operating system for managing staff, sites, attendance, payroll, payments, assets, materials, and real-time reporting.

Designed to feel like **Stripe meets Linear** — industrial, premium, minimal, and dark — but optimized for workers wearing gloves on a job site.

## Core Pillars

| Pillar | Description |
|---|---|
| **Staff** | Complete worker profiles with rates, documents, history, and payment records |
| **Sites** | Construction site management with geo-fencing and worker assignment |
| **Attendance** | GPS + photo proof check-in/check-out with supervisor verification |
| **Payroll** | Flexible salary engine (hourly, daily, overtime, night shift, holiday, custom) |
| **Payments** | UPI, bank transfer, and cash payouts with multi-tier approval workflows |
| **Proofs** | Timestamped, geo-tagged photo evidence for attendance, progress, and delivery |
| **Assets** | Tool and equipment tracking with issuance, return, and damage logging |
| **Materials** | Site-level material procurement, inventory, and consumption tracking |
| **Reports** | Real-time dashboards, exportable reports, and trend analytics |
| **AI** | Intelligent assistant that suggests (never decides) — categories, patterns, anomalies |

## User Roles

| Role | Access Level |
|---|---|
| **Owner** | Full system control, billing, organization settings |
| **Admin** | Manage all modules, users, and configurations |
| **Supervisor** | Site-level attendance, worker management, and approvals |
| **Accountant** | Payroll, payments, expenses, and financial reports |
| **Staff** | View own attendance, payments, and submit correction requests |
| **Viewer** | Read-only access to reports and dashboards |

## Tech Stack

| Layer | Technology |
|---|---|
| **Mobile App** | Flutter (Dart) — offline-first, field-optimized |
| **Web Dashboard** | React + TypeScript — admin-focused |
| **Backend API** | Node.js (Express/Fastify) + TypeScript |
| **Database** | PostgreSQL (Supabase) + SQLite (local offline via Drift) |
| **Auth** | JWT + Refresh Tokens + Role-based middleware |
| **AI** | LLM-assisted suggestions with confidence scoring |
| **Storage** | Supabase Storage (photos, documents) |

## Project Structure

```
PayMuster/
├── frontend/          # React web dashboard (TypeScript)
├── backend/           # Node.js REST API (TypeScript)
├── database/          # SQL migrations, seed data, schema diagrams
├── design/            # UI/UX wireframes, design tokens, component specs
├── assets/            # Static assets, branding, icons
├── docs/              # Complete architectural documentation (10 files)
├── prompts/           # AI agent prompts for development (7 files)
├── README.md
└── .gitignore
```

## Design Language

- **Theme**: Industrial · Premium · Minimal · Dark · High Contrast
- **Primary Background**: `#0B1114`
- **Card Background**: `#182126`
- **Accent Yellow**: `#F4B400`
- **Typography**: Inter or Plus Jakarta Sans
- **Touch Targets**: ≥ 48dp — usable with work gloves
- **Philosophy**: Spacing is more important than decoration. No visual clutter.

## Documentation

Refer to the `/docs` directory for the complete architectural specification. Every AI agent and developer must read and follow these documents before writing any code.

## Development Rules

1. Work feature-by-feature: Planning → Database → API → Backend → Frontend → Testing → Review.
2. Never generate the whole application in one response.
3. If architecture needs improvement — stop, explain, improve first.
4. Treat this project like software that will be maintained for 10 years.
