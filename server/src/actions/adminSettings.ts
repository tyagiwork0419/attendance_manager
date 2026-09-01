import { timingSafeEqualString } from '../crypto.js';
import type { SheetsClient } from '../google/sheets.js';
import { fail, ok, type ActionResult } from '../result.js';
import { loadSettings, saveSettings, validateSettings, type Settings } from '../settings.js';
import { isAdmin, loadUserRecord, type UserRecord } from '../users.js';

/** 名前・パスワードを確認し、管理者であることまで確かめる。 */
async function verifyAdmin(
  client: SheetsClient,
  args: { name?: unknown; password?: unknown },
  adminRequiredMessage: string
): Promise<{ record: UserRecord } | { error: ActionResult<never> }> {
  const name = typeof args.name === 'string' ? args.name : '';
  const password = typeof args.password === 'string' ? args.password : '';

  if (!name || !password) {
    return { error: fail('名前とパスワードを入力してください', 'invalid_credentials') };
  }

  const record = await loadUserRecord(client, name);
  const expected = record ? record.password : '';
  if (!record || !timingSafeEqualString(password, expected)) {
    return { error: fail('名前またはパスワードが違います', 'invalid_credentials') };
  }

  if (!isAdmin(record)) {
    return { error: fail(adminRequiredMessage, 'admin_required') };
  }

  return { record };
}

/**
 * 管理者設定画面を開くための確認。管理者(role=admin)のパスワードでのみ通る。
 * 値は変更しない。
 */
export async function getAdminSettings(
  client: SheetsClient,
  args: { name?: unknown; password?: unknown }
): Promise<ActionResult<Settings>> {
  const verified = await verifyAdmin(client, args, '管理者のみ利用できます');
  if ('error' in verified) {
    return verified.error;
  }
  return ok(await loadSettings(client));
}

/** 設定を更新する。管理者(role=admin)のパスワードでのみ通る。 */
export async function updateSettingsAction(
  client: SheetsClient,
  args: { name?: unknown; password?: unknown; settings?: unknown }
): Promise<ActionResult<Settings>> {
  const verified = await verifyAdmin(client, args, '管理者のみ設定を変更できます');
  if ('error' in verified) {
    return verified.error;
  }

  const current = await loadSettings(client);
  const input =
    args.settings && typeof args.settings === 'object'
      ? (args.settings as Partial<Record<keyof Settings, unknown>>)
      : {};
  const validated = validateSettings(input, current);
  await saveSettings(client, validated);

  return ok(await loadSettings(client));
}
