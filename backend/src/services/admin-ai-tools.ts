import { prisma } from '../lib/prisma.js';
import { AppError } from '../lib/app-error.js';
import { providerHealth } from '../providers/registry.js';

/**
 * Admin AI Tool Registry — the ONLY capabilities the AI assistant has.
 *
 * Every tool is a hand-written, bounded query or a whitelisted admin-service
 * operation. The model can request tools by name with simple arguments; it can
 * never construct SQL, arbitrary commands, or reach any capability that is not
 * declared here. Read tools execute immediately and return real rows/counts.
 * Action tools are DESTRUCTIVE: they never execute on request — the registry
 * only RESOLVES the target from the database so the service layer can present
 * an explicit confirmation (target + consequence + single-use token) to the
 * admin. Execution happens exclusively through the existing authorized
 * services after the admin confirms (see ai.service.ts).
 */

/** Injectable database surface (defaults to the real Prisma client). */
type AiToolsDb = {
    user: any;
    organization: any;
    site: any;
    subscription: any;
    plan: any;
    ownerRequest: any;
    review: any;
    paymentEvent: any;
    announcementCampaign: any;
    notification: any;
    mailDispatch: any;
    usageRecord: any;
    auditLog: any;
    attendanceRecord: any;
    payRun: any;
};

export interface AiToolDeclaration {
    name: string;
    description: string;
    parameters: {
        type: 'OBJECT';
        properties: Record<string, { type: 'STRING' | 'INTEGER' | 'BOOLEAN'; description: string; enum?: string[] }>;
        required?: string[];
    };
}

export interface AiEntity {
    type: 'org' | 'user' | 'site' | 'subscription' | 'review' | 'announcement';
    id: string;
    publicId?: string | null;
    name?: string | null;
    subtitle?: string | null;
    route: string;
}

export interface AiToolResult {
    tool: string;
    summary: string;
    data: unknown;
    entities: AiEntity[];
}

export type AiActionOperation =
    | 'GRANT_UNLIMITED'
    | 'REVOKE_UNLIMITED'
    | 'SUSPEND_USER'
    | 'BLOCK_USER'
    | 'UNSUSPEND_USER'
    | 'UNBLOCK_USER';

export interface AiActionResolution {
    operation: AiActionOperation;
    target: {
        type: 'org' | 'user';
        id: string;
        publicId?: string | null;
        name?: string | null;
        subtitle?: string | null;
    };
    currentState: Record<string, unknown>;
    consequences: string;
    entity?: AiEntity;
}

const MAX_LIST_LIMIT = 20;

function clampLimit(value: unknown, fallback = 10): number {
    const n = typeof value === 'number' && Number.isFinite(value) ? Math.floor(value) : fallback;
    return Math.max(1, Math.min(MAX_LIST_LIMIT, n));
}

function str(value: unknown): string | undefined {
    return typeof value === 'string' && value.trim().length > 0 ? value.trim() : undefined;
}

// ---------------------------------------------------------------------------
// Tool declarations — the model-visible capability surface.
// ---------------------------------------------------------------------------

