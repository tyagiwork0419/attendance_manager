import { describe, expect, it, vi } from 'vitest';
import type { SheetsClient } from '../src/google/sheets.js';
import {
  isAdmin,
  loadUserRecord,
  loadUsers,
  listUserNames,
  writeUserPassword,
} from '../src/users.js';

function makeClient(rows: string[][]): SheetsClient {
  return {
    getValues: vi.fn(async () => rows),
    batchUpdateValues: vi.fn(async () => {}),
    appendValues: vi.fn(async () => {}),
    ensureSheetWithHeader: vi.fn(async () => {}),
    listSheetNames: vi.fn(async () => []),
    ensureSheetCopiedFrom: vi.fn(async () => {}),
  };
}

describe('loadUsers', () => {
  it('resolves columns by header name regardless of order', async () => {
    const client = makeClient([
      ['role', 'id', 'password', 'name'],
      ['admin', '1', '111111', '八木'],
      ['', '2', '222222', '大滝'],
    ]);
    const users = await loadUsers(client);
    expect(users).toEqual([
      { name: '八木', password: '111111', role: 'admin' },
      { name: '大滝', password: '222222', role: '' },
    ]);
  });

  it('skips rows with an empty name', async () => {
    const client = makeClient([
      ['name', 'password'],
      ['', '1234'],
      ['八木', '111111'],
    ]);
    const users = await loadUsers(client);
    expect(users).toEqual([{ name: '八木', password: '111111', role: '' }]);
  });

  it('treats a missing role column as empty role for every user', async () => {
    const client = makeClient([
      ['name', 'password'],
      ['八木', '111111'],
    ]);
    const users = await loadUsers(client);
    expect(users[0]?.role).toBe('');
  });

  it('returns an empty list when the sheet has only a header row', async () => {
    const client = makeClient([['name', 'password']]);
    expect(await loadUsers(client)).toEqual([]);
  });

  it('throws when the sheet is missing required columns', async () => {
    const client = makeClient([
      ['id', 'foo'],
      ['1', 'x'],
    ]);
    await expect(loadUsers(client)).rejects.toThrow(/name.*password|password.*name/i);
  });

  it('lowercases and trims the role value', async () => {
    const client = makeClient([
      ['name', 'password', 'role'],
      ['八木', '1', ' Admin '],
    ]);
    const users = await loadUsers(client);
    expect(users[0]?.role).toBe('admin');
  });
});

describe('isAdmin', () => {
  it('is true only when role is exactly "admin"', () => {
    expect(isAdmin({ name: 'a', password: 'p', role: 'admin' })).toBe(true);
    expect(isAdmin({ name: 'a', password: 'p', role: 'user' })).toBe(false);
    expect(isAdmin({ name: 'a', password: 'p', role: '' })).toBe(false);
    expect(isAdmin(null)).toBe(false);
  });
});

describe('loadUserRecord', () => {
  it('finds a user by exact name match', async () => {
    const client = makeClient([
      ['name', 'password'],
      ['八木', '111111'],
    ]);
    expect(await loadUserRecord(client, '八木')).toEqual({
      name: '八木',
      password: '111111',
      role: '',
    });
  });

  it('returns null when no user matches', async () => {
    const client = makeClient([
      ['name', 'password'],
      ['八木', '111111'],
    ]);
    expect(await loadUserRecord(client, '大滝')).toBeNull();
  });
});

describe('listUserNames', () => {
  it('returns names only, no passwords', async () => {
    const client = makeClient([
      ['name', 'password'],
      ['八木', '111111'],
      ['大滝', '222222'],
    ]);
    expect(await listUserNames(client)).toEqual(['八木', '大滝']);
  });
});

describe('writeUserPassword', () => {
  it("updates the matching user's password cell", async () => {
    const client = makeClient([
      ['name', 'password'],
      ['八木', '111111'],
      ['大滝', '222222'],
    ]);
    await writeUserPassword(client, '大滝', '0123456');
    expect(client.batchUpdateValues).toHaveBeenCalledWith([
      { range: 'users!B3', values: [['0123456']] },
    ]);
  });

  it('resolves the password column by header name, not a fixed position', async () => {
    const client = makeClient([
      ['password', 'name'],
      ['111111', '八木'],
    ]);
    await writeUserPassword(client, '八木', 'newpass');
    expect(client.batchUpdateValues).toHaveBeenCalledWith([
      { range: 'users!A2', values: [['newpass']] },
    ]);
  });

  it('throws when no user matches the given name', async () => {
    const client = makeClient([
      ['name', 'password'],
      ['八木', '111111'],
    ]);
    await expect(writeUserPassword(client, '大滝', 'x')).rejects.toThrow(/大滝/);
  });
});
