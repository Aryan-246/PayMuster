import { createContext, useContext } from 'react';

/**
 * The company the dashboard is currently operating in. Defaults to the
 * session's primary org (user.orgId) and can only be switched when the
 * multi-company feature flag is enabled server-side — the backend remains the
 * security boundary and re-validates every request against the active company
 * (single-org check, or an ACTIVE Membership row when the flag is ON).
 */
export const ActiveCompanyContext = createContext<{
  activeOrgId: string;
  setActiveOrgId: (orgId: string) => void;
}>({
  activeOrgId: '',
  setActiveOrgId: () => undefined,
});

export function useActiveCompany() {
  return useContext(ActiveCompanyContext);
}
