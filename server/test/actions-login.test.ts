import { describe, expect, it, vi } from 'vitest';
import type { SheetsClient } from '../src/google/sheets.js';
import { login } from '../src/actions/login.js';
import { verifySessionToken } from '../src/crypto.js';

function makeClient(rows: string[][]): SheetsClient {
  return {
    getValues: vi.fn(async (range: string) => {
      if (range.startsWith('settings')) return [];
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

describe('login', () => {
  const secret = 'test-secret';

  it('issues a valid session token for correct credentials', async () => {
    const client = makeClient(USERS);
    const result = await login(client, secret, { name: '八木', password: '111111' });

    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.result.name).toBe('八木');
    expect(result.result.expiresIn).toBe(21600);
    expect(verifySessionToken(result.result.token, secret)).toEqual({ name: '八木' });
  });

  it('rejects a wrong password with invalid_credentials', async () => {
    const client = makeClient(USERS);
    const result = await login(client, secret, { name: '八木', password: 'wrong' });
    expect(result).toEqual({
      ok: false,
      error: '名前またはパスワードが違います',
      code: 'invalid_credentials',
    });
  });

  it('rejects a non-existent user with the same error as a wrong password', async () => {
    const client = makeClient(USERS);
    const result = await login(client, secret, { name: '存在しない', password: 'x' });
    expect(result).toEqual({
      ok: false,
      error: '名前またはパスワードが違います',
      code: 'invalid_credentials',
    });
  });

  it('rejects a missing name or password before touching the sheet', async () => {
    const client = makeClient(USERS);
    const result = await login(client, secret, { name: '', password: '' });
    expect(result).toEqual({
      ok: false,
      error: '名前とパスワードを入力してください',
      code: 'invalid_credentials',
    });
    expect(client.getValues).not.toHaveBeenCalled();
  });
});
