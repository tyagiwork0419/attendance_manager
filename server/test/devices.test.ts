import { describe, expect, it, vi } from 'vitest';
import type { SheetsClient } from '../src/google/sheets.js';
import { appendDevice, resolveDevice, setDeviceOwner } from '../src/devices.js';
import { sha256Hex } from '../src/crypto.js';
import { formatDateJST } from '../src/dateFormat.js';

const HEADER = ['token_hash', 'user', 'label', 'created', 'last_used', 'revoked'];

function makeClient(rows: string[][]): SheetsClient {
  return {
    getValues: vi.fn(async () => rows),
    batchUpdateValues: vi.fn(async () => {}),
    appendValues: vi.fn(async () => {}),
    ensureSheetWithHeader: vi.fn(async () => {}),
  };
}

describe('resolveDevice', () => {
  it('returns null for an empty/missing token', async () => {
    const client = makeClient([HEADER]);
    expect(await resolveDevice(client, undefined)).toBeNull();
    expect(await resolveDevice(client, '')).toBeNull();
  });

  it('returns the owning user for a matching, active token', async () => {
    const token = 'abc123';
    const hash = sha256Hex(token);
    const client = makeClient([
      HEADER,
      [hash, '八木', '', '2026/01/01 00:00:00', '2026/01/01', 'FALSE'],
    ]);
    expect(await resolveDevice(client, token)).toEqual({ user: '八木' });
  });

  it('returns { user: "" } for a shared device', async () => {
    const token = 'shared-token';
    const hash = sha256Hex(token);
    const client = makeClient([
      HEADER,
      [hash, '', '', '2026/01/01 00:00:00', '2026/01/01', 'FALSE'],
    ]);
    expect(await resolveDevice(client, token)).toEqual({ user: '' });
  });

  it('returns null for a revoked device (TRUE/1/はい all count)', async () => {
    const token = 'revoked-token';
    const hash = sha256Hex(token);
    for (const revokedValue of ['TRUE', '1', 'はい', 'true']) {
      const client = makeClient([
        HEADER,
        [hash, '八木', '', '2026/01/01 00:00:00', '2026/01/01', revokedValue],
      ]);
      expect(await resolveDevice(client, token)).toBeNull();
    }
  });

  it('returns null when no row matches the token hash', async () => {
    const client = makeClient([
      HEADER,
      [sha256Hex('other-token'), '八木', '', '', '', 'FALSE'],
    ]);
    expect(await resolveDevice(client, 'unknown-token')).toBeNull();
  });

  it("updates last_used only when today's date isn't already recorded", async () => {
    const token = 'abc123';
    const hash = sha256Hex(token);
    const today = formatDateJST(new Date());

    const staleClient = makeClient([
      HEADER,
      [hash, '八木', '', '2020/01/01 00:00:00', '2020/01/01', 'FALSE'],
    ]);
    await resolveDevice(staleClient, token);
    expect(staleClient.batchUpdateValues).toHaveBeenCalledTimes(1);

    const freshClient = makeClient([
      HEADER,
      [hash, '八木', '', '2020/01/01 00:00:00', today, 'FALSE'],
    ]);
    await resolveDevice(freshClient, token);
    expect(freshClient.batchUpdateValues).not.toHaveBeenCalled();
  });
});

describe('appendDevice', () => {
  it('appends a row with the hash, owner, label, created timestamp, blank last_used, and FALSE revoked', async () => {
    const client = makeClient([HEADER]);
    await appendDevice(client, {
      tokenHash: 'hash123',
      user: '八木',
      label: 'iPhone',
      createdAt: new Date('2026-01-01T00:00:00Z'),
    });

    expect(client.appendValues).toHaveBeenCalledTimes(1);
    const [range, rows] = (client.appendValues as any).mock.calls[0];
    expect(range).toContain('devices');
    expect(rows[0][0]).toBe('hash123');
    expect(rows[0][1]).toBe('八木');
    expect(rows[0][2]).toBe('iPhone');
    expect(rows[0][4]).toBe('');
    expect(rows[0][5]).toBe('FALSE');
  });
});

describe('setDeviceOwner', () => {
  it('updates the user column for the matching row and returns true', async () => {
    const hash = 'hash123';
    const client = makeClient([
      HEADER,
      [hash, '八木', '', '', '', 'FALSE'],
    ]);
    const result = await setDeviceOwner(client, hash, '大滝');
    expect(result).toBe(true);
    expect(client.batchUpdateValues).toHaveBeenCalledWith([
      { range: 'devices!B2', values: [['大滝']] },
    ]);
  });

  it('returns false when the token is not registered', async () => {
    const client = makeClient([HEADER]);
    expect(await setDeviceOwner(client, 'missing', '大滝')).toBe(false);
  });
});
