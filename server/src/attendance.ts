import { FOLDER_ID, TEMPLATE_FILE_ID, TEMPLATE_SHEET_NAME } from './config.js';
import { formatDateJST } from './dateFormat.js';
import { columnLetter } from './google/a1.js';
import type { DriveClient } from './google/drive.js';
import type { SheetsClient } from './google/sheets.js';

type AttendColumn = 'id' | 'name' | 'type' | 'dateTime' | 'status' | 'remarks';

/** レコードのプロパティ名 -> 見出し行で探す列名（小文字）。 */
const ATTEND_HEADER_NAMES: Record<AttendColumn, string> = {
  id: 'id',
  name: 'name',
  type: 'type',
  dateTime: 'datetime',
  status: 'status',
  remarks: 'remarks',
};

export interface AttendRecord {
  id: number;
  name: string;
  type: string;
  /** yyyy/MM/dd HH:mm:ss (Asia/Tokyo)。クライアントとの受け渡し形式のまま保持する。 */
  dateTime: string;
  status: string;
  remarks: string;
}

export type NewAttendRecord = Omit<AttendRecord, 'id'>;

function columnIndexes(header: string[]): Record<AttendColumn, number> {
  const lower = header.map((h) => String(h ?? '').trim().toLowerCase());
  const indexes = {} as Record<AttendColumn, number>;
  for (const [col, headerName] of Object.entries(ATTEND_HEADER_NAMES) as [
    AttendColumn,
    string
  ][]) {
    indexes[col] = lower.indexOf(headerName);
  }
  return indexes;
}

/** 見出し行の名前で列を解決しつつ、全行をレコードに変換する。id が空の行は読み飛ばす。 */
function parseRecords(rows: string[][]): { header: string[]; col: Record<AttendColumn, number>; records: AttendRecord[] } {
  const header = rows[0] ?? [];
  const col = columnIndexes(header);

  const records: AttendRecord[] = [];
  for (let i = 1; i < rows.length; i++) {
    const row = rows[i] ?? [];
    const idRaw = row[col.id];
    if (idRaw === undefined || idRaw === '') {
      continue;
    }
    records.push({
      id: Number(idRaw),
      name: String(row[col.name] ?? ''),
      type: String(row[col.type] ?? ''),
      dateTime: String(row[col.dateTime] ?? ''),
      status: String(row[col.status] ?? ''),
      remarks: String(row[col.remarks] ?? ''),
    });
  }
  return { header, col, records };
}

const STATUS_DELETED = 'deleted';

/** 指定日の打刻を返す（削除済みを除く）。日付の同一判定は JST の日付文字列で行う。 */
export async function selectByDate(
  client: SheetsClient,
  sheetName: string,
  dateTime: Date
): Promise<AttendRecord[]> {
  const rows = await client.getValues(sheetName);
  const { records } = parseRecords(rows);
  const targetDate = formatDateJST(dateTime);
  return records.filter(
    (r) => r.status !== STATUS_DELETED && r.dateTime.startsWith(targetDate)
  );
}

/** 指定した名前の打刻を返す（削除済みを除く）。 */
export async function selectByName(
  client: SheetsClient,
  sheetName: string,
  name: string
): Promise<AttendRecord[]> {
  const rows = await client.getValues(sheetName);
  const { records } = parseRecords(rows);
  return records.filter((r) => r.status !== STATUS_DELETED && r.name === name);
}

/**
 * 打刻を1件追加する。ID は最終行の id + 1（行は論理削除のみで物理削除されないため
 * 安全）。列は見出し行の名前で解決し、位置には依存しない。
 */
export async function insertRow(
  client: SheetsClient,
  sheetName: string,
  data: NewAttendRecord
): Promise<number> {
  const rows = await client.getValues(sheetName);
  const { header, col, records } = parseRecords(rows);

  const lastRecord = records[records.length - 1];
  const nextId = lastRecord ? lastRecord.id + 1 : 1;

  const newRow: string[] = new Array(header.length).fill('');
  newRow[col.id] = String(nextId);
  newRow[col.name] = data.name;
  newRow[col.type] = data.type;
  newRow[col.dateTime] = data.dateTime;
  newRow[col.status] = data.status;
  newRow[col.remarks] = data.remarks;

  await client.appendValues(sheetName, [newRow]);
  return nextId;
}

/** id が一致する行の status だけを書き換える（時刻等は変更しない＝論理削除専用）。 */
export async function updateStatusById(
  client: SheetsClient,
  sheetName: string,
  id: number,
  status: string
): Promise<void> {
  const rows = await client.getValues(sheetName);
  const header = rows[0] ?? [];
  const col = columnIndexes(header);

  const updates: { range: string; values: unknown[][] }[] = [];
  for (let i = 1; i < rows.length; i++) {
    const row = rows[i] ?? [];
    if (Number(row[col.id] ?? NaN) !== id) {
      continue;
    }
    updates.push({
      range: `${sheetName}!${columnLetter(col.status)}${i + 1}`,
      values: [[status]],
    });
  }

  if (updates.length > 0) {
    await client.batchUpdateValues(updates);
  }
}

const MONTH_SHEET_PATTERN = /^([1-9]|1[0-2])月$/;

/** 打刻を入れる月シートかどうか。テンプレートや古いファイルの作業用シートを除く。 */
export function isMonthSheetName(name: string): boolean {
  return MONTH_SHEET_PATTERN.test(name.trim());
}

/**
 * データのある年を昇順で返す。年ごとに「2026年」という名前のファイルを作る運用
 * なので、フォルダ内のファイル名から年を拾う。
 */
export async function listYears(drive: DriveClient): Promise<number[]> {
  const names = await drive.listFileNamesInFolder(FOLDER_ID);
  const years = new Set<number>();
  for (const name of names) {
    const match = /^(\d{4})年$/.exec(name);
    if (match) {
      years.add(Number(match[1]));
    }
  }
  return [...years].sort((a, b) => a - b);
}

/** 年ファイルのスプレッドシートIDを解決する。無ければテンプレートから複製する。 */
export async function resolveYearSpreadsheetId(
  drive: DriveClient,
  fileName: string
): Promise<string> {
  const existing = await drive.findFileInFolder(FOLDER_ID, fileName);
  if (existing) {
    return existing;
  }
  return drive.copyFile(TEMPLATE_FILE_ID, fileName);
}

/**
 * 年ファイル・月シートを解決し、その月シートに束縛した SheetsClient を返す。
 * 月シートが無ければテンプレートシートを複製して作る。
 */
export async function resolveMonthSheetClient(
  drive: DriveClient,
  sheetsClientFactory: (spreadsheetId: string) => SheetsClient,
  fileName: string,
  sheetName: string
): Promise<SheetsClient> {
  const spreadsheetId = await resolveYearSpreadsheetId(drive, fileName);
  const client = sheetsClientFactory(spreadsheetId);
  await client.ensureSheetCopiedFrom(TEMPLATE_SHEET_NAME, sheetName);
  return client;
}
