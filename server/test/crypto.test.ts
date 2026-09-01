import { describe, expect, it } from 'vitest';
import {
  sha256Hex,
  timingSafeEqualString,
  generateDeviceToken,
  signSessionToken,
  verifySessionToken,
} from '../src/crypto.js';

describe('sha256Hex', () => {
  it('matches a known SHA-256 digest', () => {
    // echo -n "hello" | sha256sum
    expect(sha256Hex('hello')).toBe(
      '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824'
    );
  });

  it('is deterministic for the same input', () => {
    expect(sha256Hex('端末トークン')).toBe(sha256Hex('端末トークン'));
  });

  it('differs for different input', () => {
    expect(sha256Hex('a')).not.toBe(sha256Hex('b'));
  });
});

describe('timingSafeEqualString', () => {
  it('returns true for identical strings', () => {
    expect(timingSafeEqualString('1111', '1111')).toBe(true);
  });

  it('returns false for different strings of the same length', () => {
    expect(timingSafeEqualString('1111', '1112')).toBe(false);
  });

  it('returns false (not throw) for different-length strings', () => {
    expect(timingSafeEqualString('1111', '11111')).toBe(false);
    expect(timingSafeEqualString('', '1')).toBe(false);
  });

  it('returns false for empty vs empty only when both are literally empty', () => {
    expect(timingSafeEqualString('', '')).toBe(true);
  });
});

describe('generateDeviceToken', () => {
  it('generates a non-empty, sufficiently long random token', () => {
    const token = generateDeviceToken();
    expect(token.length).toBeGreaterThanOrEqual(32);
  });

  it('generates different tokens each call', () => {
    expect(generateDeviceToken()).not.toBe(generateDeviceToken());
  });
});

describe('session token sign/verify', () => {
  const secret = 'test-secret';

  it('round-trips a valid, unexpired token', () => {
    const token = signSessionToken({ name: '八木', ttlSeconds: 3600 }, secret);
    const result = verifySessionToken(token, secret);
    expect(result).toEqual({ name: '八木' });
  });

  it('rejects a token signed with a different secret', () => {
    const token = signSessionToken({ name: '八木', ttlSeconds: 3600 }, secret);
    expect(verifySessionToken(token, 'wrong-secret')).toBeNull();
  });

  it('rejects an expired token', () => {
    const token = signSessionToken({ name: '八木', ttlSeconds: -1 }, secret);
    expect(verifySessionToken(token, secret)).toBeNull();
  });

  it('rejects a tampered payload', () => {
    const token = signSessionToken({ name: '八木', ttlSeconds: 3600 }, secret);
    const [payload, sig] = token.split('.');
    const tamperedPayload = Buffer.from(
      JSON.stringify({ name: '大滝', exp: Date.now() + 3600_000 })
    ).toString('base64url');
    expect(verifySessionToken(`${tamperedPayload}.${sig}`, secret)).toBeNull();
  });

  it('rejects garbage input', () => {
    expect(verifySessionToken('not-a-token', secret)).toBeNull();
    expect(verifySessionToken('', secret)).toBeNull();
  });
});
