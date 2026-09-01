import { afterEach, describe, expect, it, vi } from 'vitest';
import { getServiceAccountCredentials, getSessionSecret } from '../src/config.js';

describe('getServiceAccountCredentials', () => {
  afterEach(() => {
    vi.unstubAllEnvs();
  });

  it('throws when GOOGLE_CLIENT_EMAIL is missing', () => {
    vi.stubEnv('GOOGLE_CLIENT_EMAIL', '');
    vi.stubEnv('GOOGLE_PRIVATE_KEY', 'key');
    expect(() => getServiceAccountCredentials()).toThrow(/GOOGLE_CLIENT_EMAIL/);
  });

  it('throws when GOOGLE_PRIVATE_KEY is missing', () => {
    vi.stubEnv('GOOGLE_CLIENT_EMAIL', 'sa@example.iam.gserviceaccount.com');
    vi.stubEnv('GOOGLE_PRIVATE_KEY', '');
    expect(() => getServiceAccountCredentials()).toThrow(/GOOGLE_PRIVATE_KEY/);
  });

  it('unescapes \\n sequences in the private key', () => {
    vi.stubEnv('GOOGLE_CLIENT_EMAIL', 'sa@example.iam.gserviceaccount.com');
    vi.stubEnv('GOOGLE_PRIVATE_KEY', '-----BEGIN KEY-----\\nabc\\n-----END KEY-----');
    const creds = getServiceAccountCredentials();
    expect(creds.privateKey).toBe('-----BEGIN KEY-----\nabc\n-----END KEY-----');
    expect(creds.clientEmail).toBe('sa@example.iam.gserviceaccount.com');
  });
});

describe('getSessionSecret', () => {
  afterEach(() => {
    vi.unstubAllEnvs();
  });

  it('throws when SESSION_SECRET is missing', () => {
    vi.stubEnv('SESSION_SECRET', '');
    expect(() => getSessionSecret()).toThrow(/SESSION_SECRET/);
  });

  it('returns the configured secret', () => {
    vi.stubEnv('SESSION_SECRET', 'shh');
    expect(getSessionSecret()).toBe('shh');
  });
});
