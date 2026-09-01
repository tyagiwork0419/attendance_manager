import { describe, expect, it, vi } from 'vitest';
import type { CalendarClient } from '../src/google/calendar.js';
import { getEventsAction, yearRange } from '../src/actions/getEvents.js';

describe('yearRange', () => {
  it('spans from the earliest data year through one year past the current year', () => {
    const range = yearRange([2024, 2025], 2026);
    expect(range).toEqual({ start: 2024, end: 2027 });
  });

  it('falls back to the current year alone when no data years are given', () => {
    expect(yearRange([], 2026)).toEqual({ start: 2026, end: 2027 });
  });

  it('extends forward even if all data years are in the past', () => {
    expect(yearRange([2020], 2026)).toEqual({ start: 2020, end: 2027 });
  });
});

describe('getEventsAction', () => {
  it('queries both the holiday and company calendars across the computed range', async () => {
    const calendar: CalendarClient = {
      listEvents: vi.fn(async (calendarId: string) => [
        { date: '2026/01/01 00:00:00', name: `event-${calendarId}` },
      ]),
    };

    const events = await getEventsAction(calendar, 'company-cal@example.com', [2026], 2026);

    expect(events).toHaveLength(2);
    expect(calendar.listEvents).toHaveBeenCalledWith(
      'ja.japanese#holiday@group.v.calendar.google.com',
      expect.any(Date),
      expect.any(Date)
    );
    expect(calendar.listEvents).toHaveBeenCalledWith(
      'company-cal@example.com',
      expect.any(Date),
      expect.any(Date)
    );
  });

  it('skips a calendar that throws (e.g. no longer shared) and keeps the rest', async () => {
    const calendar: CalendarClient = {
      listEvents: vi.fn(async (calendarId: string) => {
        if (calendarId === 'company-cal@example.com') {
          throw new Error('not shared');
        }
        return [{ date: '2026/01/01 00:00:00', name: 'holiday' }];
      }),
    };

    const events = await getEventsAction(calendar, 'company-cal@example.com', [], 2026);
    expect(events).toEqual([{ date: '2026/01/01 00:00:00', name: 'holiday' }]);
  });

  it('skips the company calendar entirely when unset', async () => {
    const calendar: CalendarClient = {
      listEvents: vi.fn(async () => []),
    };
    await getEventsAction(calendar, '', [], 2026);
    expect(calendar.listEvents).toHaveBeenCalledTimes(1);
  });
});
