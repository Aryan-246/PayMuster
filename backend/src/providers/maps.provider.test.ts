import assert from 'node:assert/strict';
import test from 'node:test';
import { StoredCoordinateMapsProvider } from './maps.provider.js';

function provider(site: { latitude: number | null; longitude: number | null; geoFenceRadius: number | null } | null) {
    return new StoredCoordinateMapsProvider({
        site: { findFirst: async () => site },
    });
}

const request = {
    organizationId: 'org-1',
    siteId: 'site-1',
    latitude: 12.9716,
    longitude: 77.5946,
    capturedAt: new Date(),
};

test('stored coordinate provider accepts a capture inside the server geofence', async () => {
    const result = await provider({ latitude: request.latitude, longitude: request.longitude, geoFenceRadius: 100 }).validateLocation(request);
    assert.equal(result.valid, true);
    assert.equal(result.reason, 'VALID');
    assert.equal(result.distanceMeters, 0);
});

test('stored coordinate provider rejects an outside capture without trusting client claims', async () => {
    const result = await provider({ latitude: request.latitude, longitude: request.longitude, geoFenceRadius: 50 }).validateLocation({
        ...request,
        latitude: 13.0000,
        longitude: 77.5946,
    });
    assert.equal(result.valid, false);
    assert.equal(result.reason, 'OUTSIDE_GEOFENCE');
    assert.ok((result.distanceMeters ?? 0) > 50);
});

test('stored coordinate provider rejects missing site geofence configuration', async () => {
    const result = await provider({ latitude: null, longitude: null, geoFenceRadius: null }).validateLocation(request);
    assert.deepEqual(result, { valid: false, distanceMeters: null, reason: 'SITE_NOT_CONFIGURED' });
});

test('stored coordinate provider rejects stale and low-accuracy captures', async () => {
    const site = { latitude: request.latitude, longitude: request.longitude, geoFenceRadius: 100 };
    const stale = await provider(site).validateLocation({ ...request, capturedAt: new Date(Date.now() - 11 * 60 * 1000) });
    assert.equal(stale.reason, 'STALE_CAPTURE');

    const inaccurate = await provider(site).validateLocation({ ...request, accuracyMeters: 101 });
    assert.equal(inaccurate.reason, 'LOW_ACCURACY');
});

test('stored coordinate provider rejects invalid coordinates', async () => {
    const result = await provider({ latitude: request.latitude, longitude: request.longitude, geoFenceRadius: 100 }).validateLocation({
        ...request,
        latitude: 91,
    });
    assert.deepEqual(result, { valid: false, distanceMeters: null, reason: 'INVALID_COORDINATES' });
});
