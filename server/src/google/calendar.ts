import { calendar_v3, google } from 'googleapis';
import type { JWT } from 'google-auth-library';
import { formatDateTimeJST, parseJstDateTime } from '../dateFormat.js';

export interface CalendarEvent {
  /** yyyy/MM/dd HH:mm:ss (Asia/Tokyo)。 */
  date: string;
  name: string;
}

export interface CalendarClient {
  /** [timeMin, timeMax) の範囲の予定を返す（終日予定も含む）。 */
  listEvents(calendarId: string, timeMin: Date, timeMax: Date): Promise<CalendarEvent[]>;
}

function eventStartDate(event: calendar_v3.Schema$Event): Date | null {
  if (event.start?.dateTime) {
    return new Date(event.start.dateTime);
  }
  if (event.start?.date) {
    // 終日予定はスクリプト（GAS）のタイムゾーン基準の午前0時として扱われていた。
    // Asia/Tokyo に固定して同じ意味にする。
    return parseJstDateTime(`${event.start.date.replace(/-/g, '/')} 00:00:00`);
  }
  return null;
}

type CalendarApi = Pick<calendar_v3.Calendar, 'events'>;

export function createCalendarClient(
  auth: JWT,
  api: CalendarApi = google.calendar({ version: 'v3', auth })
): CalendarClient {
  return {
    async listEvents(calendarId, timeMin, timeMax) {
      const events: CalendarEvent[] = [];
      let pageToken: string | undefined;

      do {
        const response = await api.events.list({
          calendarId,
          timeMin: timeMin.toISOString(),
          timeMax: timeMax.toISOString(),
          singleEvents: true,
          maxResults: 2500,
          pageToken,
        });

        for (const item of response.data.items ?? []) {
          const startDate = eventStartDate(item);
          if (!startDate) {
            continue;
          }
          events.push({ date: formatDateTimeJST(startDate), name: item.summary ?? '' });
        }

        pageToken = response.data.nextPageToken ?? undefined;
      } while (pageToken);

      return events;
    },
  };
}
