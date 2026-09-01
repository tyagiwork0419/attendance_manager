import { timingSafeEqualString } from '../crypto.js';
import type { SheetsClient } from '../google/sheets.js';
import { loadSettings } from '../settings.js';
import { loadUserRecord, writeUserPassword } from '../users.js';
import { fail, ok, type ActionResult } from '../result.js';

/**
 * パスワードを変更する。現在のパスワードを知っていることが条件。
 *
 * 呼び出しには端末トークンも必要（api/exec.ts 側で検証済みの前提）。つまり
 * 「登録済みの端末から」かつ「現在のパスワードを知っている」場合にのみ通る。
 */
export async function changePassword(
  client: SheetsClient,
  args: { name?: unknown; currentPassword?: unknown; newPassword?: unknown }
): Promise<ActionResult<{ name: string }>> {
  const name = typeof args.name === 'string' ? args.name : '';
  const currentPassword = typeof args.currentPassword === 'string' ? args.currentPassword : '';
  const newPassword = args.newPassword == null ? '' : String(args.newPassword);

  if (!name || !currentPassword) {
    return fail('名前と現在のパスワードを入力してください', 'invalid_credentials');
  }

  const record = await loadUserRecord(client, name);
  const expected = record ? record.password : '';
  if (!record || !timingSafeEqualString(currentPassword, expected)) {
    return fail('現在のパスワードが違います', 'invalid_credentials');
  }

  const settings = await loadSettings(client);
  if (newPassword.length < settings.minPasswordLength) {
    return fail(
      `新しいパスワードは${settings.minPasswordLength}文字以上にしてください`,
      'weak_password'
    );
  }

  if (newPassword === currentPassword) {
    return fail('現在のパスワードと同じです', 'weak_password');
  }

  await writeUserPassword(client, name, newPassword);
  return ok({ name });
}
