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
}

export function createSheetsClient(auth: JWT, spreadsheetId: string): SheetsClient {
  const api = google.sheets({ version: 'v4', auth });

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
  };
}

export type { sheets_v4 };
