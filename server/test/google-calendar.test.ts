import { describe, expect, it, vi } from 'vitest';
import { createCalendarClient } from '../src/google/calendar.js';

function makeEventsApi(overrides: Partial<Record<string, any>> = {}) {
  return {
    list: vi.fn(async () => ({ data: { items: [] } })),
    ...overrides,
  };
}

function makeAuthStub() {
  return {} as any;
}

describe('createCalendarClient.listEvents', () => {
  it('formats timed events as JST yyyy/MM/dd HH:mm:ss', async () => {
    const eventsApi = makeEventsApi({
      list: vi.fn(async () => ({
        data: {
          items: [
            { start: { dateTime: '2026-01-01T00:00:00+09:00' }, summary: '元日' },
          ],
        },
      })),
    });
    const client = createCalendarClient(makeAuthStub(), { events: eventsApi } as any);

    const events = await client.listEvents(
      'cal-1',
      new Date('2026-01-01T00:00:00Z'),
      new Date('2027-01-01T00:00:00Z')
    );
    expect(events).toEqual([{ date: '2026/01/01 00:00:00', name: '元日' }]);
  });

  it('treats all-day events as JST midnight of that date', async () => {
    const eventsApi = makeEventsApi({
      list: vi.fn(async () => ({
        data: { items: [{ start: { date: '2026-05-05' }, summary: 'こどもの日' }] },
      })),
    });
    const client = createCalendarClient(makeAuthStub(), { events: eventsApi } as any);

    const events = await client.listEvents(
      'cal-1',
      new Date('2026-01-01T00:00:00Z'),
      new Date('2027-01-01T00:00:00Z')
    );
    expect(events).toEqual([{ date: '2026/05/05 00:00:00', name: 'こどもの日' }]);
  });

  it('paginates through nextPageToken', async () => {
    const eventsApi = makeEventsApi({
      list: vi
        .fn()
        .mockResolvedValueOnce({
          data: {
            items: [{ start: { date: '2026-01-01' }, summary: 'A' }],
            nextPageToken: 'p2',
          },
        })
        .mockResolvedValueOnce({
          data: { items: [{ start: { date: '2026-02-01' }, summary: 'B' }] },
        }),
    });
    const client = createCalendarClient(makeAuthStub(), { events: eventsApi } as any);
    const events = await client.listEvents(
      'cal-1',
      new Date('2026-01-01T00:00:00Z'),
      new Date('2027-01-01T00:00:00Z')
    );
    expect(events.map((e) => e.name)).toEqual(['A', 'B']);
  });

  it('skips events with neither dateTime nor date', async () => {
    const eventsApi = makeEventsApi({
      list: vi.fn(async () => ({ data: { items: [{ summary: 'broken' }] } })),
    });
    const client = createCalendarClient(makeAuthStub(), { events: eventsApi } as any);
    const events = await client.listEvents(
      'cal-1',
      new Date('2026-01-01T00:00:00Z'),
      new Date('2027-01-01T00:00:00Z')
    );
    expect(events).toEqual([]);
  });
});
