# GAS バックエンド

Flutter アプリのバックエンドとなる Google Apps Script 側の設定手順。

[Auth.gs](Auth.gs) は認証レイヤーで、データ操作そのものは既存の
`insertRows` / `selectByDate` / `selectByName` / `updateById` / `getEvents` に委譲する。
このファイルを既存の Apps Script プロジェクトに **追加** する（既存関数は消さない）。

## 設計方針

クライアントに秘密情報を置かないため、Web アプリを「実行するユーザー: 自分」で
デプロイし、スクリプトが所有者権限でサーバー側で動くようにする。
これにより OAuth の client secret / refresh token が不要になる。

パスワードはスクリプトプロパティ（サーバー側ストレージ）にソルト付きハッシュで保存し、
照合も GAS 側で行う。クライアントには名前の一覧のみを返す。

## 1. 資格情報の失効（最初にやる）

移行前に、既に露出している資格情報を無効化する。ソースを直しても、
失効させるまで古い資格情報は有効なままである。

1. [Google アカウント → セキュリティ → サードパーティ アプリとの連携](https://myaccount.google.com/connections)
   から対象アプリのアクセスを削除し、リフレッシュトークンを失効させる
2. [Google Cloud Console → API とサービス → 認証情報](https://console.cloud.google.com/apis/credentials)
   で OAuth クライアントの client secret を再発行し、古い secret を削除する

## 2. clasp のセットアップと Auth.gs の反映

Apps Script のコードは [clasp](https://github.com/google/clasp) で git 管理し、
ローカル編集 → `clasp push` で反映する。エディタへのコピペは不要。

clasp は Docker コンテナで動くため、ホストに Node.js を入れる必要はない。

```sh
docker compose run --rm clasp <サブコマンド>
```

### 2-1. Apps Script API を有効化

https://script.google.com/home/usersettings を開き、
**Google Apps Script API** を **オン** にする。

これを忘れると `clasp push` が `User has not enabled the Apps Script API` で失敗する。

### 2-2. ログイン

```sh
docker compose run --rm --service-ports clasp login
```

**`--service-ports` は必須。** `docker compose run` は通常ポートを publish しないため、
これが無いと承認後のリダイレクトがコンテナに届かず、ブラウザが
「接続できません」で止まる。

表示された `https://accounts.google.com/o/oauth2/...` をホストのブラウザで開いて承認する。
コンテナ内にブラウザが無いので自動では開かない。URL は手動でコピーする。

承認すると `http://localhost:3001` にリダイレクトされ、
コンテナ側のサーバーが受け取ってログインが完了する。

> **同意画面では権限をすべて許可すること。**
> チェックボックスが並ぶ画面で「すべて選択」を押さずに進むと、
> `openid` / `userinfo.email` / `userinfo.profile` だけが付与され、
> Apps Script 系のスコープが欠けた状態でログインが「成功」してしまう。
> この状態だと `clone` は `Could not find script`、
> `list` は `Insufficient Permission` で失敗する。

認証情報は `clasp-auth` という Docker volume に保存され、リポジトリには入らない。
以降のコマンドで再ログインは不要。

付与されたスコープは次のコマンドで確認できる。

```sh
docker compose run --rm -T --entrypoint node clasp \
  -e "const c=require('/claspauth/.clasprc.json');console.log(c.token.scope)"
```

`script.projects` が含まれていなければ、やり直す。

```sh
docker compose run --rm -T clasp logout
docker compose run --rm --service-ports clasp login
```

> **`--no-localhost` は使えない。**
> このオプションが使う OOB フロー（`urn:ietf:wg:oauth:2.0:oob`）は
> Google が 2022 年に廃止しており、`エラー 400: invalid_request` になる。
>
> なお clasp は本来ランダムポートで待ち受ける（`auth.js` の `listen(0)`）ため、
> そのままではポートを publish できない。[Dockerfile](Dockerfile) でこれを
> 3001 に固定している。

### 2-3. 既存プロジェクトを取り込む

エディタの URL からスクリプト ID を調べる。

```
https://script.google.com/home/projects/★スクリプトID★/edit
```

（エディタ左の歯車 **プロジェクトの設定** → **スクリプト ID** でも確認できる。
Web アプリ URL に含まれる `AKfycb...` は「デプロイ ID」であり別物。）

取り込む前に、いまの `gas/` をコミットしておく。
こうすると `clasp clone` が何を持ってきたかが `git diff` で正確に分かる。

```sh
git add gas/ && git commit -m "add GAS auth layer and clasp environment"

docker compose run --rm clasp clone <スクリプトID>
```

既存の `insertRows` / `selectByDate` / `selectByName` / `updateById` / `getEvents`
などが `gas/` に降りてくる。**これらは現状 GAS エディタ上にしか存在せず
バージョン管理されていない**ため、この時点で初めて git の管理下に入る。

`appsscript.json`（マニフェスト）と `.clasp.json`（スクリプト ID を保持）も生成される。
`.clasp.json` はコミットしてよい。

> このリポジトリの認証レイヤーを `Auth.gs` という名前にしてあるのは、
> 既存プロジェクトの `Code.gs` と衝突させないため。同名だと push 時に
> 既存のデータ関数を上書き破壊してしまう。

### 2-4. 反映

```sh
# 差分を確認してから
docker compose run --rm clasp status

docker compose run --rm clasp push
```

`clasp push` はローカルの内容でリモートを**置き換える**。
`clasp pull` でエディタ側の変更を取り込めるが、ローカルの変更は失われる。
エディタとローカルの両方で編集すると競合するので、**編集はローカルに一本化する**。

## 3. ユーザーの登録

`upsertUser(name, password)` は引数を取るが、スクリプトエディタの実行ボタンは
引数を渡せない。そのため一時的な呼び出し用関数を作って実行する。

### 3-1. 一時関数を書く

`Auth.gs` の末尾に以下を追記する。パスワードは全員分、新しい値に決めておく。

```javascript
// 実行後、この関数は必ず削除する（平文パスワードをソースに残さないため）
function setupUsers() {
  upsertUser('八木', '新しいパスワード1');
  upsertUser('大滝', '新しいパスワード2');
  upsertUser('山本', '新しいパスワード3');
  upsertUser('広瀬', '新しいパスワード4');
  upsertUser('坂下', '新しいパスワード5');
  upsertUser('西本', '新しいパスワード6');
  upsertUser('関屋', '新しいパスワード7');
}
```

旧パスワード（`tyagi` / `kotaki` など）は git 履歴に残っているため、
**同じものを再利用してはいけない。**

### 3-2. 保存して実行

1. `Ctrl + S` で保存する（保存しないと次の手順の一覧に出てこない）
2. エディタ上部の実行対象のプルダウンで **`setupUsers`** を選ぶ
3. **実行** を押す

> プルダウンに `hashPassword_` などが出てこないのは、GAS では末尾が `_` の関数が
> 非公開扱いになるため。意図通りの挙動。

### 3-3. 初回のみ権限承認が出る

「承認が必要です」と表示されたら:

1. **権限を確認** を押す
2. アカウントを選ぶ
3. 「このアプリは Google で確認されていません」と出たら
   **詳細** → **（プロジェクト名）に移動（安全ではないページ）**
4. **許可** を押す

自分が作ったスクリプトを自分の権限で動かすだけなので、この警告は想定通り。

### 3-4. 結果を確認

画面下の **実行ログ** に以下が出れば成功。

```
登録しました: 八木
登録しました: 大滝
...
```

左サイドバーの歯車 **プロジェクトの設定** → 下部の **スクリプト プロパティ** で
実際の保存内容も確認できる。

| プロパティ | 値の例 |
|---|---|
| `USER_INDEX` | `["八木","大滝","山本",...]` |
| `USER_八木` | `{"salt":"a1b2...","hash":"9f3c...","iterations":10000}` |

`hash` がハッシュ値になっていて、平文パスワードがどこにも無いことを確認する。

### 3-5. 一時関数を削除する（重要）

`setupUsers()` を丸ごと消して `Ctrl + S` で保存する。
消し忘れると平文パスワードがスクリプト上に残り続ける。

以降ユーザーを追加・変更したいときは、都度この一時関数を作って実行し、また消す。
削除は同じ手順で `deleteUser('名前')` を呼ぶ。

> `HASH_ITERATIONS` は 10000 回。登録やログインに数秒かかる場合はこの値を下げる。
> 変更した場合、既存ユーザーは登録し直しが必要（保存済みの `iterations` が使われる）。

## 4. Web アプリとしてデプロイ

### 4-1. デプロイを作成

1. エディタ右上の **デプロイ** → **新しいデプロイ**
2. 左上の歯車 **種類の選択** → **ウェブアプリ**
3. 各項目を設定する

| 項目 | 値 |
|---|---|
| 説明 | 任意（例: `勤怠管理 v1`） |
| 次のユーザーとして実行 | **自分** |
| アクセスできるユーザー | **全員** |

4. **デプロイ** を押す

「次のユーザーとして実行: 自分」がこの構成の核心で、これによりスクリプトが
所有者権限でサーバー側で動き、クライアントに認証情報が不要になる。

「アクセスできるユーザー: 全員」は、独自ログイン方式（Google アカウントに
依存しない）のため必要。アクセス制御は `Auth.gs` のトークン検証で行う。

### 4-2. URL を取得

表示された **ウェブアプリ** の URL をコピーする。

```
https://script.google.com/macros/s/AKfycb.../exec
```

末尾が `/exec` であることを確認する。`/dev` の URL はログイン必須で
アプリからは使えない。

### 4-3. 動作確認

アプリに組み込む前に、PowerShell から直接叩いて確認する。

```powershell
$url = "https://script.google.com/macros/s/.../exec"

# 名前一覧（認証不要）
Invoke-RestMethod -Uri $url -Method Post `
  -ContentType "text/plain;charset=utf-8" `
  -Body '{"action":"getUsers"}'
```

期待する結果:

```
ok result
-- ------
True {八木, 大滝, 山本...}
```

ログインも確認する。日本語を含むので UTF-8 バイト列で送る。

```powershell
$body = [System.Text.Encoding]::UTF8.GetBytes(
  '{"action":"login","name":"八木","password":"新しいパスワード1"}')

Invoke-RestMethod -Uri $url -Method Post `
  -ContentType "text/plain;charset=utf-8" -Body $body
```

`ok: True` とトークンが返れば成功。パスワードを間違えると
`ok: False` / `code: invalid_credentials` が返る。

### 4-4. URL をアプリに設定

[app/lib/application/constants.dart](../app/lib/application/constants.dart) の
`webAppUrl` の `defaultValue` を取得した URL に書き換える。

```dart
static const String webAppUrl = String.fromEnvironment(
  'GAS_WEB_APP_URL',
  defaultValue: 'https://script.google.com/macros/s/.../exec',
);
```

URL 自体は秘密情報ではない（漏れても所有者権限が奪われるわけではない）。
ただし現在の設定では打刻データの読み書きが認証不要なので、
**リポジトリが公開されている場合は URL をコミットしないほうがよい。**
その場合は `--dart-define=GAS_WEB_APP_URL=...` でビルド時に渡す方式にする
（Dockerfile と GitHub Actions 側の対応が別途必要）。

### 4-5. コード変更時の再デプロイ

`Auth.gs` を編集しても、再デプロイしないと `/exec` は古いコードを返す。
`clasp push` はコードを送るだけで、デプロイは更新されない点に注意。

```sh
docker compose run --rm clasp push

# 既存デプロイを新バージョンに更新する（URL は変わらない）
docker compose run --rm clasp deployments          # デプロイ ID を確認
docker compose run --rm clasp deploy -i <デプロイID> -d "説明"
```

エディタから行う場合は **デプロイを管理** → 対象の行の鉛筆アイコン →
**バージョン: 新バージョン** → **デプロイ**。

いずれの方法でも、**「新しいデプロイ」を作ると URL が変わる**。
[constants.dart](../app/lib/application/constants.dart) の `webAppUrl` を
変えたくない場合は、必ず既存デプロイの更新を選ぶ。

## 5. CORS についての注意

クライアントは `Content-Type: text/plain` で JSON を POST する。
`application/json` にすると CORS プリフライト（OPTIONS）が発生するが、
GAS Web アプリは OPTIONS を処理できないためリクエストが失敗する。

`text/plain` は CORS セーフリストの Content-Type なのでプリフライトが起きない。
GAS 側は `e.postData.contents` から本文を読むため、この指定でも問題なく動作する。

## リクエスト・レスポンス形式

リクエスト:

```json
{ "action": "selectByName", "token": "<セッショントークン>", "parameters": { "fileName": "2026年", "sheetName": "8月", "name": "八木" } }
```

レスポンス:

```json
{ "ok": true, "result": [ ... ] }
{ "ok": false, "error": "ログインが必要です", "code": "unauthorized" }
```

`code` の値: `invalid_credentials` / `unauthorized` / `unknown_action` /
`no_action` / `empty_request` / `internal_error`

## アクセス制御の方針（意図的な設定）

`Auth.gs` の `OPEN_DATA_ACTIONS` に含まれる操作は**ログイン不要**である。

```javascript
var OPEN_DATA_ACTIONS = ['getEvents', 'selectByDate', 'insertRows', 'updateById'];
var PROTECTED_ACTIONS = ['selectByName'];
```

打刻をログインなしで行える UX を優先した、意図的な設定である（設定漏れではない）。

### 受け入れているリスク

このアプリは公開リポジトリから GitHub Pages に配信されており、ビルド成果物に
Web アプリ URL が埋め込まれる。サイトを開けば URL を読み出せるため、
**URL は事実上公開されている**。

したがって `OPEN_DATA_ACTIONS` の操作は誰でも実行でき、打刻データの
追加・書き換え・削除が第三者に可能である（`updateById` は削除にも使われる）。
この状態を承知のうえで採用している。

### 方針を変える場合

対象を `PROTECTED_ACTIONS` に移し、クライアント側も起動時ログインを必須にする。

セッションは `TOKEN_TTL_SECONDS`（6時間）有効なので、共有端末であれば
始業時に1回ログインすれば終業まで保つ。打刻のたびの入力にはならない。
