export type ProviderHealthStatus =
    | 'CONNECTED'
    | 'DISABLED'
    | 'INVALID_CONFIGURATION'
    | 'RATE_LIMITED'
    | 'UNAVAILABLE';

export type ProviderKind =
    | 'AI'
    | 'SEARCH'
    | 'STORAGE'
    | 'REALTIME'
    | 'AUTH'
    | 'EMAIL'
    | 'PAYMENT'
    | 'PUSH'
    | 'MAPS'
    | 'OBSERVABILITY';

export type ProviderReadiness =
    | 'READY'
    | 'DISABLED'
    | 'MISSING_CONFIGURATION'
    | 'INVALID_CONFIGURATION'
    | 'ENVIRONMENT_BLOCKED';

export interface ProviderHealth {
    provider: string;
    kind: ProviderKind;
    status: ProviderHealthStatus;
    readiness?: ProviderReadiness;
    enabled: boolean;
    fallback?: string;
    checkedAt: string;
    detail?: string;
}

export interface ProviderConfigurationSummary {
    provider: string;
    kind: ProviderKind;
    enabled: boolean;
    readiness: ProviderReadiness;
    configured: boolean;
    testMode?: boolean;
    fallback?: string;
}

export interface ProviderContext {
    userId: string;
    role: string;
    orgId: string | null;
    siteId?: string | null;
    permissions: readonly string[];
}

export interface AIProviderRequest {
    operation: 'ANALYZE' | 'SUMMARY' | 'INSIGHTS' | 'QUERY';
    prompt: string;
    context: Record<string, string | number | boolean | null>;
}

export interface AIProviderResult {
    analysis: string;
    recommendation: string | null;
    proposal: Record<string, unknown> | null;
    confidence: number | null;
    metadata: Record<string, unknown>;
}

export interface AIProvider {
    readonly name: string;
    analyze(request: AIProviderRequest): Promise<AIProviderResult>;
    health(): Promise<ProviderHealth>;
}

export interface SearchFilters {
    entityTypes?: readonly SearchEntityType[];
    role?: string;
    status?: string;
    siteId?: string;
    from?: Date;
    to?: Date;
}

export type SearchEntityType =
    | 'USER'
    | 'ORGANIZATION'
    | 'SITE'
    | 'DOCUMENT'
    | 'ATTENDANCE'
    | 'PAYROLL'
    | 'ANNOUNCEMENT'
    | 'NOTIFICATION'
    | 'AUDIT_LOG';

export interface SearchRequest {
    query: string;
    page: number;
    limit: number;
    filters: SearchFilters;
    context: ProviderContext;
}

export interface SearchHit {
    id: string;
    entityType: SearchEntityType;
    title: string;
    subtitle?: string;
    status?: string;
    orgId: string | null;
    route?: string;
    metadata: Record<string, string | number | boolean | null>;
}

export interface SearchResult {
    hits: SearchHit[];
    total: number;
    page: number;
    totalPages: number;
    provider: string;
    fallbackUsed: boolean;
}

export interface SearchProvider {
    readonly name: string;
    search(request: SearchRequest): Promise<SearchResult>;
    health(): Promise<ProviderHealth>;
}

export interface StorageUpload {
    key: string;
    contentType: string;
    body: Buffer;
    metadata: Record<string, string>;
}

export interface StorageObject {
    key: string;
    provider: string;
    byteSize: number;
    contentType: string;
}

export interface StorageProvider {
    readonly name: string;
    upload(input: StorageUpload): Promise<StorageObject>;
    remove(key: string): Promise<void>;
    createSignedUrl(key: string, expiresInSeconds: number): Promise<{ url: string; expiresInSeconds: number }>;
    health(): Promise<ProviderHealth>;
}

export interface RealtimeChannelRequest {
    channelId: string;
    context: ProviderContext;
    memberIds: readonly string[];
    orgId: string;
    siteId?: string | null;
}

export interface RealtimeProvider {
    readonly name: string;
    authorize(request: RealtimeChannelRequest): Promise<boolean>;
    health(): Promise<ProviderHealth>;
}

export interface AuthCapabilities {
    provider: string;
    password: boolean;
    google: boolean;
    passkeys: boolean;
    organizations: boolean;
    sessionRevocation: boolean;
}

export interface AuthProvider {
    readonly name: string;
    capabilities(): Promise<AuthCapabilities>;
    health(): Promise<ProviderHealth>;
}

export interface PaymentOrderRequest {
    organizationId: string;
    userId: string;
    amountMinor: bigint;
    currency: string;
    receipt: string;
    notes?: Record<string, string>;
    idempotencyKey: string;
}

export interface PaymentOrder {
    provider: string;
    orderId: string;
    amountMinor: bigint;
    currency: string;
    status: 'CREATED' | 'PAID' | 'FAILED' | 'REFUNDED';
}

export interface PaymentRefundRequest {
    paymentId: string;
    amountMinor?: bigint;
    notes?: Record<string, string>;
    idempotencyKey: string;
}

export interface PaymentRefund {
    provider: string;
    refundId: string;
    paymentId: string;
    amountMinor: bigint;
    currency: string;
    status: 'PROCESSED' | 'PENDING' | 'FAILED';
}

export interface PaymentReconciliation {
    provider: string;
    paymentId: string;
    orderId: string | null;
    amountMinor: bigint | null;
    currency: string | null;
    status: 'CREATED' | 'AUTHORIZED' | 'CAPTURED' | 'FAILED' | 'REFUNDED' | 'UNKNOWN';
    providerEventId?: string;
}

export interface PaymentProvider {
    readonly name: string;
    createOrder(request: PaymentOrderRequest): Promise<PaymentOrder>;
    refundPayment(request: PaymentRefundRequest): Promise<PaymentRefund>;
    reconcilePayment(paymentId: string): Promise<PaymentReconciliation>;
    verifyCheckoutSignature(input: {
        orderId: string;
        paymentId: string;
        signature: string;
    }): boolean;
    verifyWebhookSignature(rawBody: string, signature: string): boolean;
    health(): Promise<ProviderHealth>;
}

export interface PushMessage {
    eventId: string;
    token: string;
    title: string;
    body: string;
    data: Record<string, string>;
}

export interface PushProvider {
    readonly name: string;
    send(message: PushMessage): Promise<'SENT' | 'INVALID_TOKEN' | 'UNAVAILABLE'>;
    health(): Promise<ProviderHealth>;
}

export interface EmailMessage {
    eventId: string;
    to: string;
    subject: string;
    text: string;
    html: string;
}

export interface EmailProvider {
    readonly name: string;
    send(message: EmailMessage): Promise<'SENT' | 'SKIPPED' | 'UNAVAILABLE'>;
    health(): Promise<ProviderHealth>;
}

export interface LocationValidationRequest {
    organizationId: string;
    siteId: string;
    latitude: number;
    longitude: number;
    accuracyMeters?: number;
    capturedAt: Date;
}

export interface LocationValidationResult {
    valid: boolean;
    distanceMeters: number | null;
    reason:
    | 'VALID'
    | 'SITE_NOT_CONFIGURED'
    | 'OUTSIDE_GEOFENCE'
    | 'LOW_ACCURACY'
    | 'STALE_CAPTURE'
    | 'INVALID_COORDINATES';
}

export interface MapsProvider {
    readonly name: string;
    validateLocation(request: LocationValidationRequest): Promise<LocationValidationResult>;
    health(): Promise<ProviderHealth>;
}
