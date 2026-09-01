import { describe, expect, it, vi } from 'vitest';
import type { SheetsClient } from '../src/google/sheets.js';
import { changePassword } from '../src/actions/changePassword.js';

function makeClient(rows: string[][], settingsRows: string[][] = []): SheetsClient {
  return {
    getValues: vi.fn(async (range: string) => {
      if (range.startsWith('settings')) return settingsRows;
      return rows;
    }),
    batchUpdateValues: vi.fn(async () => {}),
    appendValues: vi.fn(async () => {}),
    ensureSheetWithHeader: vi.fn(async () => {}),
  };
}

const USERS = [
  ['name', 'password'],
  ['八木', '111111'],
];

describe('changePassword', () => {
  it('updates the password when the current password is correct and the new one is valid', async () => {
    const client = makeClient(USERS);
    const result = await changePassword(client, {
      name: '八木',
      currentPassword: '111111',
      newPassword: '222222',
    });

    expect(result).toEqual({ ok: true, result: { name: '八木' } });
    expect(client.batchUpdateValues).toHaveBeenCalledWith([
      { range: 'users!B2', values: [['222222']] },
    ]);
  });

  it('rejects a wrong current password', async () => {
    const client = makeClient(USERS);
    const result = await changePassword(client, {
      name: '八木',
      currentPassword: 'wrong',
      newPassword: '222222',
    });
    expect(result).toEqual({
      ok: false,
      error: '現在のパスワードが違います',
      code: 'invalid_credentials',
    });
    expect(client.batchUpdateValues).not.toHaveBeenCalled();
  });

  it('rejects a new password shorter than the configured minimum', async () => {
    const client = makeClient(USERS, [['minPasswordLength', '8']]);
    const result = await changePassword(client, {
      name: '八木',
      currentPassword: '111111',
      newPassword: '1234567',
    });
    expect(result).toEqual({
      ok: false,
      error: '新しいパスワードは8文字以上にしてください',
      code: 'weak_password',
    });
  });

  it('rejects a new password identical to the current one', async () => {
    const client = makeClient(USERS);
    const result = await changePassword(client, {
      name: '八木',
      currentPassword: '111111',
      newPassword: '111111',
    });
    expect(result).toEqual({
      ok: false,
      error: '現在のパスワードと同じです',
      code: 'weak_password',
    });
  });

  it('rejects a missing name or current password up front', async () => {
    const client = makeClient(USERS);
    const result = await changePassword(client, { newPassword: 'whatever' });
    expect(result).toEqual({
      ok: false,
      error: '名前と現在のパスワードを入力してください',
      code: 'invalid_credentials',
    });
    expect(client.getValues).not.toHaveBeenCalled();
  });
});
