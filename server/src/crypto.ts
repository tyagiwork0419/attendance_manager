import { createHash, randomUUID, timingSafeEqual } from 'node:crypto';
import { createHmac } from 'node:crypto';

/** 端末トークンの保存用ハッシュ。生の値をシートに残さないために使う。 */
export function sha256Hex(value: string): string {
  return createHash('sha256').update(value, 'utf8').digest('hex');
}

/**
 * 文字単位の差分を全て走査し、一致位置による処理時間の差を作らない。
 *
 * Node標準の timingSafeEqual は長さが異なるバッファを渡すと例外を投げるため、
 * GAS版と同じく長さチェックを先に行ってから比較する（不一致なら即 false）。
 */
export function timingSafeEqualString(a: string, b: string): boolean {
  const bufferA = Buffer.from(a, 'utf8');
  const bufferB = Buffer.from(b, 'utf8');
  if (bufferA.length !== bufferB.length) {
    return false;
  }
  return timingSafeEqual(bufferA, bufferB);
}

/** 端末トークンを発行する。GAS版の Utilities.getUuid()+getUuid() に相当する長さ・強度。 */
export function generateDeviceToken(): string {
  return randomUUID() + randomUUID();
}

interface SessionPayload {
  name: string;
  ttlSeconds: number;
}

interface VerifiedSession {
  name: string;
}

/**
 * 本人確認セッション用の署名付きトークンを発行する。
 *
 * サーバー側で状態を持たない（Vercel Functionsには GAS の CacheService に相当する
 * 永続ストアがないため）。`base64url(payload).base64url(hmac-sha256 signature)` の形式。
 * GASのセッションも元々失効のみでrevoke機構が無いため、この方式で振る舞いを維持できる。
 */
export function signSessionToken(payload: SessionPayload, secret: string): string {
  const exp = Date.now() + payload.ttlSeconds * 1000;
  const body = Buffer.from(JSON.stringify({ name: payload.name, exp })).toString(
    'base64url'
  );
  const signature = createHmac('sha256', secret).update(body).digest('base64url');
  return `${body}.${signature}`;
}

/** 署名・有効期限を検証する。無効なら null を返す（例外は投げない）。 */
export function verifySessionToken(token: string, secret: string): VerifiedSession | null {
  const parts = token.split('.');
  if (parts.length !== 2) {
    return null;
  }
  const [body, signature] = parts;
  if (!body || !signature) {
    return null;
  }

  const expectedSignature = createHmac('sha256', secret).update(body).digest('base64url');
  if (!timingSafeEqualString(signature, expectedSignature)) {
    return null;
  }

  let decoded: { name?: unknown; exp?: unknown };
  try {
    decoded = JSON.parse(Buffer.from(body, 'base64url').toString('utf8'));
  } catch {
    return null;
  }

  if (typeof decoded.name !== 'string' || typeof decoded.exp !== 'number') {
    return null;
  }
  if (Date.now() >= decoded.exp) {
    return null;
  }

  return { name: decoded.name };
}