export const AI_TOOL_DECLARATIONS: AiToolDeclaration[] = [
    {
        name: 'platform_stats',
        description:
            'Platform-wide counters: users, organizations, sites, attendance records, payroll runs, ' +
            'pending owner requests, blocked/disabled users, subscriptions, pending reviews. ' +
            'Use for questions like "how many users are on the platform".',
        parameters: { type: 'OBJECT', properties: {} },
    },
    {
        name: 'list_users',
        description:
            'List real users with name, email, public id, role, status, company. ' +
            'Supports an optional search query and role/status filters.',
        parameters: {
            type: 'OBJECT',
            properties: {
                query: { type: 'STRING', description: 'Optional search over name, email, or public id' },
                role: { type: 'STRING', description: 'Filter by role', enum: ['OWNER', 'ADMIN', 'STAFF', 'SUPER_ADMIN'] },
                status: { type: 'STRING', description: 'Filter by account status' },
                limit: { type: 'INTEGER', description: 'Max rows to return (1-20)' },
            },
        },
    },
    {
        name: 'list_organizations',
        description:
            'List organizations/companies with public id, owner, subscription status and plan. ' +
            'Supports an optional search query.',
        parameters: {
            type: 'OBJECT',
            properties: {
                query: { type: 'STRING', description: 'Optional search over company name or public id' },
                limit: { type: 'INTEGER', description: 'Max rows to return (1-20)' },
            },
        },
    },
    {
        name: 'list_sites',
        description:
            'List operational/construction sites with company, address, status, assigned-worker and attendance counts.',
        parameters: {
            type: 'OBJECT',
            properties: {
                query: { type: 'STRING', description: 'Optional search over site name, address, or public id' },
                limit: { type: 'INTEGER', description: 'Max rows to return (1-20)' },
            },
        },
    },
    {
        name: 'list_subscriptions',
        description:
            'List organization subscriptions with plan, status (TRIALING/ACTIVE/PAST_DUE/EXPIRED/CANCELED), ' +
            'trial state, unlimited-access flag and period end.',
        parameters: {
            type: 'OBJECT',
            properties: {
                status: { type: 'STRING', description: 'Filter by subscription status', enum: ['TRIALING', 'ACTIVE', 'PAST_DUE', 'EXPIRED', 'CANCELED'] },
                trial: { type: 'STRING', description: 'Filter by trial state', enum: ['ACTIVE', 'EXPIRED', 'NONE'] },
                unlimited: { type: 'STRING', description: 'Filter by unlimited access', enum: ['GRANTED', 'STANDARD'] },
                limit: { type: 'INTEGER', description: 'Max rows to return (1-20)' },
            },
        },
    },
    {
        name: 'organizations_without_subscription',
        description:
            'List organizations that currently have no subscription record (never started a trial or plan). ' +
            'Use for "which companies have no subscription".',
        parameters: {
            type: 'OBJECT',
            properties: {
                limit: { type: 'INTEGER', description: 'Max rows to return (1-20)' },
            },
        },
    },
    {
        name: 'subscription_detail',
        description:
            'Full subscription snapshot for one organization: plan, status, trial, unlimited access, entitlements/offers, usage and invoices.',
        parameters: {
            type: 'OBJECT',
            properties: {
                orgRef: { type: 'STRING', description: 'Organization id, PM-CMP public id, or exact company name' },
            },
            required: ['orgRef'],
        },
    },
    {
        name: 'pending_owner_requests',
        description:
            'List pending owner requests awaiting admin review, with requester identity and requested company name.',
        parameters: {
            type: 'OBJECT',
            properties: {
                limit: { type: 'INTEGER', description: 'Max rows to return (1-20)' },
            },
        },
    },
    {
        name: 'reviews_summary',
        description:
            'Customer-review state: average rating, distribution, totals by status and the most recent pending reviews.',
        parameters: { type: 'OBJECT', properties: {} },
    },
    {
        name: 'provider_health',
        description:
            'Current health/status of every integrated provider (AI, email, payments, push, storage, search, observability). ' +
            'Use for "what is the current provider health".',
        parameters: { type: 'OBJECT', properties: {} },
    },
    {
        name: 'payments_summary',
        description:
            'Platform payment-event summary: totals by status and provider, plus the most recent events.',
        parameters: {
            type: 'OBJECT',
            properties: {
                limit: { type: 'INTEGER', description: 'Max recent events to return (1-20)' },
            },
        },
    },
    {
        name: 'mail_overview',
        description:
            'Mail-supply overview: monthly quota window, send totals, orgs using mail, and recent dispatch results.',
        parameters: { type: 'OBJECT', properties: {} },
    },
    {
        name: 'recent_announcements',
        description:
            'Most recent announcement campaigns with audience, recipient count and acknowledgement count.',
        parameters: {
            type: 'OBJECT',
            properties: {
                limit: { type: 'INTEGER', description: 'Max rows to return (1-20)' },
            },
        },
    },
    {
        name: 'recent_activity_report',
        description:
            'Trailing-window platform activity report (default 30 days): new users, companies, subscriptions, ' +
            'payments, mail dispatches, reviews, attendance and audit events, with daily series. ' +
            'Use for "what happened in the last N days".',
        parameters: {
            type: 'OBJECT',
            properties: {
                days: { type: 'INTEGER', description: 'Window length in days (1-30)' },
            },
        },
    },
    {
        name: 'audit_recent',
        description: 'Most recent audit-log entries: action, entity type, actor, timestamp.',
        parameters: {
            type: 'OBJECT',
            properties: {
                limit: { type: 'INTEGER', description: 'Max rows to return (1-20)' },
            },
        },
    },
    // --- Destructive operations: NEVER executed from a prompt. These only
    // --- resolve the target; ai.service turns the resolution into an explicit
    // --- confirmation the admin must approve with a token.
    {
        name: 'grant_unlimited_access',
        description:
            'PROPOSE granting unlimited access to an organization. Does NOT execute: returns a confirmation ' +
            'the administrator must explicitly approve.',
        parameters: {
            type: 'OBJECT',
            properties: {
                orgRef: { type: 'STRING', description: 'Organization id, PM-CMP public id, or exact company name' },
            },
            required: ['orgRef'],
        },
    },
    {
        name: 'revoke_unlimited_access',
        description:
            'PROPOSE revoking unlimited access from an organization. Does NOT execute: returns a confirmation ' +
            'the administrator must explicitly approve.',
        parameters: {
            type: 'OBJECT',
            properties: {
                orgRef: { type: 'STRING', description: 'Organization id, PM-CMP public id, or exact company name' },
            },
            required: ['orgRef'],
        },
    },
    {
        name: 'suspend_user',
        description:
            'PROPOSE suspending a user account. Does NOT execute: returns a confirmation the administrator must approve.',
        parameters: {
            type: 'OBJECT',
            properties: {
                userRef: { type: 'STRING', description: 'User id, PM-USR public id, or email' },
                reason: { type: 'STRING', description: 'Optional reason recorded in the audit trail' },
            },
            required: ['userRef'],
        },
    },
    {
        name: 'block_user',
        description:
            'PROPOSE blocking a user account. Does NOT execute: returns a confirmation the administrator must approve.',
        parameters: {
            type: 'OBJECT',
            properties: {
                userRef: { type: 'STRING', description: 'User id, PM-USR public id, or email' },
                reason: { type: 'STRING', description: 'Optional reason recorded in the audit trail' },
            },
            required: ['userRef'],
        },
    },
    {
        name: 'unsuspend_user',
        description:
            'PROPOSE lifting a user suspension. Does NOT execute: returns a confirmation the administrator must approve.',
        parameters: {
            type: 'OBJECT',
            properties: {
                userRef: { type: 'STRING', description: 'User id, PM-USR public id, or email' },
            },
            required: ['userRef'],
        },
    },
    {
        name: 'unblock_user',
        description:
            'PROPOSE unblocking a user account. Does NOT execute: returns a confirmation the administrator must approve.',
        parameters: {
            type: 'OBJECT',
            properties: {
                userRef: { type: 'STRING', description: 'User id, PM-USR public id, or email' },
            },
            required: ['userRef'],
        },
    },
];

