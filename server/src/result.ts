/** doPostのレスポンス形式 `{ok:true,result}` / `{ok:false,error,code}` に対応する型。 */
export type ActionResult<T> =
  | { ok: true; result: T }
  | { ok: false; error: string; code: string };

export function ok<T>(result: T): ActionResult<T> {
  return { ok: true, result };
}

export function fail(error: string, code: string): ActionResult<never> {
  return { ok: false, error, code };
}
