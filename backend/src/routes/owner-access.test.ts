import assert from 'node:assert/strict';
import test from 'node:test';

import adminRouter from './admin.routes.js';
import companyRouter from './company.routes.js';

interface RouterLayer {
    name: string;
    route?: {
        path: string;
        methods: Record<string, boolean>;
        stack: Array<{ handle: { name?: string } }>;
    };
}

function routePaths(router: unknown): string[] {
    return (router as { stack: RouterLayer[] }).stack
        .filter((layer) => layer.route)
        .map((layer) => layer.route!.path);
}

test('company routes expose owner submission and personal status but no review endpoints', () => {
    const paths = routePaths(companyRouter);

    assert.ok(paths.includes('/owner-request'));
    assert.ok(paths.includes('/owner-request/my'));
    assert.equal(paths.some((path) => path.includes('owner-request/:id/approve')), false);
    assert.equal(paths.some((path) => path.includes('owner-request/:id/reject')), false);
    assert.equal(paths.some((path) => path.includes('owner-requests/:id/approve')), false);
    assert.equal(paths.some((path) => path.includes('owner-requests/:id/reject')), false);
});

test('owner review endpoints exist only after the Admin router authentication and manage-system gates', () => {
    const layers = (adminRouter as unknown as { stack: RouterLayer[] }).stack;
    const approvalIndex = layers.findIndex((layer) => layer.route?.path === '/owner-requests/:id/approve');
    const rejectionIndex = layers.findIndex((layer) => layer.route?.path === '/owner-requests/:id/reject');
    const requireAuthIndex = layers.findIndex((layer) => layer.name === 'requireAuth');
    const permissionIndex = layers.findIndex((layer) => layer.name === '<anonymous>');

    assert.ok(approvalIndex >= 0);
    assert.ok(rejectionIndex >= 0);
    assert.ok(requireAuthIndex >= 0 && requireAuthIndex < approvalIndex);
    assert.ok(requireAuthIndex < rejectionIndex);
    assert.ok(permissionIndex >= 0 && permissionIndex < approvalIndex);
    assert.ok(permissionIndex < rejectionIndex);

    const approval = layers[approvalIndex].route!;
    const rejection = layers[rejectionIndex].route!;
    assert.equal(approval.methods.post, true);
    assert.equal(rejection.methods.post, true);
});