const READ_TOOLS = new Set(AI_TOOL_DECLARATIONS
    .map((t) => t.name)
    .filter((name) => !['grant_unlimited_access', 'revoke_unlimited_access', 'suspend_user', 'block_user', 'unsuspend_user', 'unblock_user'].includes(name)));

const ACTION_TOOLS = new Set(AI_TOOL_DECLARATIONS.map((t) => t.name).filter((n) => !READ_TOOLS.has(n)));

export function isReadTool(name: string): boolean {
    return READ_TOOLS.has(name);
}

export function isActionTool(name: string): boolean {
    return ACTION_TOOLS.has(name);
}

// ---------------------------------------------------------------------------
// Reference resolution (id / publicId / exact name / email) against real rows.
// ---------------------------------------------------------------------------

function userEntity(u: { id: string; publicId: string; firstName: string; lastName: string; email: string }): AiEntity {
    return {
        type: 'user',
        id: u.id,
        publicId: u.publicId,
        name: `${u.firstName} ${u.lastName}`.trim(),
        subtitle: u.email,
        route: `/admin/users/${u.id}`,
    };
}

function orgEntity(o: { id: string; publicId: string; name: string }): AiEntity {
    return { type: 'org', id: o.id, publicId: o.publicId, name: o.name, subtitle: null, route: `/admin/subscriptions/${o.id}` };
}

const USER_SELECT = { id: true, publicId: true, firstName: true, lastName: true, email: true, role: true, status: true, isDisabled: true, deletedAt: true, orgId: true } as const;

async function resolveUser(db: AiToolsDb, ref: string) {
    const trimmed = ref.trim();
    const uuidLike = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(trimmed);
    const user = await db.user.findFirst({
        where: uuidLike
            ? { OR: [{ id: trimmed }, { publicId: trimmed }] }
            : trimmed.includes('@')
                ? { email: { equals: trimmed, mode: 'insensitive' } }
                : { OR: [{ publicId: { equals: trimmed, mode: 'insensitive' } }, { email: { equals: trimmed, mode: 'insensitive' } }] },
        select: { ...USER_SELECT, org: { select: { id: true, publicId: true, name: true } } },
    });
    return user ?? null;
}

async function resolveOrganization(db: AiToolsDb, ref: string) {
    const trimmed = ref.trim();
    const uuidLike = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(trimmed);
    return db.organization.findFirst({
        where: uuidLike
            ? { OR: [{ id: trimmed }, { publicId: { equals: trimmed, mode: 'insensitive' } }] }
            : { OR: [{ publicId: { equals: trimmed, mode: 'insensitive' } }, { name: { equals: trimmed, mode: 'insensitive' } }] },
        select: { id: true, publicId: true, name: true, status: true, deletedAt: true },
    }) ?? null;
}

// ---------------------------------------------------------------------------
// Registry
// ---------------------------------------------------------------------------

export class AdminAiToolRegistry {
    private readonly db: AiToolsDb;

    constructor(db: AiToolsDb = prisma as unknown as AiToolsDb) {
        this.db = db;
    }

    /** Execute a READ tool. Throws AppError for unknown tools — never falls through to anything dynamic. */
    async execute(name: string, args: Record<string, unknown>): Promise<AiToolResult> {
        if (!isReadTool(name)) {
            throw new AppError('AI_TOOL_UNAVAILABLE', `Tool "${name}" is not an executable read tool.`, 400);
        }
        switch (name) {
            case 'platform_stats': return this.platformStats();
            case 'list_users': return this.listUsers(args);
            case 'list_organizations': return this.listOrganizations(args);
            case 'list_sites': return this.listSites(args);
            case 'list_subscriptions': return this.listSubscriptions(args);
            case 'organizations_without_subscription': return this.organizationsWithoutSubscription(args);
            case 'subscription_detail': return this.subscriptionDetail(args);
            case 'pending_owner_requests': return this.pendingOwnerRequests(args);
            case 'reviews_summary': return this.reviewsSummary();
            case 'provider_health': return this.providerHealth();
            case 'payments_summary': return this.paymentsSummary(args);
            case 'mail_overview': return this.mailOverview();
            case 'recent_announcements': return this.recentAnnouncements(args);
            case 'recent_activity_report': return this.recentActivityReport(args);
            case 'audit_recent': return this.auditRecent(args);
            default:
                throw new AppError('AI_TOOL_UNAVAILABLE', `Unknown tool "${name}".`, 400);
        }
    }

