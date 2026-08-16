/**
 * 勤怠管理 バックエンド — Google Apps Script Web アプリのエントリポイント。
 *
 * このファイルは「認証レイヤー」であり、データ操作そのものは既存の
 * insertRows / selectByDate / selectByName / updateById / getEvents に委譲する。
 * 既存関数はこのプロジェクトに既にあるものをそのまま使うため、ここには含めない。
 *
 * === なぜこの構成なのか ===
 * Flutter Web の成果物はすべてブラウザに配信されるため、クライアントには
 * いかなる秘密情報も置けない。OAuth の client secret / refresh token を
 * 持たせる代わりに、Web アプリを「実行するユーザー: 自分」でデプロイし、
 * スクリプトが所有者権限でサーバー側で動作するようにする。
 * これにより OAuth のやりとり自体が不要になる。
 *
 * デプロイ手順とユーザー登録は gas/README.md を参照。
 */

// ---------------------------------------------------------------------------
// 設定
// ---------------------------------------------------------------------------

/** セッションの有効期間(秒)。CacheService の上限は 21600 秒 (6時間)。 */
var TOKEN_TTL_SECONDS = 21600;

/** 認証不要。端末登録の画面を出すために必要。 */
var PUBLIC_ACTIONS = ['getUsers', 'registerDevice', 'login'];

/**
 * 登録済み端末からのみ実行できる操作。
 *
 * 端末トークンは localStorage に永続化されるため、利用者から見ると
 * 「最初の1回だけ端末登録すれば、以後は毎日そのまま打刻できる」動作になる。
 * 一方で URL を知っただけの第三者は端末トークンを持たないため何もできない。
 */
var DEVICE_ACTIONS = ['getEvents', 'selectByDate', 'insertRows', 'updateById'];

/**
 * 端末トークンに加えて「本人であること」まで必要な操作。
 *
 * 自分名義で登録した端末からは自分の分をそのまま開ける。
 * 共有端末（user が空）や他人の分を見る場合は、その人のパスワードで
 * ログインして得たセッショントークンが要る。
 */
var PERSONAL_ACTIONS = ['selectByName'];

// ---------------------------------------------------------------------------
// エントリポイント
// ---------------------------------------------------------------------------

/**
 * クライアントは Content-Type: text/plain で JSON 文字列を POST する。
 * application/json にすると CORS プリフライト(OPTIONS)が発生し、
 * GAS Web アプリは OPTIONS を処理できないため失敗する。
 */
function doPost(e) {
  try {
    if (!e || !e.postData || !e.postData.contents) {
      return fail_('リクエストが空です', 'empty_request');
    }

    var req = JSON.parse(e.postData.contents);
    var action = req.action;

    if (!action) {
      return fail_('action が指定されていません', 'no_action');
    }

    if (action === 'getUsers') {
      return ok_(listUserNames_());
    }

    if (action === 'registerDevice') {
      return handleRegisterDevice_(req);
    }

    if (action === 'login') {
      return handleLogin_(req);
    }

    var isDeviceAction = DEVICE_ACTIONS.indexOf(action) >= 0;
    var isPersonalAction = PERSONAL_ACTIONS.indexOf(action) >= 0;

    if (!isDeviceAction && !isPersonalAction) {
      return fail_('不明な action です: ' + action, 'unknown_action');
    }

    // ここから先はすべて登録済み端末からの呼び出しであることが前提。
    var device = resolveDevice_(req.deviceToken);
    if (!device) {
      return fail_('この端末は登録されていません', 'device_unauthorized');
    }

    if (isPersonalAction) {
      var target = (req.parameters && req.parameters.name) || '';

      // 自分名義の端末で自分の分を見る場合はパスワード不要。
      var isOwnDevice = device.user !== '' && device.user === target;

      if (!isOwnDevice) {
        var session = resolveSession_(req.token);
        if (!session || session.name !== target) {
          return fail_('本人確認が必要です', 'unauthorized');
        }
      }
    }

    return ok_(invokeDataFunction_(action, req.parameters));
  } catch (err) {
    // スタックトレースはクライアントに返さない。
    console.error(err && err.stack ? err.stack : err);
    return fail_('サーバー内部エラー', 'internal_error');
  }
}

/**
 * 既存のデータ操作関数を名前で呼び出す。
 * 呼び出せるのは上のホワイトリストで許可された名前のみ。
 */
function invokeDataFunction_(action, parameters) {
  var fn = globalThis[action];
  if (typeof fn !== 'function') {
    throw new Error('関数が未定義です: ' + action);
  }
  // 既存関数は fileName / sheetName / postData 等を持つオブジェクトを
  // 単一引数で受け取る前提。
  return fn(parameters || {});
}

// ---------------------------------------------------------------------------
// ログイン
// ---------------------------------------------------------------------------

