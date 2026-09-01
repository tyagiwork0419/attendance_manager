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
