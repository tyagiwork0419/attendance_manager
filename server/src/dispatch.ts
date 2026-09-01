import { getAuthClient } from './google/auth.js';
import { createSheetsClient, type SheetsClient } from './google/sheets.js';
import { createDriveClient, type DriveClient } from './google/drive.js';
import { createCalendarClient, type CalendarClient } from './google/calendar.js';
import { USERS_SPREADSHEET_ID, getSessionSecret } from './config.js';
import { resolveDevice } from './devices.js';
import { verifySessionToken } from './crypto.js';
import { listUserNames } from './users.js';
import { loadSettings } from './settings.js';
import { listYears } from './attendance.js';
import { login } from './actions/login.js';
import { changePassword } from './actions/changePassword.js';
import { registerDevice } from './actions/registerDevice.js';
import { updateDeviceOwner } from './actions/updateDeviceOwner.js';
import { getAdminSettings, updateSettingsAction } from './actions/adminSettings.js';
import { getEventsAction } from './actions/getEvents.js';
import {
  insertRowsAction,
  selectByDateAction,
  selectByNameAction,
  selectByNameForYearAction,
  updateByIdAction,
} from './actions/attendanceActions.js';
import { fail, ok, type ActionResult } from './result.js';

/** 認証不要。端末登録の画面を出すために必要。 */
const PUBLIC_ACTIONS = ['getUsers', 'registerDevice', 'login'];

/** 登録済み端末からのみ実行できる操作。 */
const DEVICE_ACTIONS = ['getEvents', 'selectByDate', 'insertRows', 'updateById', 'listYears', 'getSettings'];

/** 端末トークンに加えて「本人であること」まで必要な操作。 */
const PERSONAL_ACTIONS = ['selectByName', 'selectByNameForYear'];

/** 端末トークンに加えて、現在のパスワードによる本人確認を行う操作。 */
const ACCOUNT_ACTIONS = ['changePassword', 'updateDeviceOwner', 'getAdminSettings', 'updateSettings'];

export interface DispatchServices {
  usersClient: SheetsClient;
  drive: DriveClient;
  calendar: CalendarClient;
  sheetsFactory: (spreadsheetId: string) => SheetsClient;
  sessionSecret: string;
}

/** 本番用のサービス一式を組み立てる。サービスアカウントの認証情報が必要。 */
export function createServices(): DispatchServices {
  const auth = getAuthClient();
  return {
    usersClient: createSheetsClient(auth, USERS_SPREADSHEET_ID),
    drive: createDriveClient(auth),
    calendar: createCalendarClient(auth),
    sheetsFactory: (spreadsheetId: string) => createSheetsClient(auth, spreadsheetId),
    sessionSecret: getSessionSecret(),
  };
}

interface RequestBody {
  action?: unknown;
  deviceToken?: unknown;
  token?: unknown;
  parameters?: { name?: unknown } & Record<string, unknown>;
  [key: string]: unknown;
}

/**
 * リクエスト本文（JSON文字列）を受け取り、action に応じて処理を振り分ける。
 * Auth.gs の doPost と同じ認可の順序・エラーコードを踏襲する。
 */
export async function dispatch(rawBody: string, services: DispatchServices): Promise<ActionResult<unknown>> {
  let body: RequestBody;
  try {
    if (!rawBody) {
      return fail('リクエストが空です', 'empty_request');
    }
    body = JSON.parse(rawBody);
  } catch {
    return fail('リクエストが空です', 'empty_request');
  }

  if (!body || typeof body !== 'object') {
    return fail('リクエストが空です', 'empty_request');
  }

  const action = typeof body.action === 'string' ? body.action : '';
  if (!action) {
    return fail('action が指定されていません', 'no_action');
  }

  // 各アクション関数は自分で型を検証・強制するため、ここでは境界として
  // unknown フィールドの塊として渡す。
  const untypedBody = body as Record<string, unknown>;

  try {
    if (action === 'getUsers') {
      return ok(await listUserNames(services.usersClient));
    }
    if (action === 'registerDevice') {
      return await registerDevice(services.usersClient, untypedBody);
    }
    if (action === 'login') {
      return await login(services.usersClient, services.sessionSecret, untypedBody);
    }

    const isDeviceAction = DEVICE_ACTIONS.includes(action);
    const isPersonalAction = PERSONAL_ACTIONS.includes(action);
    const isAccountAction = ACCOUNT_ACTIONS.includes(action);

    if (!isDeviceAction && !isPersonalAction && !isAccountAction) {
      return fail(`不明な action です: ${action}`, 'unknown_action');
    }

    // ここから先はすべて登録済み端末からの呼び出しであることが前提。
    const device = await resolveDevice(services.usersClient, body.deviceToken as string | undefined);
    if (!device) {
      return fail('この端末は登録されていません', 'device_unauthorized');
    }

    // パスワード変更・端末の名義変更・管理者設定は、パスワードそのもので
    // 本人確認するため、PERSONAL_ACTIONS のセッション判定は経由しない。
    if (action === 'changePassword') {
      return await changePassword(services.usersClient, untypedBody);
    }
    if (action === 'updateDeviceOwner') {
      return await updateDeviceOwner(services.usersClient, untypedBody);
    }
    if (action === 'getAdminSettings') {
      return await getAdminSettings(services.usersClient, untypedBody);
    }
    if (action === 'updateSettings') {
      return await updateSettingsAction(services.usersClient, untypedBody);
    }

    if (isPersonalAction) {
      const target = (body.parameters && body.parameters.name) || '';
      const isOwnDevice = device.user !== '' && device.user === target;

      if (!isOwnDevice) {
        const session = verifySessionToken(String(body.token ?? ''), services.sessionSecret);
        if (!session || session.name !== target) {
          return fail('本人確認が必要です', 'unauthorized');
        }
      }
    }

    const parameters = body.parameters ?? {};
    const result = await invokeDataAction(action, parameters, services);
    return ok(result);
  } catch (err) {
    console.error(err);
    return fail('サーバー内部エラー', 'internal_error');
  }
}

async function invokeDataAction(
  action: string,
  parameters: Record<string, unknown>,
  services: DispatchServices
): Promise<unknown> {
  switch (action) {
    case 'getEvents': {
      const years = await listYears(services.drive);
      const settings = await loadSettings(services.usersClient);
      return getEventsAction(services.calendar, settings.companyHolidayCalendarId, years);
    }
    case 'selectByDate':
      return selectByDateAction(services.drive, services.sheetsFactory, parameters);
    case 'insertRows':
      return insertRowsAction(services.drive, services.sheetsFactory, parameters);
    case 'updateById':
      return updateByIdAction(services.drive, services.sheetsFactory, parameters);
    case 'listYears':
      return listYears(services.drive);
    case 'getSettings':
      return loadSettings(services.usersClient);
    case 'selectByName':
      return selectByNameAction(services.drive, services.sheetsFactory, parameters);
    case 'selectByNameForYear':
      return selectByNameForYearAction(services.drive, services.sheetsFactory, parameters);
    default:
      // DEVICE_ACTIONS/PERSONAL_ACTIONS のホワイトリストと不整合がある場合のみ到達する。
      throw new Error(`未実装の action です: ${action}`);
  }
}