    /**
     * Resolve the target of a DESTRUCTIVE operation so the service layer can
     * present an explicit confirmation. Performs no mutation whatsoever.
     */
    async resolveAction(name: string, args: Record<string, unknown>): Promise<AiActionResolution> {
        switch (name) {
            case 'grant_unlimited_access':
            case 'revoke_unlimited_access': {
                const orgRef = str(args.orgRef);
                if (!orgRef) throw new AppError('AI_ACTION_ARGUMENT_REQUIRED', 'An organization reference (orgRef) is required.', 400);
                const org = await resolveOrganization(this.db, orgRef);
                if (!org || org.deletedAt) throw new AppError('AI_TARGET_NOT_FOUND', `No active organization matches "${orgRef}".`, 404);
                const subscription = await this.db.subscription.findFirst({
                    where: { orgId: org.id, status: { in: ['TRIALING', 'ACTIVE', 'PAST_DUE'] } },
                    orderBy: { createdAt: 'desc' },
                    select: { id: true, status: true, unlimitedAccess: true, plan: { select: { code: true, name: true } } },
                });
                const granting = name === 'grant_unlimited_access';
                if (granting && subscription?.unlimitedAccess) {
                    throw new AppError('AI_ACTION_ALREADY_APPLIED', `${org.name} already has unlimited access.`, 409);
                }
                if (!granting && !subscription?.unlimitedAccess) {
                    throw new AppError('AI_ACTION_ALREADY_APPLIED', `${org.name} does not currently have unlimited access.`, 409);
                }
                return {
                    operation: granting ? 'GRANT_UNLIMITED' : 'REVOKE_UNLIMITED',
                    target: { type: 'org', id: org.id, publicId: org.publicId, name: org.name, subtitle: null },
                    currentState: {
                        organizationStatus: org.status,
                        subscription: subscription
                            ? { id: subscription.id, status: subscription.status, unlimitedAccess: subscription.unlimitedAccess, plan: subscription.plan }
                            : null,
                    },
                    consequences: granting
                        ? `Grant unlimited access to ${org.name}${subscription ? ` (current plan: ${subscription.plan?.name ?? subscription.plan?.code ?? 'n/a'}, status ${subscription.status})` : ' (no subscription record exists — one will be provisioned)'}: the organization bypasses all plan limits immediately, the change is audited, and the organization's owners are notified.`
                        : `Revoke unlimited access from ${org.name}: the organization immediately returns to its plan limits and entitlements, the change is audited, and the organization's owners are notified.`,
                    entity: orgEntity(org),
                };
            }
            case 'suspend_user':
            case 'block_user':
            case 'unsuspend_user':
            case 'unblock_user': {
                const userRef = str(args.userRef);
                if (!userRef) throw new AppError('AI_ACTION_ARGUMENT_REQUIRED', 'A user reference (userRef) is required.', 400);
                const user = await resolveUser(this.db, userRef);
                if (!user || user.deletedAt) throw new AppError('AI_TARGET_NOT_FOUND', `No active user matches "${userRef}".`, 404);
                if (user.role === 'SUPER_ADMIN') {
                    throw new AppError('AI_ACTION_FORBIDDEN', 'Super Admin accounts cannot be modified through the AI assistant.', 403);
                }
                const operation = name === 'suspend_user' ? 'SUSPEND_USER'
                    : name === 'block_user' ? 'BLOCK_USER'
                        : name === 'unsuspend_user' ? 'UNSUSPEND_USER'
                            : 'UNBLOCK_USER';
                const stateDesc = `current status: ${user.status}${user.isDisabled ? ', disabled' : ''}`;
                const verb = operation.startsWith('UN') ? operation.slice(2).toLowerCase() : operation.slice(0, -5).toLowerCase();
                return {
                    operation,
                    target: {
                        type: 'user',
                        id: user.id,
                        publicId: user.publicId,
                        name: `${user.firstName} ${user.lastName}`.trim(),
                        subtitle: `${user.email} • ${user.role}`,
                    },
                    currentState: { status: user.status, isDisabled: user.isDisabled, role: user.role, orgId: user.orgId },
                    consequences: `${operation.startsWith('UN') ? 'Restore' : 'Apply'} ${verb} for ${user.firstName} ${user.lastName} (${user.email}, ${stateDesc}): the account state changes immediately, the action is audited, and the user's sessions are invalidated where applicable.`,
                    entity: userEntity(user),
                };
            }
            default:
                throw new AppError('AI_TOOL_UNAVAILABLE', `"${name}" is not a supported operation.`, 400);
        }
    }

    // --- Read tool implementations ----------------------------------------

    private async platformStats(): Promise<AiToolResult> {
        const [users, owners, organizations, sites, attendance, payroll, pendingOwnerRequests, blockedUsers, subscriptions, activeSubscriptions, unlimitedSubscriptions, pendingReviews, announcements, mailDispatches] = await Promise.all([
            this.db.user.count({ where: { deletedAt: null } }),
            this.db.user.count({ where: { deletedAt: null, role: 'OWNER' } }),
            this.db.organization.count({ where: { deletedAt: null } }),
            this.db.site.count({ where: { deletedAt: null } }),
            this.db.attendanceRecord.count({ where: { deletedAt: null } }),
            this.db.payRun.count({ where: { deletedAt: null } }),
            this.db.ownerRequest.count({ where: { status: 'PENDING', deletedAt: null } }),
            this.db.user.count({ where: { deletedAt: null, isDisabled: true } }),
            this.db.subscription.count(),
            this.db.subscription.count({ where: { status: { in: ['TRIALING', 'ACTIVE', 'PAST_DUE'] } } }),
            this.db.subscription.count({ where: { unlimitedAccess: true } }),
            this.db.review.count({ where: { status: 'PENDING' } }),
            this.db.announcementCampaign.count(),
            this.db.mailDispatch.count(),
        ]);
        const data = {
            users, owners, organizations, sites, attendance, payroll,
            pendingOwnerRequests, blockedUsers, subscriptions, activeSubscriptions,
            unlimitedSubscriptions, pendingReviews, announcements, mailDispatches,
        };
        return {
            tool: 'platform_stats',
            summary: `${users} users (${owners} owners), ${organizations} companies, ${sites} sites, ${subscriptions} subscriptions (${activeSubscriptions} active, ${unlimitedSubscriptions} unlimited), ${pendingOwnerRequests} pending owner requests, ${pendingReviews} pending reviews, ${blockedUsers} blocked users.`,
            data,
            entities: [],
        };
    }

