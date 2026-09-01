import { DEVICES_SHEET_NAME } from './config.js';
import { formatDateJST, formatDateTimeJST } from './dateFormat.js';
import { columnLetter } from './google/a1.js';
import type { SheetsClient } from './google/sheets.js';
import { sha256Hex } from './crypto.js';

export const DEVICE_HEADER = ['token_hash', 'user', 'label', 'created', 'last_used', 'revoked'];

export interface ResolvedDevice {
  /** 所有者の名前。空文字なら共有端末。 */
  user: string;
}

interface DeviceColumnIndexes {
  tokenHash: number;
  user: number;
  label: number;
  created: number;
  lastUsed: number;
  revoked: number;
}

function deviceColumnIndexes(header: string[]): DeviceColumnIndexes {
  const lower = header.map((h) => String(h ?? '').trim().toLowerCase());
  return {
    tokenHash: lower.indexOf('token_hash'),
    user: lower.indexOf('user'),
    label: lower.indexOf('label'),
    created: lower.indexOf('created'),
    lastUsed: lower.indexOf('last_used'),
    revoked: lower.indexOf('revoked'),
  };
}

/**
 * 端末トークンを検証する。有効なら { user } を返し、無効なら null。
 *
 * v1ではキャッシュを挟まない（Sheets API自体がGASのDrive検索より十分速い想定のため。
 * ADR 0004参照）。
 */
export async function resolveDevice(
  client: SheetsClient,
  token: string | undefined | null
): Promise<ResolvedDevice | null> {
  if (!token) {
    return null;
  }

  const hash = sha256Hex(token);
  const rows = await client.getValues(DEVICES_SHEET_NAME);
  if (rows.length < 2) {
    return null;
  }

  const col = deviceColumnIndexes(rows[0] ?? []);
  if (col.tokenHash < 0) {
    return null;
  }

  for (let i = 1; i < rows.length; i++) {
    const row = rows[i] ?? [];
    if (String(row[col.tokenHash] ?? '').trim() !== hash) {
      continue;
    }

    const revoked = String(row[col.revoked] ?? '').trim().toUpperCase();
    if (revoked === 'TRUE' || revoked === '1' || revoked === 'はい') {
      return null;
    }

    await touchLastUsed(client, i, col.lastUsed, String(row[col.lastUsed] ?? ''));
    return { user: String(row[col.user] ?? '').trim() };
  }

  return null;
}

/** 最終利用日を更新する。日付が変わったときだけ書く。書けなくても認証は通す。 */
async function touchLastUsed(
  client: SheetsClient,
  rowIndex: number,
  columnIndex: number,
  current: string
): Promise<void> {
  if (columnIndex < 0) {
    return;
  }
  const today = formatDateJST(new Date());
  if (current.startsWith(today)) {
    return;
  }
  try {
    await client.batchUpdateValues([
      {
        range: `${DEVICES_SHEET_NAME}!${columnLetter(columnIndex)}${rowIndex + 1}`,
        values: [[today]],
      },
    ]);
  } catch {
    // 監査用の情報なので、書けなくても認証は通す。
  }
}

/** 端末を登録する。管理者判定・パスワード確認は呼び出し側（actions層）が行う。 */
export async function appendDevice(
  client: SheetsClient,
  args: { tokenHash: string; user: string; label: string; createdAt: Date }
): Promise<void> {
  await client.ensureSheetWithHeader(DEVICES_SHEET_NAME, DEVICE_HEADER);
  await client.appendValues(DEVICES_SHEET_NAME, [
    [
      args.tokenHash,
      args.user,
      args.label,
      formatDateTimeJST(args.createdAt),
      '',
      'FALSE',
    ],
  ]);
}

/**
 * この端末を共有端末にするか、特定の人の端末にするかを切り替える。
 * トークンに一致する行が無ければ false を返す。
 */
export async function setDeviceOwner(
  client: SheetsClient,
  tokenHash: string,
  user: string
): Promise<boolean> {
  const rows = await client.getValues(DEVICES_SHEET_NAME);
  if (rows.length < 2) {
    return false;
  }

  const col = deviceColumnIndexes(rows[0] ?? []);
  for (let i = 1; i < rows.length; i++) {
    const row = rows[i] ?? [];
    if (String(row[col.tokenHash] ?? '').trim() !== tokenHash) {
      continue;
    }
    await client.batchUpdateValues([
      {
        range: `${DEVICES_SHEET_NAME}!${columnLetter(col.user)}${i + 1}`,
        values: [[user]],
      },
    ]);
    return true;
  }
  return false;
}
