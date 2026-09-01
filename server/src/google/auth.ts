import { JWT } from 'google-auth-library';
import { getServiceAccountCredentials } from '../config.js';

/**
 * サービスアカウントに必要なスコープ。
 *
 * gas/appsscript.json はフル権限（spreadsheets/drive/calendar）だったが、
 * カレンダーは祝日・会社休日の読み取りにしか使わないため readonly に絞る。
 */
const SCOPES = [
  'https://www.googleapis.com/auth/spreadsheets',
  'https://www.googleapis.com/auth/drive',
  'https://www.googleapis.com/auth/calendar.readonly',
];

let cachedClient: JWT | undefined;

/**
 * サービスアカウントの認証クライアントを返す。
 *
 * Vercel Functions はウォームインスタンス間でモジュールスコープの変数を再利用できる
 * ことがあるため、リクエストのたびに作り直さずキャッシュする（実際に効くかは
 * インスタンスの再利用状況次第だが、無駄にはならない）。
 */
export function getAuthClient(): JWT {
  if (!cachedClient) {
    const { clientEmail, privateKey } = getServiceAccountCredentials();
    cachedClient = new JWT({
      email: clientEmail,
      key: privateKey,
      scopes: SCOPES,
    });
  }
  return cachedClient;
}
