import { describe, expect, it, vi } from 'vitest';
import type { SheetsClient } from '../src/google/sheets.js';
import { updateDeviceOwner } from '../src/actions/updateDeviceOwner.js';
import { sha256Hex } from '../src/crypto.js';

const DEVICE_HEADER = ['token_hash', 'user', 'label', 'created', 'last_used', 'revoked'];

function makeClient(userRows: string[][], deviceRows: string[][]): SheetsClient {
  return {
    getValues: vi.fn(async (range: string) => {
      if (range === 'devices') return deviceRows;
      return userRows;
    }),
    batchUpdateValues: vi.fn(async () => {}),
    appendValues: vi.fn(async () => {}),
    ensureSheetWithHeader: vi.fn(async () => {}),
  };
}

const USERS = [
  ['name', 'password', 'role'],
  ['八木', '111111', 'admin'],
  ['大滝', '222222', ''],
];

describe('updateDeviceOwner', () => {
  it('switches a device to personal ownership for anyone with the right password', async () => {
    const token = 'abc';
    const hash = sha256Hex(token);
    const client = makeClient(USERS, [
      DEVICE_HEADER,
      [hash, '', '', '', '', 'FALSE'],
    ]);

    const result = await updateDeviceOwner(client, {
      name: '大滝',
      password: '222222',
      shared: false,
      deviceToken: token,
    });

    expect(result).toEqual({ ok: true, result: { user: '大滝', shared: false } });
    expect(client.batchUpdateValues).toHaveBeenCalledWith([
      { range: 'devices!B2', values: [['大滝']] },
    ]);
  });

  it('requires admin to switch a device to shared', async () => {
    const token = 'abc';
    const hash = sha256Hex(token);
    const client = makeClient(USERS, [
      DEVICE_HEADER,
      [hash, '大滝', '', '', '', 'FALSE'],
    ]);

    const result = await updateDeviceOwner(client, {
      name: '大滝',
      password: '222222',
      shared: true,
      deviceToken: token,
    });

    expect(result).toEqual({
      ok: false,
      error: '共有端末への変更は管理者のみ行えます',
      code: 'admin_required',
    });
    expect(client.batchUpdateValues).not.toHaveBeenCalled();
  });

  it('allows an admin to switch a device to shared', async () => {
    const token = 'abc';
    const hash = sha256Hex(token);
    const client = makeClient(USERS, [
      DEVICE_HEADER,
      [hash, '大滝', '', '', '', 'FALSE'],
    ]);

    const result = await updateDeviceOwner(client, {
      name: '八木',
      password: '111111',
      shared: true,
      deviceToken: token,
    });

    expect(result).toEqual({ ok: true, result: { user: '', shared: true } });
  });

  it('returns device_unauthorized when the device token does not match any row', async () => {
    const client = makeClient(USERS, [DEVICE_HEADER]);
    const result = await updateDeviceOwner(client, {
      name: '大滝',
      password: '222222',
      shared: false,
      deviceToken: 'unknown',
    });
    expect(result).toEqual({
      ok: false,
      error: 'この端末は登録されていません',
      code: 'device_unauthorized',
    });
  });

  it('rejects an incorrect password before touching the devices sheet', async () => {
    const client = makeClient(USERS, [DEVICE_HEADER]);
    const result = await updateDeviceOwner(client, {
      name: '大滝',
      password: 'wrong',
      shared: false,
      deviceToken: 'whatever',
    });
    expect(result).toEqual({
      ok: false,
      error: '名前またはパスワードが違います',
      code: 'invalid_credentials',
    });
  });
});
