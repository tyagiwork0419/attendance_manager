/** 打刻データの年ファイルが置かれているDriveフォルダ（gas/AttendanceManagerBackend.js と同じ値）。 */
export const FOLDER_ID = '1Iq5UpbILGSUxZfMFqgCbVk6g75hXqY59';

/** 新しい年ファイルを作るときにコピーするテンプレート。 */
export const TEMPLATE_FILE_ID = '1uycFMLBrmp1Z3BWFV3y_NmQrSasRDBV2OM0qw-G489g';

/** 新しい月シートを作るときにコピーするテンプレートシート名。 */
export const TEMPLATE_SHEET_NAME = 'template';

/** ユーザー・端末・設定を保持するスプレッドシート（gas/Auth.gs と同じ値）。 */
export const USERS_SPREADSHEET_ID = '1wMNwaPobjjov3orYkEpuoaqEx6YC3BSBHLBGZFukb6o'; // TEMP: diagnostic test, revert after
export const USERS_SHEET_NAME = 'users';
export const DEVICES_SHEET_NAME = 'devices';
export const SETTINGS_SHEET_NAME = 'settings';

export const TIMEZONE = 'Asia/Tokyo';

/** 本人確認セッションの既定の有効期間(秒)。管理者設定で上書きされる。 */
export const DEFAULT_SESSION_TTL_SECONDS = 21600;

/** サーバー側で許容するセッション有効期間の上限(秒)。 */
export const MAX_SESSION_TTL_SECONDS = 21600;

function requiredEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

export interface ServiceAccountCredentials {
  clientEmail: string;
  privateKey: string;
}

/**
 * サービスアカウントの認証情報を環境変数から読む。
 *
 * `GOOGLE_PRIVATE_KEY` は改行が `\n` エスケープされた1行の文字列として環境変数に
 * 設定する運用を前提にする（Vercelのenv var入力欄は複数行を素直に扱えないため）。
 */
export function getServiceAccountCredentials(): ServiceAccountCredentials {
  return {
    clientEmail: requiredEnv('GOOGLE_CLIENT_EMAIL'),
    privateKey: requiredEnv('GOOGLE_PRIVATE_KEY').replace(/\\n/g, '\n'),
  };
}

/** セッショントークンの署名に使う秘密鍵。 */
export function getSessionSecret(): string {
  return requiredEnv('SESSION_SECRET');
}
