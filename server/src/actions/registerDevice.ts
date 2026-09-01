import { generateDeviceToken, sha256Hex, timingSafeEqualString } from '../crypto.js';
import { appendDevice } from '../devices.js';
import type { SheetsClient } from '../google/sheets.js';
import { isAdmin, loadUserRecord } from '../users.js';
import { fail, ok, type ActionResult } from '../result.js';

export interface RegisterDeviceResult {
  token: string;
  user: string;
  shared: boolean;
}

/**
 * 端末を登録する。登録には既存ユーザーのパスワードが必要。
 * 発行したトークンはこの応答でしか返さない（サーバーはハッシュしか保持しない）。
 *
 * 共有端末としての登録（shared: true）は管理者のみ許可する。
 * 個人名義での登録（shared: false）は誰でもできる。
 */
export async function registerDevice(
  client: SheetsClient,
  args: { name?: unknown; password?: unknown; label?: unknown; shared?: unknown }
): Promise<ActionResult<RegisterDeviceResult>> {
  const name = typeof args.name === 'string' ? args.name : '';
  const password = typeof args.password === 'string' ? args.password : '';

  if (!name || !password) {
    return fail('名前とパスワードを入力してください', 'invalid_credentials');
  }

  const record = await loadUserRecord(client, name);
  const expected = record ? record.password : '';
  if (!record || !timingSafeEqualString(password, expected)) {
    return fail('名前またはパスワードが違います', 'invalid_credentials');
  }

  const shared = args.shared === true;
  if (shared && !isAdmin(record)) {
    return fail('共有端末への登録は管理者のみ行えます', 'admin_required');
  }

  const token = generateDeviceToken();
  await appendDevice(client, {
    tokenHash: sha256Hex(token),
    user: shared ? '' : name,
    label: typeof args.label === 'string' ? args.label.trim() : '',
    createdAt: new Date(),
  });

  return ok({ token, user: shared ? '' : name, shared });
}
