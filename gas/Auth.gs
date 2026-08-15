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

/** 認証不要。ログイン画面を出すために必要。 */
var PUBLIC_ACTIONS = ['getUsers', 'login'];

/**
 * ログイン不要で呼べるデータ操作。
 *
 * === これは意図的な設定である（見落としではない） ===
 * 打刻をログインなしで行える UX を優先し、認証を課さない選択をしている。
 *
 * ただし前提として、アプリは公開リポジトリから GitHub Pages に配信されており、
 * ビルド成果物にこの Web アプリ URL が埋め込まれる。つまり URL は事実上公開で、
 * ここに列挙した操作は誰でも実行できる。打刻データの追加・書き換え・削除
 * （updateById は削除にも使われる）が第三者に可能な状態を受け入れている。
 *
 * 方針を変える場合は、対象を PROTECTED_ACTIONS へ移し、
 * クライアント側も起動時ログインを必須にする。
 * セッションは TOKEN_TTL_SECONDS (6時間) 有効なので、共有端末なら
 * 始業時に1回ログインすれば終業まで保つ。
 */
var OPEN_DATA_ACTIONS = ['getEvents', 'selectByDate', 'insertRows', 'updateById'];

/** 有効なセッショントークンが必須のデータ操作。 */
var PROTECTED_ACTIONS = ['selectByName'];

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

    if (action === 'login') {
      return handleLogin_(req);
    }

    var isOpen = OPEN_DATA_ACTIONS.indexOf(action) >= 0;
    var isProtected = PROTECTED_ACTIONS.indexOf(action) >= 0;

    if (!isOpen && !isProtected) {
      return fail_('不明な action です: ' + action, 'unknown_action');
    }

    if (isProtected) {
      var session = resolveSession_(req.token);
      if (!session) {
        return fail_('ログインが必要です', 'unauthorized');
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
// パスワード照合
// ---------------------------------------------------------------------------
//
// シートには平文で保存されているため、そのまま比較する。
// シートはサーバー側でのみ読まれ、クライアントには渡らない。

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
