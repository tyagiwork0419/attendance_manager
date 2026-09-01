import { USERS_SHEET_NAME } from './config.js';
import { columnLetter } from './google/a1.js';
import type { SheetsClient } from './google/sheets.js';

export interface UserRecord {
  name: string;
  password: string;
  role: string;
}

const COLUMN_NAME = 'name';
const COLUMN_PASSWORD = 'password';
const COLUMN_ROLE = 'role';

export const ROLE_ADMIN = 'admin';

/**
 * users シートを読み、[{name, password, role}] を返す。
 *
 * 列は見出し行の名前で解決する（列順が変わっても動作する）。role 列は省略可能で、
 * 無い場合は全員 role: '' として扱う。
 */
export async function loadUsers(client: SheetsClient): Promise<UserRecord[]> {
  const rows = await client.getValues(USERS_SHEET_NAME);
  if (rows.length < 2) {
    return [];
  }

  const header = (rows[0] ?? []).map((h) => String(h ?? '').trim().toLowerCase());
  const nameIndex = header.indexOf(COLUMN_NAME);
  const passwordIndex = header.indexOf(COLUMN_PASSWORD);
  const roleIndex = header.indexOf(COLUMN_ROLE);

  if (nameIndex < 0 || passwordIndex < 0) {
    throw new Error(`${USERS_SHEET_NAME} シートに ${COLUMN_NAME} / ${COLUMN_PASSWORD} 列が必要です`);
  }

  const users: UserRecord[] = [];
  for (let i = 1; i < rows.length; i++) {
    const row = rows[i] ?? [];
    const name = String(row[nameIndex] ?? '').trim();
    if (!name) {
      continue;
    }
    const role = roleIndex < 0 ? '' : String(row[roleIndex] ?? '').trim().toLowerCase();
    const password = String(row[passwordIndex] ?? '').trim();
    users.push({ name, password, role });
  }
  return users;
}

/** 管理者かどうか。role 列が無い・空のユーザーは一般利用者として扱う。 */
export function isAdmin(user: UserRecord | null): boolean {
  return !!user && user.role === ROLE_ADMIN;
}

export async function loadUserRecord(
  client: SheetsClient,
  name: string
): Promise<UserRecord | null> {
  const users = await loadUsers(client);
  return users.find((u) => u.name === name) ?? null;
}

/** ログイン画面に出す名前の一覧。パスワードは一切返さない。 */
export async function listUserNames(client: SheetsClient): Promise<string[]> {
  const users = await loadUsers(client);
  return users.map((u) => u.name);
}

/**
 * users シートのパスワード欄を書き換える。
 *
 * Sheets API の valueInputOption: RAW は値をそのまま文字列として保存するため、
 * GAS版のように setNumberFormat('@') で先に書式を文字列にしておく必要がない
 * （数字だけのパスワードでも先頭の0が失われない）。
 */
export async function writeUserPassword(
  client: SheetsClient,
  name: string,
  newPassword: string
): Promise<void> {
  const rows = await client.getValues(USERS_SHEET_NAME);
  const header = (rows[0] ?? []).map((h) => String(h ?? '').trim().toLowerCase());
  const nameIndex = header.indexOf(COLUMN_NAME);
  const passwordIndex = header.indexOf(COLUMN_PASSWORD);

  for (let i = 1; i < rows.length; i++) {
    const row = rows[i] ?? [];
    if (String(row[nameIndex] ?? '').trim() !== name) {
      continue;
    }
    await client.batchUpdateValues([
      {
        range: `${USERS_SHEET_NAME}!${columnLetter(passwordIndex)}${i + 1}`,
        values: [[newPassword]],
      },
    ]);
    return;
  }

  throw new Error(`ユーザーが見つかりません: ${name}`);
}
