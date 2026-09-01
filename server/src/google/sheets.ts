import { sheets_v4, google } from 'googleapis';
import type { JWT } from 'google-auth-library';

/**
 * Sheets API の薄いラッパー。呼び出し側は spreadsheetId を毎回渡さなくてよいように
 * 1つのスプレッドシートに束縛したクライアントを受け取る。
 *
 * テスト時はこのインターフェースをモックするだけでよく、googleapis を直接モックする
 * 必要がない。
 */
export interface SheetsClient {
  /** A1記法の範囲を文字列の2次元配列で返す。空セルは空文字列になる。 */
  getValues(range: string): Promise<string[][]>;
  /** 複数範囲を1回のリクエストでまとめて更新する。 */
  batchUpdateValues(updates: { range: string; values: unknown[][] }[]): Promise<void>;
  /** 範囲の末尾に行を追記する（既存行は変更しない）。 */
  appendValues(range: string, values: unknown[][]): Promise<void>;
  /** シートが無ければ作り、見出し行を書く。既にあれば何もしない。 */
  ensureSheetWithHeader(sheetName: string, header: string[]): Promise<void>;
  /** このスプレッドシート内の全シート（タブ）名。 */
  listSheetNames(): Promise<string[]>;
  /**
   * シートが無ければ、同じスプレッドシート内の templateSheetName を複製して
   * newSheetName にリネームする。既にあれば何もしない。
   */
  ensureSheetCopiedFrom(templateSheetName: string, newSheetName: string): Promise<void>;
}

type SheetsApi = Pick<sheets_v4.Sheets, 'spreadsheets'>;

export function createSheetsClient(
  auth: JWT,
  spreadsheetId: string,
  api: SheetsApi = google.sheets({ version: 'v4', auth })
): SheetsClient {
  return {
    async getValues(range) {
      const response = await api.spreadsheets.values.get({ spreadsheetId, range });
      return (response.data.values ?? []) as string[][];
    },

    async batchUpdateValues(updates) {
      if (updates.length === 0) {
        return;
      }
      await api.spreadsheets.values.batchUpdate({
        spreadsheetId,
        requestBody: {
          valueInputOption: 'RAW',
          data: updates.map((u) => ({ range: u.range, values: u.values })),
        },
      });
    },

    async appendValues(range, values) {
      await api.spreadsheets.values.append({
        spreadsheetId,
        range,
        valueInputOption: 'RAW',
        insertDataOption: 'INSERT_ROWS',
        requestBody: { values },
      });
    },

    async ensureSheetWithHeader(sheetName, header) {
      const meta = await api.spreadsheets.get({ spreadsheetId });
      const exists = (meta.data.sheets ?? []).some(
        (s) => s.properties?.title === sheetName
      );
      if (exists) {
        return;
      }
      await api.spreadsheets.batchUpdate({
        spreadsheetId,
        requestBody: { requests: [{ addSheet: { properties: { title: sheetName } } }] },
      });
      await api.spreadsheets.values.append({
        spreadsheetId,
        range: `${sheetName}!A1`,
        valueInputOption: 'RAW',
        requestBody: { values: [header] },
      });
    },

    async listSheetNames() {
      const meta = await api.spreadsheets.get({ spreadsheetId });
      return (meta.data.sheets ?? [])
        .map((s) => s.properties?.title)
        .filter((title): title is string => !!title);
    },

    async ensureSheetCopiedFrom(templateSheetName, newSheetName) {
      const meta = await api.spreadsheets.get({ spreadsheetId });
      const sheetsList = meta.data.sheets ?? [];

      const exists = sheetsList.some((s) => s.properties?.title === newSheetName);
      if (exists) {
        return;
      }

      const template = sheetsList.find((s) => s.properties?.title === templateSheetName);
      const templateSheetId = template?.properties?.sheetId;
      if (templateSheetId === undefined || templateSheetId === null) {
        throw new Error(`テンプレートシートが見つかりません: ${templateSheetName}`);
      }

      const copyResponse = await api.spreadsheets.sheets.copyTo({
        spreadsheetId,
        sheetId: templateSheetId,
        requestBody: { destinationSpreadsheetId: spreadsheetId },
      });
      const newSheetId = copyResponse.data.sheetId;

      await api.spreadsheets.batchUpdate({
        spreadsheetId,
        requestBody: {
          requests: [
            {
              updateSheetProperties: {
                properties: { sheetId: newSheetId, title: newSheetName },
                fields: 'title',
              },
            },
          ],
        },
      });
    },
  };
}

export type { sheets_v4 };
