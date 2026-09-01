import { SETTINGS_SHEET_NAME } from './config.js';
import type { SheetsClient } from './google/sheets.js';

export interface Settings {
  /** 所定労働時間(時間/日)。残業時間の算出に使う。 */
  standardWorkHoursPerDay: number;
  /** 新しいパスワードの最低文字数。 */
  minPasswordLength: number;
  /** 本人確認セッションの有効期限(秒)。上限は MAX_SESSION_TTL_SECONDS。 */
  sessionTtlSeconds: number;
  /** 会社の休日カレンダーID。 */
  companyHolidayCalendarId: string;
  /** 有休の年間付与日数（全社一律）。 */
  paidHolidayGrantDays: number;
  /** 有休を付与する月日。 */
  paidHolidayGrantMonth: number;
  paidHolidayGrantDay: number;
  /** 付与から何年で失効するか。 */
  paidHolidayExpirationYears: number;
}

/** CacheService.put の上限を引き継いだ、セッション有効期限の上限(秒)。 */
export const MAX_SESSION_TTL_SECONDS = 21600;

export const SETTINGS_DEFAULTS: Settings = {
  standardWorkHoursPerDay: 8,
  minPasswordLength: 6,
  sessionTtlSeconds: MAX_SESSION_TTL_SECONDS,
  companyHolidayCalendarId: '50oe6kjcmt9nmjlagbab00af7c@group.calendar.google.com',
  paidHolidayGrantDays: 10,
  paidHolidayGrantMonth: 9,
  paidHolidayGrantDay: 1,
  paidHolidayExpirationYears: 2,
};

const SETTINGS_KEYS = Object.keys(SETTINGS_DEFAULTS) as (keyof Settings)[];

const SETTINGS_RANGE = `${SETTINGS_SHEET_NAME}!A:B`;

/**
 * 設定を読む。`settings` シート（見出し行 key/value、以降 key,value の2列）を
 * 読み、既定値にマージする。未知のキーや壊れた値は無視して既定値のまま残す。
 */
export async function loadSettings(client: SheetsClient): Promise<Settings> {
  const rows = await client.getValues(SETTINGS_RANGE);

  const stored = new Map<string, string>();
  for (const row of rows) {
    const key = row[0];
    if (key) {
      stored.set(key, row[1] ?? '');
    }
  }

  const settings = { ...SETTINGS_DEFAULTS };
  for (const key of SETTINGS_KEYS) {
    const raw = stored.get(key);
    if (raw === undefined || raw === '') {
      continue;
    }
    try {
      (settings as Record<string, unknown>)[key] = JSON.parse(raw);
    } catch {
      // 既定値のまま残す。
    }
  }
  return settings;
}

function numberOr(value: unknown, fallback: number): number {
  const n = Number(value);
  return Number.isFinite(n) ? n : fallback;
}

function clamp(n: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, n));
}

/**
 * 入力を検証し、保存してよい形に整える。未指定の項目は current の値をそのまま使う
 * （部分更新を許すため）。クランプ範囲は GAS 版 validateSettings_ と同じ。
 */
export function validateSettings(
  input: Partial<Record<keyof Settings, unknown>>,
  current: Settings
): Settings {
  return {
    standardWorkHoursPerDay: clamp(
      numberOr(input.standardWorkHoursPerDay, current.standardWorkHoursPerDay),
      0.5,
      24
    ),
    minPasswordLength: Math.round(
      clamp(numberOr(input.minPasswordLength, current.minPasswordLength), 1, 100)
    ),
    sessionTtlSeconds: Math.round(
      clamp(
        numberOr(input.sessionTtlSeconds, current.sessionTtlSeconds),
        60,
        MAX_SESSION_TTL_SECONDS
      )
    ),
    companyHolidayCalendarId:
      input.companyHolidayCalendarId === undefined
        ? current.companyHolidayCalendarId
        : String(input.companyHolidayCalendarId).trim(),
    paidHolidayGrantDays: clamp(
      numberOr(input.paidHolidayGrantDays, current.paidHolidayGrantDays),
      0,
      365
    ),
    paidHolidayGrantMonth: Math.round(
      clamp(numberOr(input.paidHolidayGrantMonth, current.paidHolidayGrantMonth), 1, 12)
    ),
    paidHolidayGrantDay: Math.round(
      clamp(numberOr(input.paidHolidayGrantDay, current.paidHolidayGrantDay), 1, 31)
    ),
    paidHolidayExpirationYears: Math.round(
      clamp(
        numberOr(input.paidHolidayExpirationYears, current.paidHolidayExpirationYears),
        1,
        20
      )
    ),
  };
}

/**
 * 設定を保存する。既存のキーはその行を更新し、まだ無いキーは末尾に追記する。
 * 呼び出し前に validateSettings を通した値を渡すこと。
 */
export async function saveSettings(client: SheetsClient, settings: Settings): Promise<void> {
  const rows = await client.getValues(SETTINGS_RANGE);

  const rowIndexByKey = new Map<string, number>();
  rows.forEach((row, index) => {
    const key = row[0];
    if (key) {
      rowIndexByKey.set(key, index);
    }
  });

  const updates: { range: string; values: unknown[][] }[] = [];
  const appended: unknown[][] = [];

  for (const key of SETTINGS_KEYS) {
    const value = JSON.stringify(settings[key]);
    const rowIndex = rowIndexByKey.get(key);
    if (rowIndex === undefined) {
      appended.push([key, value]);
    } else {
      // rows は sheet の1行目から並ぶため、0始まりのindexに+1すればそのままシート行番号になる。
      updates.push({
        range: `${SETTINGS_SHEET_NAME}!B${rowIndex + 1}`,
        values: [[value]],
      });
    }
  }

  if (updates.length > 0) {
    await client.batchUpdateValues(updates);
  }
  if (appended.length > 0) {
    await client.appendValues(SETTINGS_RANGE, appended);
  }
}
