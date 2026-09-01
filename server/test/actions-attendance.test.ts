import { describe, expect, it, vi } from 'vitest';
import type { SheetsClient } from '../src/google/sheets.js';
import type { DriveClient } from '../src/google/drive.js';
import {
  insertRowsAction,
  selectByDateAction,
  selectByNameAction,
  selectByNameForYearAction,
  updateByIdAction,
} from '../src/actions/attendanceActions.js';

const HEADER = ['id', 'name', 'type', 'dateTime', 'status', 'remarks'];

function makeSheetsClient(rows: string[][], sheetNames: string[] = ['8月']): SheetsClient {
  return {
    getValues: vi.fn(async () => rows),
    batchUpdateValues: vi.fn(async () => {}),
    appendValues: vi.fn(async () => {}),
    ensureSheetWithHeader: vi.fn(async () => {}),
    listSheetNames: vi.fn(async () => sheetNames),
    ensureSheetCopiedFrom: vi.fn(async () => {}),
  };
}

function makeDriveClient(fileId = 'year-file-id'): DriveClient {
  return {
    findFileInFolder: vi.fn(async () => fileId),
    listFileNamesInFolder: vi.fn(async () => []),
    copyFile: vi.fn(async () => fileId),
  };
}

const ROWS = [
  HEADER,
  ['1', '八木', '出勤', '2026/08/31 09:00:00', 'normal', ''],
  ['2', '八木', '退勤', '2026/08/31 18:00:00', 'normal', ''],
];

describe('selectByDateAction', () => {
  it('resolves the year/month sheet then filters by date', async () => {
    const client = makeSheetsClient(ROWS);
    const factory = vi.fn(() => client);
    const drive = makeDriveClient();

    const results = await selectByDateAction(drive, factory, {
      fileName: '2026年',
      sheetName: '8月',
      dateTime: '2026/08/31 00:00:00',
    });

    expect(results).toHaveLength(2);
    expect(client.ensureSheetCopiedFrom).toHaveBeenCalledWith('template', '8月');
  });
});

describe('selectByNameAction', () => {
  it('resolves the year/month sheet then filters by name', async () => {
    const client = makeSheetsClient(ROWS);
    const factory = vi.fn(() => client);
    const drive = makeDriveClient();

    const results = await selectByNameAction(drive, factory, {
      fileName: '2026年',
      sheetName: '8月',
      name: '八木',
    });

    expect(results).toHaveLength(2);
  });
});

describe('selectByNameForYearAction', () => {
  it('reads every month sheet, skipping non-month tabs, without creating missing ones', async () => {
    const augustClient = makeSheetsClient(ROWS, ['8月', 'template', '9月']);
    // getValues returns the same ROWS regardless of which sheet name is requested here,
    // since this stub represents a single spreadsheet with (for this test) identical data
    // on every tab; what matters is that both real month tabs get queried.
    const factory = vi.fn(() => augustClient);
    const drive = makeDriveClient();

    const results = await selectByNameForYearAction(drive, factory, {
      fileName: '2026年',
      name: '八木',
    });

    // 8月 と 9月 の両方から2件ずつ、templateは読み飛ばされる。
    expect(results).toHaveLength(4);
    expect(augustClient.ensureSheetCopiedFrom).not.toHaveBeenCalled();
    expect(augustClient.getValues).toHaveBeenCalledWith('8月');
    expect(augustClient.getValues).toHaveBeenCalledWith('9月');
    expect(augustClient.getValues).not.toHaveBeenCalledWith('template');
  });
});

describe('insertRowsAction', () => {
  it('inserts the punch then returns the full day (not just the new row)', async () => {
    const client = makeSheetsClient(ROWS);
    const factory = vi.fn(() => client);
    const drive = makeDriveClient();

    const results = await insertRowsAction(drive, factory, {
      fileName: '2026年',
      sheetName: '8月',
      postData: {
        name: '大滝',
        type: '出勤',
        dateTime: '2026/08/31 09:10:00',
        status: 'normal',
        remarks: '',
      },
    });

    expect(client.appendValues).toHaveBeenCalledTimes(1);
    // selectByDate is re-run against the sheet after the insert, so the mock (which
    // always returns the static ROWS) reports the original 2 rows; the important
    // behavior under test is that it re-queries by date rather than returning just
    // the inserted row.
    expect(results).toHaveLength(2);
  });
});

describe('updateByIdAction', () => {
  it('updates status by id then returns the full day', async () => {
    const client = makeSheetsClient(ROWS);
    const factory = vi.fn(() => client);
    const drive = makeDriveClient();

    const results = await updateByIdAction(drive, factory, {
      fileName: '2026年',
      sheetName: '8月',
      postData: { id: 2, status: 'deleted', dateTime: '2026/08/31 18:00:00' },
    });

    expect(client.batchUpdateValues).toHaveBeenCalledWith([
      { range: '8月!E3', values: [['deleted']] },
    ]);
    expect(results).toHaveLength(2);
  });
});
