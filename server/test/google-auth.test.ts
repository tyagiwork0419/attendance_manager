import { afterEach, describe, expect, it, vi } from 'vitest';
import { JWT } from 'google-auth-library';

vi.mock('../src/config.js', async () => {
  const actual = await vi.importActual<typeof import('../src/config.js')>(
    '../src/config.js'
  );
  return {
    ...actual,
    getServiceAccountCredentials: vi.fn(() => ({
      clientEmail: 'sa@example.iam.gserviceaccount.com',
      privateKey: 'fake-key',
    })),
  };
});

describe('getAuthClient', () => {
  afterEach(() => {
    vi.resetModules();
  });

  it('builds a JWT client with the service account email and required scopes', async () => {
    const { getAuthClient } = await import('../src/google/auth.js');
    const client = getAuthClient();

    expect(client).toBeInstanceOf(JWT);
    expect(client.email).toBe('sa@example.iam.gserviceaccount.com');
    const scopes = (client as unknown as { scopes: string[] }).scopes;
    expect(scopes).toEqual(
      expect.arrayContaining([
        'https://www.googleapis.com/auth/spreadsheets',
        'https://www.googleapis.com/auth/drive',
        'https://www.googleapis.com/auth/calendar.readonly',
      ])
    );
  });

  it('reuses the same client instance across calls (no re-auth per request)', async () => {
    const { getAuthClient } = await import('../src/google/auth.js');
    expect(getAuthClient()).toBe(getAuthClient());
  });
});
