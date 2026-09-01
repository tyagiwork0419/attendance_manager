import { sha256Hex, timingSafeEqualString } from '../crypto.js';
import { setDeviceOwner } from '../devices.js';
import type { SheetsClient } from '../google/sheets.js';
import { isAdmin, loadUserRecord } from '../users.js';
import { fail, ok, type ActionResult } from '../result.js';

export interface UpdateDeviceOwnerResult {
  user: string;
  shared: boolean;
}

/**
 * この端末を共有端末にするか、特定の人の端末にするかを切り替える。
 *
 * 名義を変えるとその人のタイムカードをパスワードなしで開けるようになるため、
 * 必ずその人のパスワードで本人確認する。共有端末に戻す場合も同じ確認を通す。
 *
 * 共有端末への切り替え（shared: true）はさらに管理者のみ許可する。
 * 個人名義に戻す（shared: false）のは本人確認さえ取れれば誰でもできる。
 */
export async function updateDeviceOwner(
  client: SheetsClient,
  args: { name?: unknown; password?: unknown; shared?: unknown; deviceToken?: unknown }
): Promise<ActionResult<UpdateDeviceOwnerResult>> {
  const name = typeof args.name === 'string' ? args.name : '';
  const password = typeof args.password === 'string' ? args.password : '';
  const shared = args.shared === true;

  if (!name || !password) {
    return fail('名前とパスワードを入力してください', 'invalid_credentials');
  }

  const record = await loadUserRecord(client, name);
  const expected = record ? record.password : '';
  if (!record || !timingSafeEqualString(password, expected)) {
    return fail('名前またはパスワードが違います', 'invalid_credentials');
  }

  if (shared && !isAdmin(record)) {
    return fail('共有端末への変更は管理者のみ行えます', 'admin_required');
  }

  const deviceToken = typeof args.deviceToken === 'string' ? args.deviceToken : '';
  const hash = sha256Hex(deviceToken);
  const updated = await setDeviceOwner(client, hash, shared ? '' : name);
  if (!updated) {
    return fail('この端末は登録されていません', 'device_unauthorized');
  }

  return ok({ user: shared ? '' : name, shared });
}
