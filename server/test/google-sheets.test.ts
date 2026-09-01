import { describe, expect, it, vi } from 'vitest';
import { createSheetsClient } from '../src/google/sheets.js';

function makeSheetsApi(overrides: Partial<Record<string, any>> = {}) {
  return {
    spreadsheets: {
      get: vi.fn(async () => ({ data: { sheets: [] } })),
      batchUpdate: vi.fn(async () => ({ data: {} })),
      values: {
        get: vi.fn(async () => ({ data: { values: [] } })),
        append: vi.fn(async () => ({ data: {} })),
        batchUpdate: vi.fn(async () => ({ data: {} })),
      },
      sheets: {
        copyTo: vi.fn(async () => ({ data: { sheetId: 999 } })),
      },
      ...overrides,
    },
  };
}

function makeAuthStub() {
  return {} as any;
}

describe('createSheetsClient.listSheetNames', () => {
  it('returns the titles of every sheet/tab', async () => {
    const api = makeSheetsApi({
      get: vi.fn(async () => ({
        data: { sheets: [{ properties: { title: '8月' } }, { properties: { title: 'template' } }] },
      })),
    });
    const client = createSheetsClient(makeAuthStub(), 'sheet-id', api as any);
    expect(await client.listSheetNames()).toEqual(['8月', 'template']);
  });
});

describe('createSheetsClient.ensureSheetCopiedFrom', () => {
  it('does nothing if the target sheet already exists', async () => {
    const api = makeSheetsApi({
      get: vi.fn(async () => ({
        data: { sheets: [{ properties: { title: '8月', sheetId: 1 } }] },
      })),
    });
    const client = createSheetsClient(makeAuthStub(), 'sheet-id', api as any);
    await client.ensureSheetCopiedFrom('template', '8月');
    expect(api.spreadsheets.sheets.copyTo).not.toHaveBeenCalled();
  });

  it('copies the template sheet and renames it when the target is missing', async () => {
    const api = makeSheetsApi({
      get: vi.fn(async () => ({
        data: { sheets: [{ properties: { title: 'template', sheetId: 5 } }] },
      })),
      sheets: { copyTo: vi.fn(async () => ({ data: { sheetId: 42 } })) },
    });
    const client = createSheetsClient(makeAuthStub(), 'sheet-id', api as any);
    await client.ensureSheetCopiedFrom('template', '9月');

    expect(api.spreadsheets.sheets.copyTo).toHaveBeenCalledWith({
      spreadsheetId: 'sheet-id',
      sheetId: 5,
      requestBody: { destinationSpreadsheetId: 'sheet-id' },
    });
    expect(api.spreadsheets.batchUpdate).toHaveBeenCalledWith({
      spreadsheetId: 'sheet-id',
      requestBody: {
        requests: [
          {
            updateSheetProperties: {
              properties: { sheetId: 42, title: '9月' },
              fields: 'title',
            },
          },
        ],
      },
    });
  });

  it('throws when the template sheet itself is missing', async () => {
    const api = makeSheetsApi({
      get: vi.fn(async () => ({ data: { sheets: [] } })),
    });
    const client = createSheetsClient(makeAuthStub(), 'sheet-id', api as any);
    await expect(client.ensureSheetCopiedFrom('template', '9月')).rejects.toThrow(/template/);
  });
});
