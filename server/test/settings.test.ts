import { describe, expect, it, vi } from 'vitest';
import type { SheetsClient } from '../src/google/sheets.js';
import {
  SETTINGS_DEFAULTS,
  loadSettings,
  saveSettings,
  validateSettings,
} from '../src/settings.js';

function makeClient(rows: string[][]): SheetsClient {
  return {
    getValues: vi.fn(async () => rows),
    batchUpdateValues: vi.fn(async () => {}),
    appendValues: vi.fn(async () => {}),
    ensureSheetWithHeader: vi.fn(async () => {}),
  };
}

describe('loadSettings', () => {
  it('returns all defaults when the sheet is empty', async () => {
    const client = makeClient([]);
    expect(await loadSettings(client)).toEqual(SETTINGS_DEFAULTS);
  });

  it('overrides defaults with stored values, ignoring the header row', async () => {
    const client = makeClient([
      ['key', 'value'],
      ['standardWorkHoursPerDay', '7.5'],
      ['paidHolidayGrantDays', '12'],
    ]);
    const settings = await loadSettings(client);
    expect(settings.standardWorkHoursPerDay).toBe(7.5);
    expect(settings.paidHolidayGrantDays).toBe(12);
    // Untouched keys keep their default.
    expect(settings.minPasswordLength).toBe(SETTINGS_DEFAULTS.minPasswordLength);
  });

  it('falls back to the default for a row with unparsable JSON', async () => {
    const client = makeClient([['standardWorkHoursPerDay', 'not-json{']]);
    const settings = await loadSettings(client);
    expect(settings.standardWorkHoursPerDay).toBe(SETTINGS_DEFAULTS.standardWorkHoursPerDay);
  });

  it('ignores unknown keys stored in the sheet', async () => {
    const client = makeClient([['someOldRemovedSetting', '123']]);
    const settings = await loadSettings(client);
    expect(settings).toEqual(SETTINGS_DEFAULTS);
  });
});

describe('validateSettings', () => {
  const current = SETTINGS_DEFAULTS;

  it('keeps unspecified fields at their current value', () => {
    const result = validateSettings({}, current);
    expect(result).toEqual(current);
  });

  it('clamps standardWorkHoursPerDay to [0.5, 24]', () => {
    expect(validateSettings({ standardWorkHoursPerDay: 87.5 }, current).standardWorkHoursPerDay).toBe(
      24
    );
    expect(validateSettings({ standardWorkHoursPerDay: 0 }, current).standardWorkHoursPerDay).toBe(
      0.5
    );
    expect(validateSettings({ standardWorkHoursPerDay: 7.5 }, current).standardWorkHoursPerDay).toBe(
      7.5
    );
  });

  it('rounds and clamps minPasswordLength to [1, 100]', () => {
    expect(validateSettings({ minPasswordLength: 0 }, current).minPasswordLength).toBe(1);
    expect(validateSettings({ minPasswordLength: 6.4 }, current).minPasswordLength).toBe(6);
    expect(validateSettings({ minPasswordLength: 1000 }, current).minPasswordLength).toBe(100);
  });

  it('rounds and clamps sessionTtlSeconds to [60, 21600]', () => {
    expect(validateSettings({ sessionTtlSeconds: 10 }, current).sessionTtlSeconds).toBe(60);
    expect(validateSettings({ sessionTtlSeconds: 999999 }, current).sessionTtlSeconds).toBe(
      21600
    );
  });

  it('trims companyHolidayCalendarId when provided', () => {
    expect(
      validateSettings({ companyHolidayCalendarId: '  foo@example.com  ' }, current)
        .companyHolidayCalendarId
    ).toBe('foo@example.com');
  });

  it('clamps paidHolidayGrantMonth to [1, 12] and paidHolidayGrantDay to [1, 31]', () => {
    expect(validateSettings({ paidHolidayGrantMonth: 13 }, current).paidHolidayGrantMonth).toBe(
      12
    );
    expect(validateSettings({ paidHolidayGrantMonth: 0 }, current).paidHolidayGrantMonth).toBe(1);
    expect(validateSettings({ paidHolidayGrantDay: 40 }, current).paidHolidayGrantDay).toBe(31);
  });

  it('falls back to the current value for non-numeric input', () => {
    expect(
      validateSettings({ standardWorkHoursPerDay: 'not-a-number' }, current)
        .standardWorkHoursPerDay
    ).toBe(current.standardWorkHoursPerDay);
  });
});

describe('saveSettings', () => {
  it('updates existing rows in place and appends missing keys', async () => {
    const client = makeClient([
      ['key', 'value'],
      ['standardWorkHoursPerDay', '8'],
    ]);

    await saveSettings(client, { ...SETTINGS_DEFAULTS, standardWorkHoursPerDay: 7.5 });

    expect(client.batchUpdateValues).toHaveBeenCalledTimes(1);
    const [updates] = (client.batchUpdateValues as any).mock.calls[0];
    const workHoursUpdate = updates.find((u: any) => u.range === 'settings!B2');
    expect(workHoursUpdate.values).toEqual([['7.5']]);

    expect(client.appendValues).toHaveBeenCalledTimes(1);
    const [range, appendedRows] = (client.appendValues as any).mock.calls[0];
    expect(range).toBe('settings!A:B');
    // Every default key except the one already present should be appended.
    expect(appendedRows.length).toBe(Object.keys(SETTINGS_DEFAULTS).length - 1);
  });
});
