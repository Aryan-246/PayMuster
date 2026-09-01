import { config } from './config.js';

/**
 * Runtime feature flags (blueprint §L/§T). Unlike the frozen `config` object,
 * this state is mutable so tests can exercise both flag positions without
 * reloading modules. Values are initialized from configuration and MUST NOT
 * be flipped at runtime by application code — flags change via environment
 * and deployment, never per-request.
 *
 * multiCompanyEnabled — membership-authoritative multi-company mode.
 * DEFAULT OFF. When OFF, the tenant middleware's single `user.orgId` check is
 * the only tenant gate (existing single-company behavior, unchanged). When
 * ON, an ACTIVE Membership row additionally grants tenant access to that
 * company. Flipping this ON against production data is an explicit, separate
 * operational decision.
 */
export const featureFlags = {
  multiCompanyEnabled: config.multiCompanyEnabled,
};

export function resetFeatureFlags(): void {
  featureFlags.multiCompanyEnabled = config.multiCompanyEnabled;
}