    private async listUsers(args: Record<string, unknown>): Promise<AiToolResult> {
        const query = str(args.query);
        const role = str(args.role);
        const status = str(args.status);
        const limit = clampLimit(args.limit);
        const where: Record<string, unknown> = { deletedAt: null };
        if (role) where.role = role;
        if (status) where.status = status;
        if (query) {
            where.OR = [
                { firstName: { contains: query, mode: 'insensitive' } },
                { lastName: { contains: query, mode: 'insensitive' } },
                { email: { contains: query, mode: 'insensitive' } },
                { publicId: { contains: query, mode: 'insensitive' } },
            ];
        }
        const [users, total] = await Promise.all([
            this.db.user.findMany({
                where,
                select: { ...USER_SELECT, org: { select: { id: true, publicId: true, name: true } } },
                orderBy: { createdAt: 'desc' },
                take: limit,
            }),
            this.db.user.count({ where }),
        ]);
        return {
            tool: 'list_users',
            summary: `${total} users match${total > 0 ? `; showing ${users.length}` : ''}.`,
            data: { total, users },
            entities: users.map((u: any) => userEntity(u)),
        };
    }

    private async listOrganizations(args: Record<string, unknown>): Promise<AiToolResult> {
        const query = str(args.query);
        const limit = clampLimit(args.limit);
        const where: Record<string, unknown> = { deletedAt: null };
        if (query) {
            where.OR = [
                { name: { contains: query, mode: 'insensitive' } },
                { publicId: { contains: query, mode: 'insensitive' } },
            ];
        }
        const [orgs, total] = await Promise.all([
            this.db.organization.findMany({
                where,
                select: {
                    id: true, publicId: true, name: true, status: true, createdAt: true,
                    subscriptions: { where: { status: { in: ['TRIALING', 'ACTIVE', 'PAST_DUE'] } }, orderBy: { createdAt: 'desc' }, take: 1, select: { status: true, unlimitedAccess: true, plan: { select: { code: true, name: true } } } },
                },
                orderBy: { createdAt: 'desc' },
                take: limit,
            }),
            this.db.organization.count({ where }),
        ]);
        const rows = orgs.map((o: any) => {
            const sub = o.subscriptions?.[0] ?? null;
            return {
                id: o.id, publicId: o.publicId, name: o.name, status: o.status, createdAt: o.createdAt,
                subscriptionStatus: sub?.status ?? 'NONE',
                plan: sub?.plan?.name ?? sub?.plan?.code ?? null,
                unlimitedAccess: sub?.unlimitedAccess ?? false,
            };
        });
        return {
            tool: 'list_organizations',
            summary: `${total} companies match${total > 0 ? `; showing ${rows.length}` : ''}.`,
            data: { total, organizations: rows },
            entities: rows.map((o: any) => orgEntity(o)),
        };
    }

    private async listSites(args: Record<string, unknown>): Promise<AiToolResult> {
        const query = str(args.query);
        const limit = clampLimit(args.limit);
        const where: Record<string, unknown> = { deletedAt: null, org: { deletedAt: null } };
        if (query) {
            where.OR = [
                { name: { contains: query, mode: 'insensitive' } },
                { address: { contains: query, mode: 'insensitive' } },
                { publicId: { contains: query, mode: 'insensitive' } },
            ];
        }
        const [sites, total] = await Promise.all([
            this.db.site.findMany({
                where,
                select: {
                    id: true, publicId: true, name: true, address: true, status: true, createdAt: true,
                    org: { select: { id: true, publicId: true, name: true } },
                    _count: {
                        select: {
                            siteAssignments: { where: { deletedAt: null } },
                            attendanceRecords: { where: { deletedAt: null } },
                        },
                    },
                },
                orderBy: { createdAt: 'desc' },
                take: limit,
            }),
            this.db.site.count({ where }),
        ]);
        const rows = sites.map((s: any) => ({
            id: s.id, publicId: s.publicId, name: s.name, address: s.address, status: s.status, createdAt: s.createdAt,
            company: s.org?.name ?? null, companyPublicId: s.org?.publicId ?? null,
            assignedWorkers: s._count?.siteAssignments ?? 0, attendanceRecords: s._count?.attendanceRecords ?? 0,
        }));
        return {
            tool: 'list_sites',
            summary: `${total} sites match${total > 0 ? `; showing ${rows.length}` : ''}.`,
            data: { total, sites: rows },
            entities: rows.map((s: any) => ({ type: 'site', id: s.id, publicId: s.publicId, name: s.name, subtitle: s.company, route: `/admin/sites/${s.id}` })),
        };
    }

