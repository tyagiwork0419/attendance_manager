import { signSessionToken, timingSafeEqualString } from '../crypto.js';
import type { SheetsClient } from '../google/sheets.js';
import { loadSettings } from '../settings.js';
import { loadUserRecord } from '../users.js';
import { fail, ok, type ActionResult } from '../result.js';

export interface LoginResult {
  token: string;
  name: string;
  expiresIn: number;
}

export async function login(
  client: SheetsClient,
  sessionSecret: string,
  args: { name?: unknown; password?: unknown }
): Promise<ActionResult<LoginResult>> {
  const name = typeof args.name === 'string' ? args.name : '';
  const password = typeof args.password === 'string' ? args.password : '';

  if (!name || !password) {
    return fail('名前とパスワードを入力してください', 'invalid_credentials');
  }

  const record = await loadUserRecord(client, name);

  // 存在しないユーザーでも同じ比較経路を通し、応答の差で
  // ユーザーの存在有無が判別できないようにする。
  const expected = record ? record.password : '';
  const matched = timingSafeEqualString(password, expected);

  if (!record || !matched) {
    return fail('名前またはパスワードが違います', 'invalid_credentials');
  }

  const settings = await loadSettings(client);
  const token = signSessionToken({ name, ttlSeconds: settings.sessionTtlSeconds }, sessionSecret);

  return ok({ token, name, expiresIn: settings.sessionTtlSeconds });
}
