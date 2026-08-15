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

/** パスワードハッシュの反復回数。増やすほど総当たりに強いがログインが遅くなる。 */
var HASH_ITERATIONS = 10000;

/** 認証不要。ログイン画面を出すために必要。 */
var PUBLIC_ACTIONS = ['getUsers', 'login'];

/**
 * ログイン不要で呼べるデータ操作。
 *
 * 現状のアプリは打刻をログインなしで行える UX のため、既定ではここに置いている。
 * つまり Web アプリ URL を知っていれば打刻データの読み書きは可能な状態である。
 * これを塞ぐには、対象を PROTECTED_ACTIONS へ移し、
 * クライアント側も起動時ログインを必須にする必要がある。
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

  // ユーザーが存在しない場合もハッシュ計算を行い、応答時間の差で
  // ユーザーの存在有無が判別できないようにする。
  var salt = record ? record.salt : 'dummy-salt-for-timing';
  var iterations = record ? record.iterations : HASH_ITERATIONS;
  var computed = hashPassword_(password, salt, iterations);

  if (!record || !timingSafeEqual_(computed, record.hash)) {
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
// ユーザー管理 (スクリプトプロパティに保存)
// ---------------------------------------------------------------------------
//
// 保存形式:
//   USER_INDEX      -> ["八木","大滝", ...]                 表示用の名前一覧
//   USER_<名前>     -> {"salt":"..","hash":"..","iterations":10000}
//
// スクリプトプロパティはサーバー側ストレージであり、クライアントには渡らない。

var USER_INDEX_KEY = 'USER_INDEX';

function userKey_(name) {
  return 'USER_' + name;
}

/** ログイン画面に出す名前の一覧。パスワード情報は一切返さない。 */
function listUserNames_() {
  var raw = PropertiesService.getScriptProperties().getProperty(USER_INDEX_KEY);
  if (!raw) {
    return [];
  }
  try {
    return JSON.parse(raw);
  } catch (err) {
    return [];
  }
}

function loadUserRecord_(name) {
  var raw = PropertiesService.getScriptProperties().getProperty(userKey_(name));
  if (!raw) {
    return null;
  }
  try {
    var record = JSON.parse(raw);
    if (!record.salt || !record.hash) {
      return null;
    }
    record.iterations = record.iterations || HASH_ITERATIONS;
    return record;
  } catch (err) {
    return null;
  }
}

/**
 * ユーザーを登録・更新する。スクリプトエディタから手動で実行する用。
 * 使い方は gas/README.md を参照。
 */
function upsertUser(name, password) {
  if (!name || !password) {
    throw new Error('name と password は必須です');
  }

  var salt = Utilities.getUuid();
  var record = {
    salt: salt,
    hash: hashPassword_(password, salt, HASH_ITERATIONS),
    iterations: HASH_ITERATIONS
  };

  var props = PropertiesService.getScriptProperties();
  props.setProperty(userKey_(name), JSON.stringify(record));

  var names = listUserNames_();
  if (names.indexOf(name) < 0) {
    names.push(name);
    props.setProperty(USER_INDEX_KEY, JSON.stringify(names));
  }

  console.log('登録しました: ' + name);
}

/** ユーザーを削除する。スクリプトエディタから手動で実行する用。 */
function deleteUser(name) {
  var props = PropertiesService.getScriptProperties();
  props.deleteProperty(userKey_(name));

  var names = listUserNames_().filter(function (n) {
    return n !== name;
  });
  props.setProperty(USER_INDEX_KEY, JSON.stringify(names));

  console.log('削除しました: ' + name);
}

// ---------------------------------------------------------------------------
// パスワードハッシュ
// ---------------------------------------------------------------------------
//
// GAS には bcrypt / scrypt / PBKDF2 が無いため、ソルト付き SHA-256 の
// 反復で代替している。専用のパスワードハッシュ関数より弱いことは事実だが、
// 平文保存や無反復ハッシュよりは総当たり耐性が大きく向上する。
// 反復回数は HASH_ITERATIONS で調整できる。

function hashPassword_(password, salt, iterations) {
  var digest = salt + ':' + password;
  for (var i = 0; i < iterations; i++) {
    var bytes = Utilities.computeDigest(
      Utilities.DigestAlgorithm.SHA_256,
      digest,
      Utilities.Charset.UTF_8
    );
    digest = bytesToHex_(bytes);
  }
  return digest;
}

function bytesToHex_(bytes) {
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


function setupUsers() {
  upsertUser('八木', '1111');
}
