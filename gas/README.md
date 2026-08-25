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

ユーザー情報は**スプレッドシートの `users` シート**で管理する。
コードやスクリプトプロパティを触る必要はなく、シートを編集するだけでよい。

[対象スプレッドシート](https://docs.google.com/spreadsheets/d/1P3nX1XmpVqBLCB-BVgOGWG_U6a6vSr58YXeesvDvs68/edit)

| id | name | password | role |
|---|---|---|---|
| 1 | 八木 | 1111 | admin |
| 2 | 大滝 | … | |

- 追加・変更・削除はシートの行を編集するだけ。再デプロイは不要
- 列は**見出し行の名前で解決**するため、列順を変えても動作する
- `name` が空の行は無視される
- シートはサーバー側でのみ読まれ、クライアントには**名前しか渡らない**
- `role` 列は省略可能。値が `admin` の行だけ管理者として扱われ、
  それ以外（空欄・`user` など）は一般利用者になる

### 管理者ロール

管理者（`role` が `admin`）だけが、端末を**共有端末**にできる
（端末登録画面の「共有端末として登録する」、右上メニュー → 端末の設定の
「共有端末として使う」）。一般利用者がこれらのチェックを付けて送信すると
サーバーが `admin_required` で拒否する。

共有端末から個人名義に戻す操作（本人確認込み）は誰でもできる。
制限されるのは「共有端末にする」方向だけ。

個人名義の端末では、打刻対象の名前は自動的にその端末の名義になり、
画面下部の名前選択ボタンは表示されない（共有端末でのみ表示される）。

スプレッドシート ID とシート名は [Auth.gs](Auth.gs) の
`USERS_SPREADSHEET_ID` / `USERS_SHEET_NAME` で変更できる。

### パスワードの変更

利用者自身がアプリから変更できる（右上のメニュー → **パスワードの変更**）。
現在のパスワードを知っていることが条件で、登録済みの端末からのみ実行できる。

新しいパスワードは `Auth.gs` の `MIN_PASSWORD_LENGTH`（6文字）以上が必要。
端末トークンの導入でパスワードを日常的に打つ必要がなくなったため、
以前の4桁数字より長くしても運用の負担にならない。

アプリ経由で変更した場合、セルは文字列書式で書かれるため
先頭が 0 のパスワードもそのまま保持される。

### 注意点

**パスワードは平文で保存されている。** シート自体はサーバー側（オーナーのみ
アクセス可）にあるためクライアントには漏れないが、シートの共有範囲を広げると
そのままパスワードが読める状態になる。共有設定は変更しないこと。

**シートに直接入力する場合、先頭の 0 は失われる。** Sheets は数字のみの値を
数値として扱うため、`0123` は `123` になる。セルの書式を文字列にしておくか、
アプリのパスワード変更機能を使う（そちらは書式を明示的に設定している）。

**短いパスワードは総当たりに弱い。** `registerDevice` は公開エンドポイントで
試行回数の制限がない。4桁数字なら組み合わせは1万通りしかない。
アプリからの変更では6文字以上を強制しているが、シートに直接書く場合は
検証されないので注意する。

<details>
<summary>旧方式（スクリプトプロパティ）からの移行について</summary>

以前はスクリプトプロパティにソルト付きハッシュを保存し、`upsertUser` /
`deleteUser` で管理していた。現在はスプレッドシート方式に一本化しており、
これらの関数と `USER_INDEX` / `USER_<名前>` プロパティは使われていない。
古いプロパティが残っている場合は「プロジェクトの設定 → スクリプト プロパティ」
から削除してよい。

</details>

### 初回のみ権限承認が必要

スクリプトがスプレッドシートを読むには、オーナーによる承認が要る。
まだ承認していない場合、エディタで任意の関数を実行すると承認画面が出る。

1. **権限を確認** を押す
2. アカウントを選ぶ
3. 「このアプリは Google で確認されていません」と出たら
   **詳細** → **（プロジェクト名）に移動（安全ではないページ）**
4. **許可** を押す

自分が作ったスクリプトを自分の権限で動かすだけなので、この警告は想定通り。

> Google アカウントのサードパーティアクセスからこの承認を取り消すと、
> `executeAs: USER_DEPLOYING` の Web アプリは実行主体を失い、
> `/exec` が **403** を返すようになる。その場合は上の手順で承認をやり直す。
> 再デプロイは不要。

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

> **`clasp deploy -i` はアクセス設定を変更しない。**
> 更新されるのはバージョンだけで、「アクセスできるユーザー」はデプロイ作成時の
> 設定が保持される。`appsscript.json` に `"access": "ANYONE_ANONYMOUS"` があっても、
> 既存デプロイには反映されない。
>
> アクセス設定が「全員」以外のままだと、`/exec` への POST は
> Google Drive の「アクセスが拒否されました」ページと共に **403** を返す。
> 変更はエディタの **デプロイを管理 → 鉛筆アイコン → アクセスできるユーザー**
> から行う（この項目は API / clasp からは変更できない）。

> **デプロイ数の上限は 20。**
> 超えると `clasp deploy` が
> `Scripts may only have up to 20 versioned deployments at a time.` で失敗する。
> 不要なものは `clasp undeploy <デプロイID>` で削除する。

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

`code` の値: `invalid_credentials` / `unauthorized` / `admin_required` /
`unknown_action` / `no_action` / `empty_request` / `internal_error`

## アクセス制御

「端末を信頼する」方式を採っている。**打刻のたびのログインは不要**だが、
Web アプリ URL を知っただけの第三者はデータに一切触れられない。

```javascript
var PUBLIC_ACTIONS   = ['getUsers', 'registerDevice', 'login'];
var DEVICE_ACTIONS   = ['getEvents', 'selectByDate', 'insertRows', 'updateById'];
var PERSONAL_ACTIONS = ['selectByName'];
```

| 区分 | 必要なもの |
|---|---|
| `PUBLIC_ACTIONS` | なし（端末登録画面を出すために必要） |
| `DEVICE_ACTIONS` | 有効な端末トークン |
| `PERSONAL_ACTIONS` | 端末トークン + 本人であること |

### 端末トークン

初回だけ端末登録を行うと、サーバーが長命なトークンを発行する。
クライアントはこれを `localStorage` に保存するため、ブラウザを閉じても
PC を再起動しても、アプリを再デプロイしても保持される。

サーバー側は `devices` シートに **SHA-256 ハッシュのみ**を保存する。
シートが漏れても、そこから他人の端末として振る舞うことはできない。

### 本人確認

`selectByName`（タイムカード）は個人データなので、端末トークンだけでは足りない。

- **自分名義で登録した端末から自分の分を見る** → パスワード不要
- **共有端末から、または他人の分を見る** → その人のパスワードでログインが必要
  （`TOKEN_TTL_SECONDS` = 6時間有効なセッション）

クライアントは条件を判定せず、まず開こうとして `unauthorized` が返ったときに
初めてパスワードを要求する。権限判定をサーバーに一本化するためである。

### 端末の管理

`devices` シートは初回登録時に自動生成される。

| 列 | 内容 |
|---|---|
| `token_hash` | 端末トークンの SHA-256 |
| `user` | 所有者の名前。**空欄なら共有端末** |
| `label` | 端末の名前（任意）。「事務所PC」「八木のiPhone」など |
| `created` | 登録日時 |
| `last_used` | 最終利用日（日付が変わったときだけ更新） |
| `revoked` | `TRUE` にするとその端末を締め出す |

共有端末と個人端末の切り替えは、アプリの右上メニュー → **端末の設定** から行える
（`user` 列を直接編集してもよい）。名義を変えるとその人のタイムカードを
パスワードなしで開けるようになるため、変更にはその人のパスワードが要る。

**端末を紛失・入れ替えたときは `revoked` を `TRUE` にする。**
反映は最大 `DEVICE_CACHE_SECONDS`（60秒）遅れる。締め出された端末は
次回アクセス時にローカルのトークンを破棄し、登録画面に戻る。

### 注意点

**ブラウザ・プロファイル単位**である。別のブラウザやシークレットウィンドウ、
ブラウザデータの削除後は再登録が必要になる。

**iOS / iPadOS の Safari** は、7日間アクセスがないと localStorage を
自動削除することがある（ITP）。毎日使う端末なら問題にならないが、
予備端末では再登録が発生し得る。

**XSS には注意**。localStorage は同一オリジンの JS から読めるため、
外部スクリプトを読み込むとトークンを盗まれ得る。現状このアプリは
自前コードのみで CDN も使っていない。