    private async listSubscriptions(args: Record<string, unknown>): Promise<AiToolResult> {
        const status = str(args.status);
        const trial = str(args.trial);
        const unlimited = str(args.unlimited);
        const limit = clampLimit(args.limit);
        const where: Record<string, unknown> = {};
        if (status) where.status = status;
        if (trial === 'ACTIVE') where.trialEndsAt = { gt: new Date() };
        else if (trial === 'EXPIRED') where.trialEndsAt = { lte: new Date() };
        else if (trial === 'NONE') where.trialEndsAt = null;
        if (unlimited === 'GRANTED') where.unlimitedAccess = true;
        else if (unlimited === 'STANDARD') where.unlimitedAccess = false;

        const [subscriptions, total] = await Promise.all([
            this.db.subscription.findMany({
                where,
                select: {
                    id: true, orgId: true, status: true, unlimitedAccess: true, trialEndsAt: true,
                    currentPeriodEnd: true, createdAt: true,
                    org: { select: { id: true, publicId: true, name: true } },
                    plan: { select: { code: true, name: true } },
                },
                orderBy: { createdAt: 'desc' },
                take: limit,
            }),
            this.db.subscription.count({ where }),
        ]);
        const rows = subscriptions.map((s: any) => ({
            orgId: s.orgId, orgName: s.org?.name, orgPublicId: s.org?.publicId,
            plan: s.plan?.name ?? s.plan?.code ?? null, status: s.status,
            unlimitedAccess: s.unlimitedAccess, trialEndsAt: s.trialEndsAt, currentPeriodEnd: s.currentPeriodEnd,
        }));
        return {
            tool: 'list_subscriptions',
            summary: `${total} subscriptions match${total > 0 ? `; showing ${rows.length}` : ''}.`,
            data: { total, subscriptions: rows },
            entities: rows.map((s: any) => orgEntity({ id: s.orgId, publicId: s.orgPublicId, name: s.orgName })),
        };
    }

    private async organizationsWithoutSubscription(args: Record<string, unknown>): Promise<AiToolResult> {
        const limit = clampLimit(args.limit, 20);
        const orgs = await this.db.organization.findMany({
            where: {
                deletedAt: null,
                subscriptions: { none: { status: { in: ['TRIALING', 'ACTIVE', 'PAST_DUE'] } } },
            },
            select: {
                id: true, publicId: true, name: true, status: true, createdAt: true,
                _count: { select: { users: { where: { deletedAt: null } } } },
            },
            orderBy: { createdAt: 'desc' },
            take: limit,
        });
        const total = await this.db.organization.count({
            where: {
                deletedAt: null,
                subscriptions: { none: { status: { in: ['TRIALING', 'ACTIVE', 'PAST_DUE'] } } },
            },
        });
        const rows = orgs.map((o: any) => ({
            id: o.id, publicId: o.publicId, name: o.name, status: o.status, createdAt: o.createdAt,
            userCount: o._count?.users ?? 0,
        }));
        return {
            tool: 'organizations_without_subscription',
            summary: `${total} organization${total === 1 ? '' : 's'} currently without a subscription${total > 0 ? `; showing ${rows.length}` : ''}.`,
            data: { total, organizations: rows },
            entities: rows.map((o: any) => orgEntity(o)),
        };
    }

    private async subscriptionDetail(args: Record<string, unknown>): Promise<AiToolResult> {
        const orgRef = str(args.orgRef);
        if (!orgRef) throw new AppError('AI_TOOL_ARGUMENT_REQUIRED', 'An organization reference (orgRef) is required.', 400);
        const org = await resolveOrganization(this.db, orgRef);
        if (!org) throw new AppError('AI_TARGET_NOT_FOUND', `No organization matches "${orgRef}".`, 404);
        const subscription = await this.db.subscription.findFirst({
            where: { orgId: org.id },
            orderBy: { createdAt: 'desc' },
            select: {
                id: true, status: true, unlimitedAccess: true, trialEndsAt: true,
                currentPeriodStart: true, currentPeriodEnd: true, createdAt: true, updatedAt: true,
                plan: { select: { code: true, name: true, amountMinor: true, currency: true, interval: true } },
                entitlements: { orderBy: { createdAt: 'desc' }, select: { key: true, value: true, source: true, expiresAt: true } },
                invoices: { orderBy: { createdAt: 'desc' }, take: 5, select: { invoiceNumber: true, status: true, totalMinor: true, currency: true, createdAt: true } },
            },
        });
        return {
            tool: 'subscription_detail',
            summary: subscription
                ? `${org.name}: ${subscription.status} on plan ${subscription.plan?.name ?? subscription.plan?.code}${subscription.unlimitedAccess ? ' with UNLIMITED access' : ''}.`
                : `${org.name} has no subscription record.`,
            data: { organization: { id: org.id, publicId: org.publicId, name: org.name, status: org.status }, subscription },
            entities: [orgEntity(org)],
        };
    }

