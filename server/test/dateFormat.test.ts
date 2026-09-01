import { describe, expect, it } from 'vitest';
import { formatDateJST, formatDateTimeJST, parseJstDateTime } from '../src/dateFormat.js';

describe('formatDateJST', () => {
  it('formats as yyyy/MM/dd in Asia/Tokyo', () => {
    // 2026-01-01T15:30:00Z is 2026-01-02 00:30 JST
    expect(formatDateJST(new Date('2026-01-01T15:30:00Z'))).toBe('2026/01/02');
  });

  it('never renders hour 24 (JST midnight edge case)', () => {
    // 2026-06-14T15:00:00Z is 2026-06-15 00:00 JST exactly.
    expect(formatDateTimeJST(new Date('2026-06-14T15:00:00Z'))).toBe('2026/06/15 00:00:00');
  });
});

describe('formatDateTimeJST', () => {
  it('formats as yyyy/MM/dd HH:mm:ss in Asia/Tokyo', () => {
    expect(formatDateTimeJST(new Date('2026-08-31T22:05:09Z'))).toBe('2026/09/01 07:05:09');
  });
});

describe('parseJstDateTime', () => {
  it('round-trips with formatDateTimeJST', () => {
    const original = new Date('2026-08-31T22:05:09Z');
    const formatted = formatDateTimeJST(original);
    expect(parseJstDateTime(formatted).getTime()).toBe(original.getTime());
  });

  it('interprets the string as JST wall-clock time', () => {
    expect(parseJstDateTime('2026/09/01 07:05:09').toISOString()).toBe(
      '2026-08-31T22:05:09.000Z'
    );
  });

  it('throws on an unparsable string', () => {
    expect(() => parseJstDateTime('not a date')).toThrow();
    expect(() => parseJstDateTime('')).toThrow();
  });
});
