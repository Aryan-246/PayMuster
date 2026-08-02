import test from 'node:test';
import assert from 'node:assert/strict';
import { comparePassword, constantTimeEqual, generateSecureOtp, hashOtp, hashPassword, isOtpExpired, validateStrongPassword, } from './auth-utils.js';
test('hashPassword and comparePassword work for the same value', async () => {
    const password = 'StrongPass123!';
    const hash = await hashPassword(password);
    assert.notEqual(hash, password);
    assert.equal(await comparePassword(password, hash), true);
    assert.equal(await comparePassword('wrong', hash), false);
});
test('generateSecureOtp creates a numeric code with the expected length and expiry', () => {
    const otp = generateSecureOtp(6);
    assert.match(otp, /^\d{6}$/);
    assert.equal(otp.length, 6);
    const expired = isOtpExpired(new Date(Date.now() - 60_000));
    const active = isOtpExpired(new Date(Date.now() + 60_000));
    assert.equal(expired, true);
    assert.equal(active, false);
});
test('OTP hashes are keyed and compare in constant time', () => {
    const hash = hashOtp('123456', 'test-secret');
    assert.equal(constantTimeEqual(hash, hashOtp('123456', 'test-secret')), true);
    assert.equal(constantTimeEqual(hash, hashOtp('654321', 'test-secret')), false);
});
test('strong password validation enforces every required character class', () => {
    assert.deepEqual(validateStrongPassword('StrongPass123!'), []);
    assert.notEqual(validateStrongPassword('password123').length, 0);
});
