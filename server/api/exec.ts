import type { VercelRequest, VercelResponse } from '@vercel/node';
import { createServices, dispatch } from '../src/dispatch.js';

/**
 * クライアント（Flutter Web）は CORS プリフライト(OPTIONS)を避けるため、
 * Content-Type: text/plain で JSON 文字列を POST する（GASの頃と同じ）。
 * Vercel はこれを解析せず req.body に文字列またはバッファのまま渡してくる。
 *
 * GASの script.google.com は許可オリジンを自動で返していたが、Vercel
 * Functions はそうならないため、ここで明示的に付与する。
 */
export default async function handler(req: VercelRequest, res: VercelResponse): Promise<void> {
  res.setHeader('Access-Control-Allow-Origin', '*');

  if (req.method !== 'POST') {
    res.status(405).json({ ok: false, error: 'POSTのみ受け付けます', code: 'unknown_action' });
    return;
  }

  const rawBody = extractRawBody(req.body);
  const services = createServices();
  const result = await dispatch(rawBody, services);

  res.status(200).json(result);
}

function extractRawBody(body: unknown): string {
  if (typeof body === 'string') {
    return body;
  }
  if (Buffer.isBuffer(body)) {
    return body.toString('utf8');
  }
  if (body && typeof body === 'object') {
    return JSON.stringify(body);
  }
  return '';
}
