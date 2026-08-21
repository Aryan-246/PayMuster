export interface AppContext {
  requestId: string;
  user?: {
    id: string;
    email: string;
    role: string;
    orgId: string | null;
  };
  tenant?: {
    companyId?: string;
    siteId?: string;
  };
}
