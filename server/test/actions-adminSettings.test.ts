import { describe, expect, it, vi } from 'vitest';
import type { SheetsClient } from '../src/google/sheets.js';
import { getAdminSettings, updateSettingsAction } from '../src/actions/adminSettings.js';
import { SETTINGS_DEFAULTS } from '../src/settings.js';

/**
 * settings シートの読み書きが実際に反映される、状態を持つフェイク。
 * updateSettingsAction は保存直後に読み直して返すため、静的なモックでは
 * 「保存前の値のまま」に見えてしまい正しく検証できない。
 */
function makeClient(userRows: string[][], initialSettingsRows: string[][] = []): SheetsClient {
  const settingsRows = initialSettingsRows.map((row) => [...row]);

  return {
    getValues: vi.fn(async (range: string) => {
      if (range.startsWith('settings')) return settingsRows.map((row) => [...row]);
      return userRows;
    }),
    batchUpdateValues: vi.fn(async (updates) => {
      for (const update of updates) {
        const match = /^settings!B(\d+)$/.exec(update.range);
        if (!match) continue;
        const rowIndex = Number(match[1]) - 1;
        const value = String((update.values[0] as unknown[])[0]);
        const existing = settingsRows[rowIndex] ?? ['', ''];
        settingsRows[rowIndex] = [existing[0] ?? '', value];
      }
    }),
    appendValues: vi.fn(async (range: string, values: unknown[][]) => {
      if (range.startsWith('settings')) {
        for (const row of values) {
          settingsRows.push(row.map((v) => String(v)));
        }
      }
    }),
    ensureSheetWithHeader: vi.fn(async () => {}),
    listSheetNames: vi.fn(async () => []),
    ensureSheetCopiedFrom: vi.fn(async () => {}),
  };
}

const USERS = [
  ['name', 'password', 'role'],
  ['八木', '111111', 'admin'],
  ['大滝', '222222', ''],
];

describe('getAdminSettings', () => {
  it('returns current settings for an admin with the right password', async () => {
    const client = makeClient(USERS);
    const result = await getAdminSettings(client, { name: '八木', password: '111111' });
    expect(result).toEqual({ ok: true, result: SETTINGS_DEFAULTS });
  });

  it('rejects a non-admin even with the correct password', async () => {
    const client = makeClient(USERS);
    const result = await getAdminSettings(client, { name: '大滝', password: '222222' });
    expect(result).toEqual({
      ok: false,
      error: '管理者のみ利用できます',
      code: 'admin_required',
    });
  });

  it('rejects a wrong password before checking admin status', async () => {
    const client = makeClient(USERS);
    const result = await getAdminSettings(client, { name: '八木', password: 'wrong' });
    expect(result).toEqual({
      ok: false,
      error: '名前またはパスワードが違います',
      code: 'invalid_credentials',
    });
  });
});

describe('updateSettingsAction', () => {
  it('validates, saves, and returns the updated settings for an admin', async () => {
    const client = makeClient(USERS, [
      ['key', 'value'],
      ['standardWorkHoursPerDay', '8'],
    ]);
    const result = await updateSettingsAction(client, {
      name: '八木',
      password: '111111',
      settings: { standardWorkHoursPerDay: 7.5 },
    });

    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.result.standardWorkHoursPerDay).toBe(7.5);
    expect(client.batchUpdateValues).toHaveBeenCalled();
  });

  it('clamps out-of-range input rather than rejecting it', async () => {
    const client = makeClient(USERS, []);
    const result = await updateSettingsAction(client, {
      name: '八木',
      password: '111111',
      settings: { standardWorkHoursPerDay: 87.5 },
    });
    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.result.standardWorkHoursPerDay).toBe(24);
  });

  it('rejects a non-admin trying to save', async () => {
    const client = makeClient(USERS, []);
    const result = await updateSettingsAction(client, {
      name: '大滝',
      password: '222222',
      settings: { standardWorkHoursPerDay: 7.5 },
    });
    expect(result).toEqual({
      ok: false,
      error: '管理者のみ設定を変更できます',
      code: 'admin_required',
    });
    expect(client.batchUpdateValues).not.toHaveBeenCalled();
  });
});
