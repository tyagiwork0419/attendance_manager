import {
  insertRow,
  isMonthSheetName,
  resolveMonthSheetClient,
  resolveYearSpreadsheetId,
  selectByDate,
  selectByName,
  updateStatusById,
  type AttendRecord,
} from '../attendance.js';
import { parseJstDateTime } from '../dateFormat.js';
import type { DriveClient } from '../google/drive.js';
import type { SheetsClient } from '../google/sheets.js';

export type SheetsClientFactory = (spreadsheetId: string) => SheetsClient;

interface FileSheetArgs {
  fileName?: unknown;
  sheetName?: unknown;
}

function str(value: unknown): string {
  return typeof value === 'string' ? value : String(value ?? '');
}

export async function selectByDateAction(
  drive: DriveClient,
  sheetsFactory: SheetsClientFactory,
  args: FileSheetArgs & { dateTime?: unknown }
): Promise<AttendRecord[]> {
  const sheetName = str(args.sheetName);
  const client = await resolveMonthSheetClient(drive, sheetsFactory, str(args.fileName), sheetName);
  return selectByDate(client, sheetName, parseJstDateTime(str(args.dateTime)));
}

export async function selectByNameAction(
  drive: DriveClient,
  sheetsFactory: SheetsClientFactory,
  args: FileSheetArgs & { name?: unknown }
): Promise<AttendRecord[]> {
  const sheetName = str(args.sheetName);
  const client = await resolveMonthSheetClient(drive, sheetsFactory, str(args.fileName), sheetName);
  return selectByName(client, sheetName, str(args.name));
}

/**
 * 1年分（ファイル内の全シート）をまとめて返す。
 *
 * 月ごとに呼ぶと往復が12回になるため、ここでまとめる。月シートが無くても
 * 作らない（実在するシートだけを読む）。
 */
export async function selectByNameForYearAction(
  drive: DriveClient,
  sheetsFactory: SheetsClientFactory,
  args: { fileName?: unknown; name?: unknown }
): Promise<AttendRecord[]> {
  const name = str(args.name);
  const spreadsheetId = await resolveYearSpreadsheetId(drive, str(args.fileName));
  const client = sheetsFactory(spreadsheetId);
  const sheetNames = await client.listSheetNames();

  let all: AttendRecord[] = [];
  for (const sheetName of sheetNames) {
    if (!isMonthSheetName(sheetName)) {
      continue;
    }
    all = all.concat(await selectByName(client, sheetName, name));
  }
  return all;
}

interface PunchPostData {
  name?: unknown;
  type?: unknown;
  dateTime?: unknown;
  status?: unknown;
  remarks?: unknown;
}

/** 打刻を追加し、その日ぶんの全データを返す（insertRows はその日ぶんしか返さないと使いにくいため）。 */
export async function insertRowsAction(
  drive: DriveClient,
  sheetsFactory: SheetsClientFactory,
  args: FileSheetArgs & { postData?: PunchPostData }
): Promise<AttendRecord[]> {
  const sheetName = str(args.sheetName);
  const postData = args.postData ?? {};
  const dateTimeStr = str(postData.dateTime);

  const client = await resolveMonthSheetClient(drive, sheetsFactory, str(args.fileName), sheetName);
  await insertRow(client, sheetName, {
    name: str(postData.name),
    type: str(postData.type),
    dateTime: dateTimeStr,
    status: str(postData.status) || 'normal',
    remarks: str(postData.remarks),
  });

  return selectByDate(client, sheetName, parseJstDateTime(dateTimeStr));
}

interface UpdatePostData {
  id?: unknown;
  status?: unknown;
  dateTime?: unknown;
}

/** id の行の status だけを更新し、その日ぶんの全データを返す。 */
export async function updateByIdAction(
  drive: DriveClient,
  sheetsFactory: SheetsClientFactory,
  args: FileSheetArgs & { postData?: UpdatePostData }
): Promise<AttendRecord[]> {
  const sheetName = str(args.sheetName);
  const postData = args.postData ?? {};
  const id = Number(postData.id);
  const dateTimeStr = str(postData.dateTime);

  const client = await resolveMonthSheetClient(drive, sheetsFactory, str(args.fileName), sheetName);
  await updateStatusById(client, sheetName, id, str(postData.status));

  return selectByDate(client, sheetName, parseJstDateTime(dateTimeStr));
}