function handleLogin_(req) {
  var name = req.name;
  var password = req.password;

  if (!name || !password) {
    return fail_('名前とパスワードを入力してください', 'invalid_credentials');
  }

  var record = loadUserRecord_(name);

  // 存在しないユーザーでも同じ比較経路を通し、応答の差で
  // ユーザーの存在有無が判別できないようにする。
  var expected = record ? record.password : '';
  var matched = timingSafeEqual_(String(password), expected);

  if (!record || !matched) {
    return fail_('名前またはパスワードが違います', 'invalid_credentials');
  }

  var token = issueToken_(name);
  return ok_({ token: token, name: name, expiresIn: TOKEN_TTL_SECONDS });
}

function issueToken_(name) {
  var token = Utilities.getUuid() + Utilities.getUuid();
  CacheService.getScriptCache().put(
    sessionKey_(token),
    JSON.stringify({ name: name }),
    TOKEN_TTL_SECONDS
  );
  return token;
}

function resolveSession_(token) {
  if (!token) {
    return null;
  }
  var raw = CacheService.getScriptCache().get(sessionKey_(token));
  if (!raw) {
    return null;
  }
  try {
    return JSON.parse(raw);
  } catch (err) {
    return null;
  }
}

function sessionKey_(token) {
  return 'session:' + token;
}

// ---------------------------------------------------------------------------
// ユーザー管理 (スプレッドシートの users シート)
// ---------------------------------------------------------------------------
//
// シート構成:
//   id | name | password
//
// ユーザーの追加・変更はスプレッドシートを直接編集する。
// 列は見出し行の名前で解決するため、列順が変わっても動作する。
//
// このシートはサーバー側でのみ読まれ、クライアントには名前しか渡らない。

/** ユーザー情報を保持するスプレッドシート。 */
var USERS_SPREADSHEET_ID = '1P3nX1XmpVqBLCB-BVgOGWG_U6a6vSr58YXeesvDvs68';
var USERS_SHEET_NAME = 'users';

var COLUMN_NAME = 'name';
var COLUMN_PASSWORD = 'password';

/**
 * users シートを読み、[{name, password}] を返す。
 *
 * パスワードが数値のみの場合 Sheets は number として返すため、
 * 比較前に必ず文字列化する。なお number 化により先頭の 0 は失われる
 * （"0123" は 123 になる）点に注意。
 */
function loadUsers_() {
  var book = SpreadsheetApp.openById(USERS_SPREADSHEET_ID);
  var sheet = book.getSheetByName(USERS_SHEET_NAME);
  if (!sheet) {
    throw new Error(USERS_SHEET_NAME + ' シートが見つかりません');
  }

  var values = sheet.getDataRange().getValues();
  if (values.length < 2) {
    return [];
  }

  var header = values[0].map(function (h) {
    return String(h).trim().toLowerCase();
  });
  var nameIndex = header.indexOf(COLUMN_NAME);
  var passwordIndex = header.indexOf(COLUMN_PASSWORD);

  if (nameIndex < 0 || passwordIndex < 0) {
    throw new Error(
      USERS_SHEET_NAME + ' シートに ' + COLUMN_NAME + ' / ' + COLUMN_PASSWORD + ' 列が必要です'
    );
  }

  var users = [];
  for (var i = 1; i < values.length; i++) {
    var name = String(values[i][nameIndex]).trim();
    if (!name) {
      continue;
    }
    users.push({
      name: name,
      password: String(values[i][passwordIndex]).trim()
    });
  }
  return users;
}

/** ログイン画面に出す名前の一覧。パスワードは一切返さない。 */
function listUserNames_() {
  return loadUsers_().map(function (u) {
    return u.name;
  });
}

