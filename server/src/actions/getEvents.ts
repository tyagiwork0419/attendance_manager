import { formatDateJST, parseJstDateTime } from '../dateFormat.js';
import type { CalendarClient, CalendarEvent } from '../google/calendar.js';

/** 先取りしておく年数。予定の入力が翌年ぶんまで進んでいても拾えるようにする。 */
const CALENDAR_YEARS_FORWARD = 1;

/** 日本の祝日（Google 提供）。 */
const HOLIDAY_CALENDAR_ID = 'ja.japanese#holiday@group.v.calendar.google.com';

export function currentJstYear(): number {
  const [year] = formatDateJST(new Date()).split('/');
  return Number(year);
}

export interface YearRange {
  start: number;
  end: number;
}

/**
 * 取得する年の範囲を決める。データのある年をすべて含め、現在の年と、
 * その先取りぶんも足す。
 */
export function yearRange(years: number[], currentYear: number = currentJstYear()): YearRange {
  const candidates = [...years, currentYear];
  const start = Math.min(...candidates);
  const end = Math.max(...candidates, currentYear + CALENDAR_YEARS_FORWARD);
  return { start, end };
}

/**
 * 祝日・会社の休日を返す。[years] は勤怠データのある年の一覧。
 *
 * カレンダーにアクセスできない（共有が外れている等）場合はそのカレンダーだけ
 * 読み飛ばし、他のカレンダーの取得は続ける。
 */
export async function getEventsAction(
  calendar: CalendarClient,
  companyHolidayCalendarId: string,
  years: number[],
  currentYear: number = currentJstYear()
): Promise<CalendarEvent[]> {
  const range = yearRange(years, currentYear);
  const startDate = parseJstDateTime(`${range.start}/01/01 00:00:00`);
  const endDate = parseJstDateTime(`${range.end + 1}/01/01 00:00:00`);

  const calendarIds = [HOLIDAY_CALENDAR_ID, companyHolidayCalendarId].filter(
    (id): id is string => !!id
  );

  let events: CalendarEvent[] = [];
  for (const calendarId of calendarIds) {
    try {
      events = events.concat(await calendar.listEvents(calendarId, startDate, endDate));
    } catch (err) {
      console.warn(`カレンダーにアクセスできないため読み飛ばします: ${calendarId}`, err);
    }
  }
  return events;
}
