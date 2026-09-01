import { describe, expect, it } from 'vitest';
import { columnLetter } from '../src/google/a1.js';

describe('columnLetter', () => {
  it('converts 0-based column indexes to A1 letters', () => {
    expect(columnLetter(0)).toBe('A');
    expect(columnLetter(1)).toBe('B');
    expect(columnLetter(25)).toBe('Z');
    expect(columnLetter(26)).toBe('AA');
    expect(columnLetter(27)).toBe('AB');
    expect(columnLetter(51)).toBe('AZ');
    expect(columnLetter(52)).toBe('BA');
  });
});