function loadUserRecord_(name) {
  var users = loadUsers_();
  for (var i = 0; i < users.length; i++) {
    if (users[i].name === name) {
      return users[i];
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// 端末管理 (同じスプレッドシートの devices シート)
// ---------------------------------------------------------------------------
//
// シート構成（初回登録時に自動生成される）:
//   token_hash | user | label | created | last_used | revoked
//
// token_hash : 端末トークンの SHA-256。生の値は保存しないので、
//              シートが漏れても他人の端末として振る舞うことはできない。
// user       : 所有者の名前。空欄なら共有端末。
//              自分名義の端末からは、自分のタイムカードをパスワードなしで開ける。
// revoked    : TRUE にするとその端末だけ即座に締め出せる（端末の紛失・入替用）。

var DEVICES_SHEET_NAME = 'devices';
var DEVICE_HEADER = ['token_hash', 'user', 'label', 'created', 'last_used', 'revoked'];

/** 端末検証結果のキャッシュ秒数。revoke の反映もこの分だけ遅れる。 */
var DEVICE_CACHE_SECONDS = 60;

function devicesSheet_() {
  var book = SpreadsheetApp.openById(USERS_SPREADSHEET_ID);
  var sheet = book.getSheetByName(DEVICES_SHEET_NAME);
  if (!sheet) {
    sheet = book.insertSheet(DEVICES_SHEET_NAME);
    sheet.appendRow(DEVICE_HEADER);
  }
  return sheet;
}

function deviceColumnIndexes_(header) {
  var lower = header.map(function (h) {
    return String(h).trim().toLowerCase();
  });
  return {
    tokenHash: lower.indexOf('token_hash'),
    user: lower.indexOf('user'),
    revoked: lower.indexOf('revoked'),
    lastUsed: lower.indexOf('last_used')
  };
}

/**
 * 端末トークンを検証する。
 * 有効なら { user: 所有者名 or '' } を返し、無効なら null。
 */
function resolveDevice_(token) {
  if (!token) {
    return null;
  }

  var hash = sha256Hex_(token);
  var cache = CacheService.getScriptCache();
  var cacheKey = 'device:' + hash;

  var cached = cache.get(cacheKey);
  if (cached) {
    return JSON.parse(cached);
  }

  var sheet = devicesSheet_();
  var values = sheet.getDataRange().getValues();
  if (values.length < 2) {
    return null;
  }

  var col = deviceColumnIndexes_(values[0]);
  if (col.tokenHash < 0) {
    return null;
  }

  for (var i = 1; i < values.length; i++) {
    if (String(values[i][col.tokenHash]).trim() !== hash) {
      continue;
    }

    var revoked = String(values[i][col.revoked]).trim().toUpperCase();
    if (revoked === 'TRUE' || revoked === '1' || revoked === 'はい') {
      return null;
    }

    touchDeviceLastUsed_(sheet, i + 1, col.lastUsed, values[i][col.lastUsed]);

    var device = { user: String(values[i][col.user] || '').trim() };
    cache.put(cacheKey, JSON.stringify(device), DEVICE_CACHE_SECONDS);
    return device;
  }

  return null;
}

/**
 * 最終利用日を更新する。毎リクエスト書き込むとシートが競合するため、
 * 日付が変わったときだけ書く。
 */
function touchDeviceLastUsed_(sheet, rowNumber, columnIndex, current) {
  if (columnIndex < 0) {
    return;
  }
  var today = Utilities.formatDate(new Date(), 'Asia/Tokyo', 'yyyy/MM/dd');
  if (String(current).indexOf(today) === 0) {
    return;
  }
  try {
    sheet.getRange(rowNumber, columnIndex + 1).setValue(today);
  } catch (err) {
    // 監査用の情報なので、書けなくても認証は通す。
    console.warn('last_used を更新できませんでした: ' + err);
  }
}

/**
 * 端末を登録する。登録には既存ユーザーのパスワードが必要。
 * 発行したトークンはこの応答でしか返さない（サーバーはハッシュしか保持しない）。
 */
function handleRegisterDevice_(req) {
  var name = req.name;
  var password = req.password;

  if (!name || !password) {
    return fail_('名前とパスワードを入力してください', 'invalid_credentials');
  }

  var record = loadUserRecord_(name);
  var expected = record ? record.password : '';
  if (!record || !timingSafeEqual_(String(password), expected)) {
    return fail_('名前またはパスワードが違います', 'invalid_credentials');
  }

  var token = Utilities.getUuid() + Utilities.getUuid();
  var shared = req.shared === true;

  devicesSheet_().appendRow([
    sha256Hex_(token),
    shared ? '' : name,
    String(req.label || '').trim(),
    Utilities.formatDate(new Date(), 'Asia/Tokyo', 'yyyy/MM/dd HH:mm:ss'),
    '',
    'FALSE'
  ]);

  return ok_({ token: token, user: shared ? '' : name, shared: shared });
}

// ---------------------------------------------------------------------------
// パスワード照合
// ---------------------------------------------------------------------------
//
// シートには平文で保存されているため、そのまま比較する。
// シートはサーバー側でのみ読まれ、クライアントには渡らない。

/** 端末トークンの保存用。生の値をシートに残さないために使う。 */
function sha256Hex_(value) {
  var bytes = Utilities.computeDigest(
    Utilities.DigestAlgorithm.SHA_256,
    String(value),
    Utilities.Charset.UTF_8
  );
  var hex = '';
  for (var i = 0; i < bytes.length; i++) {
    // GAS の computeDigest は符号付きバイトを返すため 0-255 に戻す。
    var b = (bytes[i] + 256) % 256;
    hex += (b < 16 ? '0' : '') + b.toString(16);
  }
  return hex;
}

/** 文字単位の差分を全て走査し、一致位置による処理時間の差を作らない。 */
function timingSafeEqual_(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string' || a.length !== b.length) {
    return false;
  }
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

// ---------------------------------------------------------------------------
// レスポンス
// ---------------------------------------------------------------------------

function ok_(result) {
  return jsonResponse_({ ok: true, result: result });
}

function fail_(message, code) {
  return jsonResponse_({ ok: false, error: message, code: code });
}

function jsonResponse_(payload) {
  return ContentService.createTextOutput(JSON.stringify(payload)).setMimeType(
    ContentService.MimeType.JSON
  );
}