    private async pendingOwnerRequests(args: Record<string, unknown>): Promise<AiToolResult> {
        const limit = clampLimit(args.limit);
        const where = { status: 'PENDING', deletedAt: null };
        const [requests, total] = await Promise.all([
            this.db.ownerRequest.findMany({
                where,
                select: {
                    id: true, publicId: true, companyName: true, createdAt: true,
                    user: { select: { id: true, publicId: true, firstName: true, lastName: true, email: true } },
                },
                orderBy: { createdAt: 'asc' },
                take: limit,
            }),
            this.db.ownerRequest.count({ where }),
        ]);
        const rows = requests.map((r: any) => ({
            id: r.id, publicId: r.publicId, companyName: r.companyName, createdAt: r.createdAt,
            requester: r.user ? { publicId: r.user.publicId, name: `${r.user.firstName} ${r.user.lastName}`.trim(), email: r.user.email } : null,
        }));
        return {
            tool: 'pending_owner_requests',
            summary: `${total} pending owner request${total === 1 ? '' : 's'}${total > 0 ? `; showing ${rows.length}` : ''}.`,
            data: { total, requests: rows },
            entities: rows.filter((r: any) => r.requester).map((r: any) => ({
                type: 'user' as const,
                id: r.id,
                publicId: r.publicId,
                name: r.requester.name,
                subtitle: r.requester.email,
                route: `/admin/owner-requests`,
            })),
        };
    }

    private async reviewsSummary(): Promise<AiToolResult> {
        const [total, pending, published, hidden, flagged, agg, recentPending] = await Promise.all([
            this.db.review.count(),
            this.db.review.count({ where: { status: 'PENDING' } }),
            this.db.review.count({ where: { status: 'PUBLISHED' } }),
            this.db.review.count({ where: { status: 'HIDDEN' } }),
            this.db.review.count({ where: { status: 'FLAGGED' } }),
            this.db.review.aggregate({ _avg: { rating: true } }),
            this.db.review.findMany({
                where: { status: 'PENDING' },
                orderBy: { createdAt: 'asc' },
                take: 5,
                select: { id: true, publicId: true, rating: true, status: true, createdAt: true, org: { select: { id: true, publicId: true, name: true } } },
            }),
        ]);
        const rows = recentPending.map((r: any) => ({
            id: r.id, publicId: r.publicId, rating: r.rating, createdAt: r.createdAt, company: r.org?.name ?? null,
        }));
        const data = {
            total, pending, published, hidden, flagged,
            averageRating: agg._avg?.rating != null ? Number(Number(agg._avg.rating).toFixed(2)) : null,
            recentPending: rows,
        };
        return {
            tool: 'reviews_summary',
            summary: `${total} reviews (avg ${data.averageRating ?? '—'}): ${pending} pending, ${published} published, ${hidden} hidden, ${flagged} flagged.`,
            data,
            entities: rows.map((r: any) => ({ type: 'review' as const, id: r.id, publicId: r.publicId, name: `${r.rating}★ review`, subtitle: r.company, route: `/admin/reviews/${r.id}` })),
        };
    }

    private async providerHealth(): Promise<AiToolResult> {
        const providers = await providerHealth();
        const rows = providers.map((p: { provider: string; kind: string; status: string; enabled: boolean; detail?: string }) => ({
            provider: p.provider, kind: p.kind, status: p.status, enabled: p.enabled, detail: p.detail ?? null,
        }));
        const summary = rows.map((r) => `${r.provider}: ${r.status}`).join(', ');
        return {
            tool: 'provider_health',
            summary: `${rows.length} providers registered — ${summary}.`,
            data: { providers: rows },
            entities: [],
        };
    }

    private async paymentsSummary(args: Record<string, unknown>): Promise<AiToolResult> {
        const limit = clampLimit(args.limit, 10);
        const [total, byStatus, byProvider, recent] = await Promise.all([
            this.db.paymentEvent.count(),
            this.db.paymentEvent.groupBy({ by: ['status'], _count: { _all: true } }),
            this.db.paymentEvent.groupBy({ by: ['provider'], _count: { _all: true } }),
            this.db.paymentEvent.findMany({
                orderBy: { createdAt: 'desc' },
                take: limit,
                select: {
                    id: true, provider: true, eventType: true, status: true, createdAt: true,
                    org: { select: { id: true, publicId: true, name: true } },
                },
            }),
        ]);
        const statusMap = Object.fromEntries((byStatus as Array<{ status: string; _count: { _all: number } }>).map((g) => [g.status, g._count._all]));
        const providerMap = Object.fromEntries((byProvider as Array<{ provider: string; _count: { _all: number } }>).map((g) => [g.provider, g._count._all]));
        const rows = recent.map((e: any) => ({
            id: e.id, provider: e.provider, eventType: e.eventType, status: e.status, createdAt: e.createdAt, company: e.org?.name ?? null,
        }));
        return {
            tool: 'payments_summary',
            summary: `${total} payment events (${Object.entries(statusMap).map(([k, v]) => `${v} ${k}`).join(', ') || 'none'}).`,
            data: { total, byStatus: statusMap, byProvider: providerMap, recent: rows },
            entities: [],
        };
    }

