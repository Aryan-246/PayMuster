import { prisma } from '../lib/prisma.js';
import type {
    LocationValidationRequest,
    LocationValidationResult,
    MapsProvider,
    ProviderHealth,
} from './contracts.js';

const MAX_CAPTURE_AGE_MS = 10 * 60 * 1000;
const MAX_ACCURACY_METERS = 100;
const EARTH_RADIUS_METERS = 6_371_000;

type SiteLookupClient = {
    site: {
        findFirst(args: unknown): Promise<{
            latitude: number | null;
            longitude: number | null;
            geoFenceRadius: number | null;
        } | null>;
    };
};

function haversineDistanceMeters(
    latitude: number,
    longitude: number,
    siteLatitude: number,
    siteLongitude: number,
): number {
    const toRadians = (degrees: number) => (degrees * Math.PI) / 180;
    const latitudeDelta = toRadians(siteLatitude - latitude);
    const longitudeDelta = toRadians(siteLongitude - longitude);
    const latitudeA = toRadians(latitude);
    const latitudeB = toRadians(siteLatitude);
    const a =
        Math.sin(latitudeDelta / 2) ** 2
        + Math.cos(latitudeA) * Math.cos(latitudeB) * Math.sin(longitudeDelta / 2) ** 2;
    return 2 * EARTH_RADIUS_METERS * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function invalidCoordinates(request: LocationValidationRequest): boolean {
    return !Number.isFinite(request.latitude)
        || !Number.isFinite(request.longitude)
        || request.latitude < -90
        || request.latitude > 90
        || request.longitude < -180
        || request.longitude > 180;
}

export class StoredCoordinateMapsProvider implements MapsProvider {
    readonly name = 'stored-site-coordinates';

    constructor(private readonly db: SiteLookupClient = prisma) { }

    async validateLocation(request: LocationValidationRequest): Promise<LocationValidationResult> {
        if (invalidCoordinates(request)) {
            return { valid: false, distanceMeters: null, reason: 'INVALID_COORDINATES' };
        }

        const captureAgeMs = Date.now() - request.capturedAt.getTime();
        if (!Number.isFinite(captureAgeMs) || captureAgeMs > MAX_CAPTURE_AGE_MS || captureAgeMs < -60_000) {
            return { valid: false, distanceMeters: null, reason: 'STALE_CAPTURE' };
        }
        if (request.accuracyMeters !== undefined
            && (!Number.isFinite(request.accuracyMeters) || request.accuracyMeters < 0 || request.accuracyMeters > MAX_ACCURACY_METERS)) {
            return { valid: false, distanceMeters: null, reason: 'LOW_ACCURACY' };
        }

        const site = await this.db.site.findFirst({
            where: { id: request.siteId, orgId: request.organizationId, deletedAt: null },
            select: { latitude: true, longitude: true, geoFenceRadius: true },
        });
        if (!site || site.latitude === null || site.longitude === null || site.geoFenceRadius === null || site.geoFenceRadius <= 0) {
            return { valid: false, distanceMeters: null, reason: 'SITE_NOT_CONFIGURED' };
        }

        const distanceMeters = haversineDistanceMeters(
            request.latitude,
            request.longitude,
            site.latitude,
            site.longitude,
        );
        const valid = distanceMeters <= site.geoFenceRadius + (request.accuracyMeters ?? 0);
        return {
            valid,
            distanceMeters: Math.round(distanceMeters * 100) / 100,
            reason: valid ? 'VALID' : 'OUTSIDE_GEOFENCE',
        };
    }

    async health(): Promise<ProviderHealth> {
        return {
            provider: this.name,
            kind: 'MAPS',
            status: 'CONNECTED',
            readiness: 'READY',
            enabled: true,
            checkedAt: new Date().toISOString(),
            detail: 'Server validates coordinates against tenant-scoped site coordinates and radius.',
        };
    }
}

export const storedCoordinateMapsProvider = new StoredCoordinateMapsProvider();
