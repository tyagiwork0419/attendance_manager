import { describe, expect, it, vi } from 'vitest';
import type { SheetsClient } from '../src/google/sheets.js';
import type { DriveClient } from '../src/google/drive.js';
import {
  insertRow,
  isMonthSheetName,
  listYears,
  resolveMonthSheetClient,
  resolveYearSpreadsheetId,
  selectByDate,
  selectByName,
  updateStatusById,
} from '../src/attendance.js';

const HEADER = ['id', 'name', 'type', 'dateTime', 'status', 'remarks'];

function makeSheetsClient(rows: string[][]): SheetsClient {
  return {
    getValues: vi.fn(async () => rows),
    batchUpdateValues: vi.fn(async () => {}),
    appendValues: vi.fn(async () => {}),
    ensureSheetWithHeader: vi.fn(async () => {}),
    listSheetNames: vi.fn(async () => []),
    ensureSheetCopiedFrom: vi.fn(async () => {}),
  };
}

function makeDriveClient(overrides: Partial<DriveClient> = {}): DriveClient {
  return {
    findFileInFolder: vi.fn(async () => null),
    listFileNamesInFolder: vi.fn(async () => []),
    copyFile: vi.fn(async () => 'new-file-id'),
    ...overrides,
  };
}

const ROWS = [
  HEADER,
  ['1', '八木', '出勤', '2026/08/31 09:00:00', 'normal', ''],
  ['2', '八木', '退勤', '2026/08/31 18:00:00', 'normal', ''],
  ['3', '大滝', '出勤', '2026/08/31 09:05:00', 'normal', ''],
  ['4', '八木', '出勤', '2026/09/01 09:00:00', 'normal', ''],
  ['5', '八木', '退勤', '2026/08/30 18:00:00', 'deleted', ''],
];

describe('selectByDate', () => {
  it('returns only records for the given day, excluding deleted ones', async () => {
    const client = makeSheetsClient(ROWS);
    const results = await selectByDate(client, '8月', new Date('2026-08-31T00:00:00Z'));
    expect(results.map((r) => r.id).sort()).toEqual([1, 2, 3]);
  });

  it('returns an empty list for a day with no records', async () => {
    const client = makeSheetsClient(ROWS);
    const results = await selectByDate(client, '8月', new Date('2026-01-01T00:00:00Z'));
    expect(results).toEqual([]);
  });
});

describe('selectByName', () => {
  it('returns only that name\'s records, excluding deleted ones', async () => {
    const client = makeSheetsClient(ROWS);
    const results = await selectByName(client, '8月', '八木');
    expect(results.map((r) => r.id).sort()).toEqual([1, 2, 4]);
  });
});

describe('insertRow', () => {
  it('assigns the next id as (last row id + 1) and appends by header position', async () => {
    const client = makeSheetsClient(ROWS);
    await insertRow(client, '8月', {
      name: '大滝',
      type: '退勤',
      dateTime: '2026/08/31 18:10:00',
      status: 'normal',
      remarks: '',
    });

    expect(client.appendValues).toHaveBeenCalledTimes(1);
    const [sheetName, rows] = (client.appendValues as any).mock.calls[0];
    expect(sheetName).toBe('8月');
    expect(rows[0]).toEqual(['6', '大滝', '退勤', '2026/08/31 18:10:00', 'normal', '']);
  });

  it('starts at id 1 for an empty sheet', async () => {
    const client = makeSheetsClient([HEADER]);
    await insertRow(client, '8月', {
      name: '八木',
      type: '出勤',
      dateTime: '2026/08/01 09:00:00',
      status: 'normal',
      remarks: '',
    });
    const [, rows] = (client.appendValues as any).mock.calls[0];
    expect(rows[0][0]).toBe('1');
  });

  it('places values by header name, not by a fixed column order', async () => {
    const reordered = [
      ['name', 'id', 'dateTime', 'type', 'remarks', 'status'],
      ['八木', '1', '2026/08/01 09:00:00', '出勤', '', 'normal'],
    ];
    const client = makeSheetsClient(reordered);
    await insertRow(client, '8月', {
      name: '大滝',
      type: '退勤',
      dateTime: '2026/08/01 18:00:00',
      status: 'normal',
      remarks: 'メモ',
    });
    const [, rows] = (client.appendValues as any).mock.calls[0];
    // name, id, dateTime, type, remarks, status の順で入っているはず
    expect(rows[0]).toEqual(['大滝', '2', '2026/08/01 18:00:00', '退勤', 'メモ', 'normal']);
  });
});

describe('updateStatusById', () => {
  it('updates only the status cell of the matching row', async () => {
    const client = makeSheetsClient(ROWS);
    await updateStatusById(client, '8月', 2, 'deleted');
    expect(client.batchUpdateValues).toHaveBeenCalledWith([
      { range: '8月!E3', values: [['deleted']] },
    ]);
  });

  it('does nothing when no row matches the id', async () => {
    const client = makeSheetsClient(ROWS);
    await updateStatusById(client, '8月', 999, 'deleted');
    expect(client.batchUpdateValues).not.toHaveBeenCalled();
  });
});

describe('isMonthSheetName', () => {
  it('accepts 1月 through 12月 and rejects everything else', () => {
    expect(isMonthSheetName('1月')).toBe(true);
    expect(isMonthSheetName('12月')).toBe(true);
    expect(isMonthSheetName('13月')).toBe(false);
    expect(isMonthSheetName('0月')).toBe(false);
    expect(isMonthSheetName('template')).toBe(false);
  });
});

describe('listYears', () => {
  it('extracts, dedupes, and sorts years from file names like "2026年"', async () => {
    const drive = makeDriveClient({
      listFileNamesInFolder: vi.fn(async () => [
        '2025年', 'template', '2026年', '2024年', '2025年', 'not a year',
      ]),
    });
    expect(await listYears(drive)).toEqual([2024, 2025, 2026]);
  });
});

describe('resolveYearSpreadsheetId', () => {
  it('returns the existing file id without copying when found', async () => {
    const drive = makeDriveClient({
      findFileInFolder: vi.fn(async () => 'existing-id'),
    });
    expect(await resolveYearSpreadsheetId(drive, '2026年')).toBe('existing-id');
    expect(drive.copyFile).not.toHaveBeenCalled();
  });

  it('copies the template file when the year file is missing', async () => {
    const drive = makeDriveClient({
      findFileInFolder: vi.fn(async () => null),
      copyFile: vi.fn(async () => 'new-year-file-id'),
    });
    expect(await resolveYearSpreadsheetId(drive, '2027年')).toBe('new-year-file-id');
    expect(drive.copyFile).toHaveBeenCalledWith(expect.any(String), '2027年');
  });
});

describe('resolveMonthSheetClient', () => {
  it('resolves the year file then ensures the month sheet exists before returning a client', async () => {
    const drive = makeDriveClient({ findFileInFolder: vi.fn(async () => 'year-id') });
    const sheetsClient = makeSheetsClient([HEADER]);
    const factory = vi.fn(() => sheetsClient);

    const client = await resolveMonthSheetClient(drive, factory, '2026年', '8月');

    expect(factory).toHaveBeenCalledWith('year-id');
    expect(sheetsClient.ensureSheetCopiedFrom).toHaveBeenCalledWith('template', '8月');
    expect(client).toBe(sheetsClient);
  });
});
