const TOKYO_TZ = 'Asia/Tokyo';

const formatter = new Intl.DateTimeFormat('en-CA', {
  timeZone: TOKYO_TZ,
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
  hour: '2-digit',
  minute: '2-digit',
  second: '2-digit',
  hour12: false,
});

function partsOf(date: Date): Record<string, string> {
  const map: Record<string, string> = {};
  for (const part of formatter.formatToParts(date)) {
    map[part.type] = part.value;
  }
  // ICUの実装によっては深夜0時が "24" になることがあるため補正する。
  if (map.hour === '24') {
    map.hour = '00';
  }
  return map;
}

/** GASの Utilities.formatDate(date, 'Asia/Tokyo', 'yyyy/MM/dd') 相当。 */
export function formatDateJST(date: Date): string {
  const p = partsOf(date);
  return `${p.year}/${p.month}/${p.day}`;
}

/** GASの Utilities.formatDate(date, 'Asia/Tokyo', 'yyyy/MM/dd HH:mm:ss') 相当。 */
export function formatDateTimeJST(date: Date): string {
  const p = partsOf(date);
  return `${p.year}/${p.month}/${p.day} ${p.hour}:${p.minute}:${p.second}`;
}

const JST_DATETIME_PATTERN = /^(\d{4})\/(\d{2})\/(\d{2}) (\d{2}):(\d{2}):(\d{2})$/;

/**
 * GASの Utilities.parseDate(value, 'Asia/Tokyo', 'yyyy/MM/dd HH:mm:ss') 相当。
 *
 * Asia/Tokyo は夏時間が無く常に UTC+9 なので、固定オフセットで直接計算できる。
 */
export function parseJstDateTime(value: string): Date {
  const match = JST_DATETIME_PATTERN.exec(value.trim());
  if (!match) {
    throw new Error(`日時の形式が不正です: ${value}`);
  }
  const [, y, mo, d, h, mi, s] = match;
  return new Date(
    Date.UTC(Number(y), Number(mo) - 1, Number(d), Number(h) - 9, Number(mi), Number(s))
  );
}