    private async mailOverview(): Promise<AiToolResult> {
        const now = new Date();
        const periodStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
        const periodEnd = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1));
        const [dispatches, totalDispatches, monthUsage, orgCount, userCount] = await Promise.all([
            this.db.mailDispatch.findMany({
                orderBy: { createdAt: 'desc' },
                take: 10,
                select: { id: true, status: true, sent: true, failed: true, recipientCount: true, createdAt: true, org: { select: { id: true, publicId: true, name: true } } },
            }),
            this.db.mailDispatch.count(),
            this.db.usageRecord.findMany({ where: { metric: 'mail_supply', periodStart, periodEnd }, select: { orgId: true, quantity: true } }),
            this.db.organization.count({ where: { deletedAt: null } }),
            this.db.user.count({ where: { deletedAt: null, isDisabled: false } }),
        ]);
        const mailSentThisMonth = monthUsage.reduce((sum: number, r: { quantity: unknown }) => sum + Number(r.quantity ?? 0), 0);
        const rows = dispatches.map((d: any) => ({
            id: d.id, status: d.status, sent: d.sent, failed: d.failed, recipientCount: d.recipientCount,
            createdAt: d.createdAt, company: d.org?.name ?? null,
        }));
        return {
            tool: 'mail_overview',
            summary: `${totalDispatches} dispatches total; ${mailSentThisMonth} mails sent this month by ${monthUsage.length} org${monthUsage.length === 1 ? '' : 's'}.`,
            data: {
                periodStart, periodEnd,
                summary: { totalDispatches, mailSentThisMonth, orgsUsingMail: monthUsage.length, orgCount, userCount },
                recentDispatches: rows,
            },
            entities: [],
        };
    }

    private async recentAnnouncements(args: Record<string, unknown>): Promise<AiToolResult> {
        const limit = clampLimit(args.limit);
        const campaigns = await this.db.announcementCampaign.findMany({
            orderBy: { createdAt: 'desc' },
            take: limit,
            select: {
                id: true, title: true, type: true, audience: true, recipientCount: true, createdAt: true,
                organization: { select: { id: true, publicId: true, name: true } },
                _count: { select: { notifications: true } },
            },
        });
        const ids = campaigns.map((c: any) => c.id);
        const ackGroups = ids.length > 0
            ? await this.db.notification.groupBy({
                by: ['campaignId'],
                where: { campaignId: { in: ids }, type: 'ANNOUNCEMENT', readAt: { not: null } },
                _count: { _all: true },
            })
            : [];
        const ackByCampaign = new Map<string, number>(
            (ackGroups as Array<{ campaignId: string | null; _count: { _all: number } }>)
                .filter((g) => g.campaignId)
                .map((g) => [g.campaignId as string, g._count._all]),
        );
        const rows = campaigns.map((c: any) => ({
            id: c.id, title: c.title, type: c.type, audience: c.audience,
            recipientCount: c.recipientCount, acknowledgements: ackByCampaign.get(c.id) ?? 0,
            createdAt: c.createdAt, company: c.organization?.name ?? null,
        }));
        return {
            tool: 'recent_announcements',
            summary: rows.length > 0
                ? `Most recent: ${rows.map((r: any) => `"${r.title}" (${r.recipientCount} recipients, ${r.acknowledgements} ack)`).join('; ')}.`
                : 'No announcements have been dispatched.',
            data: { announcements: rows },
            entities: rows.map((r: any) => ({ type: 'announcement' as const, id: r.id, publicId: null, name: r.title, subtitle: r.company, route: `/admin/announcements` })),
        };
    }

    private async recentActivityReport(args: Record<string, unknown>): Promise<AiToolResult> {
        const daysRaw = typeof args.days === 'number' && Number.isFinite(args.days) ? Math.floor(args.days) : 30;
        const days = Math.max(1, Math.min(30, daysRaw));
        const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
        const [users, orgs, subscriptions, paymentEvents, mailDispatches, auditEvents, reviews, attendance] = await Promise.all([
            this.db.user.count({ where: { createdAt: { gte: since }, deletedAt: null } }),
            this.db.organization.count({ where: { createdAt: { gte: since }, deletedAt: null } }),
            this.db.subscription.count({ where: { createdAt: { gte: since } } }),
            this.db.paymentEvent.count({ where: { createdAt: { gte: since } } }),
            this.db.mailDispatch.count({ where: { createdAt: { gte: since } } }),
            this.db.auditLog.count({ where: { createdAt: { gte: since } } }),
            this.db.review.count({ where: { createdAt: { gte: since } } }),
            this.db.attendanceRecord.count({ where: { createdAt: { gte: since } } }),
        ]);
        const data = {
            window: { days, since: since.toISOString() },
            totals: {
                newUsers: users, newCompanies: orgs, newSubscriptions: subscriptions,
                paymentEvents, mailDispatches, auditEvents, reviews, attendance,
            },
        };
        return {
            tool: 'recent_activity_report',
            summary: `Last ${days} days: ${users} new users, ${orgs} new companies, ${subscriptions} new subscriptions, ${paymentEvents} payment events, ${mailDispatches} mail dispatches, ${reviews} reviews, ${auditEvents} audit events, ${attendance} attendance records.`,
            data,
            entities: [],
        };
    }

    private async auditRecent(args: Record<string, unknown>): Promise<AiToolResult> {
        const limit = clampLimit(args.limit, 10);
        const entries = await this.db.auditLog.findMany({
            orderBy: { createdAt: 'desc' },
            take: limit,
            select: {
                id: true, action: true, entityType: true, createdAt: true,
                user: { select: { publicId: true, firstName: true, lastName: true, email: true } },
            },
        });
        const rows = entries.map((e: any) => ({
            action: e.action, entityType: e.entityType, createdAt: e.createdAt,
            actor: e.user ? `${e.user.firstName} ${e.user.lastName}`.trim() : null,
        }));
        return {
            tool: 'audit_recent',
            summary: rows.length > 0
                ? `${rows.length} most recent audit entries, latest: ${rows[0].action} ${rows[0].entityType} by ${rows[0].actor ?? 'system'}.`
                : 'No audit entries recorded.',
            data: { entries: rows },
            entities: [],
        };
    }
}

export const adminAiToolRegistry = new AdminAiToolRegistry();
