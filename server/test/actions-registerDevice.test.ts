import { describe, expect, it, vi } from 'vitest';
import type { SheetsClient } from '../src/google/sheets.js';
import { registerDevice } from '../src/actions/registerDevice.js';
import { sha256Hex } from '../src/crypto.js';

function makeClient(userRows: string[][]): SheetsClient {
  return {
    getValues: vi.fn(async () => userRows),
    batchUpdateValues: vi.fn(async () => {}),
    appendValues: vi.fn(async () => {}),
    ensureSheetWithHeader: vi.fn(async () => {}),
  };
}

const ADMIN_USERS = [
  ['name', 'password', 'role'],
  ['八木', '111111', 'admin'],
  ['大滝', '222222', ''],
];

describe('registerDevice', () => {
  it('registers a personal device for correct credentials', async () => {
    const client = makeClient(ADMIN_USERS);
    const result = await registerDevice(client, {
      name: '大滝',
      password: '222222',
      label: 'iPhone',
      shared: false,
    });

    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.result.user).toBe('大滝');
    expect(result.result.shared).toBe(false);
    expect(result.result.token).toBeTruthy();

    expect(client.appendValues).toHaveBeenCalledTimes(1);
    const [, rows] = (client.appendValues as any).mock.calls[0];
    expect(rows[0][0]).toBe(sha256Hex(result.result.token));
    expect(rows[0][1]).toBe('大滝');
    expect(rows[0][2]).toBe('iPhone');
  });

  it('allows an admin to register a shared device', async () => {
    const client = makeClient(ADMIN_USERS);
    const result = await registerDevice(client, {
      name: '八木',
      password: '111111',
      label: '',
      shared: true,
    });
    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.result.user).toBe('');
    expect(result.result.shared).toBe(true);
  });

  it('rejects a non-admin trying to register a shared device', async () => {
    const client = makeClient(ADMIN_USERS);
    const result = await registerDevice(client, {
      name: '大滝',
      password: '222222',
      label: '',
      shared: true,
    });
    expect(result).toEqual({
      ok: false,
      error: '共有端末への登録は管理者のみ行えます',
      code: 'admin_required',
    });
    expect(client.appendValues).not.toHaveBeenCalled();
  });

  it('rejects an incorrect password', async () => {
    const client = makeClient(ADMIN_USERS);
    const result = await registerDevice(client, {
      name: '大滝',
      password: 'wrong',
      label: '',
      shared: false,
    });
    expect(result).toEqual({
      ok: false,
      error: '名前またはパスワードが違います',
      code: 'invalid_credentials',
    });
  });
});
