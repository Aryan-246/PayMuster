import { prisma } from '../lib/prisma.js';
import type {
    ProviderHealth,
    SearchHit,
    SearchProvider,
    SearchRequest,
    SearchResult,
} from './contracts.js';

function health(): ProviderHealth {
    return {
        provider: 'database',
        kind: 'SEARCH',
        status: 'CONNECTED',
        enabled: true,
        checkedAt: new Date().toISOString(),
        detail: 'Tenant-scoped Prisma search fallback.',
    };
}

export class DatabaseSearchProvider implements SearchProvider {
    readonly name = 'database';

    async search(request: SearchRequest): Promise<SearchResult> {
        const query = request.query.trim();
        const skip = Math.max(0, (request.page - 1) * request.limit);
        const limit = Math.min(Math.max(1, request.limit), 100);
        const userWhere: Record<string, unknown> = { deletedAt: null };

        if (request.context.role !== 'SUPER_ADMIN') {
            userWhere.orgId = request.context.orgId ?? '__missing_org__';
        }
        if (query) {
            userWhere.OR = [
                { email: { contains: query, mode: 'insensitive' } },
                { firstName: { contains: query, mode: 'insensitive' } },
                { lastName: { contains: query, mode: 'insensitive' } },
                { phone: { contains: query, mode: 'insensitive' } },
                { publicId: { contains: query, mode: 'insensitive' } },
            ];
        }
        if (request.filters.role) userWhere.role = request.filters.role;
        if (request.filters.status === 'ACTIVE') {
            userWhere.isActive = true;
            userWhere.isDisabled = false;
        } else if (request.filters.status === 'BLOCKED') {
            userWhere.isDisabled = true;
        }

        const [users, total] = await Promise.all([
            prisma.user.findMany({
                where: userWhere as never,
                select: {
                    id: true,
                    publicId: true,
                    email: true,
                    firstName: true,
                    lastName: true,
                    role: true,
                    status: true,
                    orgId: true,
                },
                orderBy: { createdAt: 'desc' },
                skip,
                take: limit,
            }),
            prisma.user.count({ where: userWhere as never }),
        ]);

        const hits: SearchHit[] = users.map((user) => ({
            id: user.id,
            entityType: 'USER',
            title: [user.firstName, user.lastName].filter(Boolean).join(' ') || user.email || 'User',
            subtitle: user.email ?? undefined,
            status: user.status,
            orgId: user.orgId,
            metadata: {
                publicId: user.publicId,
                role: user.role,
                email: user.email,
            },
        }));

        return {
            hits,
            total,
            page: request.page,
            totalPages: Math.ceil(total / limit),
            provider: this.name,
            fallbackUsed: true,
        };
    }

    async health(): Promise<ProviderHealth> {
        return health();
    }
}

export const databaseSearchProvider = new DatabaseSearchProvider();
