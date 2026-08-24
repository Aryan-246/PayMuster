import { config } from '../lib/config.js';
import type { AuthCapabilities, AuthProvider, ProviderHealth } from './contracts.js';

export class ClerkAdapter implements AuthProvider {
    readonly name = 'clerk';

    async capabilities(): Promise<AuthCapabilities> {
        return {
            provider: this.name,
            password: false,
            google: false,
            passkeys: false,
            organizations: false,
            sessionRevocation: false,
        };
    }

    async health(): Promise<ProviderHealth> {
        const configured = Boolean(config.clerkPublishableKey && config.clerkSecretKey);
        const enabled = config.clerkEnabled;
        return {
            provider: this.name,
            kind: 'AUTH',
            enabled,
            status: !enabled ? 'DISABLED' : 'UNAVAILABLE',
            readiness: !enabled ? 'DISABLED' : 'ENVIRONMENT_BLOCKED',
            fallback: 'paymuster-auth',
            checkedAt: new Date().toISOString(),
            detail: !enabled
                ? 'Existing PayMuster authentication remains authoritative.'
                : configured
                    ? 'Clerk credentials are present, but alternate authentication is blocked until RBAC and session compatibility are approved.'
                    : 'Clerk is enabled but remains blocked; required server configuration is incomplete.',
        };
    }
}

export const clerkAdapter = new ClerkAdapter();
