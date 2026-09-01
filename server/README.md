# attendance_manager backend (Vercel Functions)

GAS Webアプリの後継バックエンド。データは今まで通りGoogleスプレッドシートに
置いたまま、実行層だけをVercel Functions (Node.js) に差し替えたもの。
背景・設計判断は [docs/adr/](../docs/adr/) を参照。

Flutterクライアント（`app/`）との通信仕様は`gas/Auth.gs`と完全互換
（1エンドポイントへのPOST、`action`ベースのディスパッチ、
`{ok:true,result}` / `{ok:false,error,code}` のレスポンス形式）。

## 構成

```
server/
├── api/exec.ts          唯一のエンドポイント（POST /api/exec）
├── src/
│   ├── dispatch.ts        action のディスパッチ本体（doPost 相当）
│   ├── config.ts          定数・環境変数
│   ├── crypto.ts          ハッシュ・タイミングセーフ比較・セッショントークン
│   ├── users.ts           users シート
│   ├── devices.ts         devices シート（端末トークン）
│   ├── settings.ts        settings シート（管理者設定）
│   ├── attendance.ts      打刻データCRUD・年ファイル/月シート解決
│   ├── google/             Sheets/Drive/Calendar APIの薄いラッパー
│   └── actions/             action ごとのハンドラ
└── test/                  Vitest
```

## ローカルでのテスト

```sh
cd server
npm install
npm test        # Vitest。実際のGoogle APIは呼ばない（全てモック）
npm run typecheck
```

## 本番セットアップ

以下は初回のみ必要な手順。**ブラウザでの操作が必要なため、この部分はユーザー
自身で行う。**

### 1. Google Cloudでサービスアカウントを作る

1. [Google Cloud Console](https://console.cloud.google.com/) で新しいプロジェクト
   を作る（既存のプロジェクトを流用してもよい）。
2. 「APIとサービス」→「ライブラリ」から、以下の3つを有効化する。
   - Google Sheets API
   - Google Drive API
   - Google Calendar API
3. 「APIとサービス」→「認証情報」→「認証情報を作成」→「サービスアカウント」
   で新しいサービスアカウントを作る（ロールの付与は不要。個別のリソース共有で
   権限を渡すため）。
4. 作成したサービスアカウントの「キー」タブから「鍵を追加」→「新しい鍵を作成」
   →形式は **JSON** を選んでダウンロードする。
   このJSONファイルの中身は他人に見せない（Vercelの環境変数に設定したら
   ローカルには残さない）。
5. JSONの中の `client_email` の値（`xxxx@xxxx.iam.gserviceaccount.com`
   の形式）を控えておく。次の手順で、これを実際のユーザーであるかのように
   スプレッドシート・フォルダ・カレンダーに共有する。

### 2. リソースをサービスアカウントに共有する

サービスアカウントは「Googleアカウントを持たないロボットユーザー」のような
もの。既存のGoogleアカウントで所有しているリソースを、`client_email`宛てに
**共有**する必要がある。

| 共有するもの | 場所 | 権限 |
|---|---|---|
| 対象スプレッドシート（users/devices/settings） | [gas/README.md](../gas/README.md)のリンク先 | 編集者 |
| 打刻データの年ファイルが入っているDriveフォルダ | `gas/AttendanceManagerBackend.js`の`FOLDER_ID` | 編集者 |
| 年ファイルのテンプレート | `gas/AttendanceManagerBackend.js`の`TEMPLATE_FILE_ID`（通常はフォルダの共有に含まれる） | 編集者 |
| 祝日カレンダー（`ja.japanese#holiday@group.v.calendar.google.com`） | Googleカレンダーの設定 | 予定の表示（閲覧） |
| 会社の休日カレンダー | 管理者設定画面の「会社の休日カレンダーID」 | 予定の表示（閲覧） |

いずれも、各リソースの「共有」メニューからサービスアカウントのメール
アドレスを追加すればよい（Googleドライブのファイル共有と同じ操作）。

### 3. Vercelプロジェクトを作る

1. [Vercel](https://vercel.com/) にサインアップし、このGitHubリポジトリを
   接続する。
2. 新しいプロジェクトを作るとき、**Root Directory を `server`** に設定する
   （リポジトリ直下ではなく `server/` をVercelプロジェクトのルートにする）。
3. Framework Preset は特に指定しなくてよい（`api/`配下がそのまま関数になる）。

### 4. 環境変数を設定する

Vercelプロジェクトの Settings → Environment Variables で以下を設定する
（`server/.env.example` も参照）。

| 変数名 | 値 |
|---|---|
| `GOOGLE_CLIENT_EMAIL` | サービスアカウントJSONの`client_email` |
| `GOOGLE_PRIVATE_KEY` | サービスアカウントJSONの`private_key`。**改行は`\n`のまま1行の文字列として貼り付ける**（JSON内の値をそのままコピーすれば`\n`表記になっている） |
| `SESSION_SECRET` | ランダムな文字列。例: `openssl rand -base64 32` で生成 |

設定後、Production・Preview 両方の環境に反映されるようにする
（Vercelのenv var設定画面でどちらの環境に適用するか選べる）。

### 5. デプロイする

GitHubにpushすると自動でデプロイされる。手動でデプロイしたい場合は
Vercelダッシュボードの「Deploy」からも実行できる。

デプロイ後のURLは `https://<プロジェクト名>.vercel.app/api/exec` になる。

## 動作確認（本番URLへの切り替え前）

`app/lib/application/constants.dart`の`webAppUrl`は
`String.fromEnvironment('GAS_WEB_APP_URL', defaultValue: ...)`で環境変数
オーバーライドに対応済みなので、**`Constants.webAppUrl`のデフォルト値は
変えずに**、ローカルのFlutter開発サーバーだけ新バックエンドへ向けて確認できる。

```sh
cd app
flutter run -d web-server --dart-define=GAS_WEB_APP_URL=https://<プロジェクト名>.vercel.app/api/exec
```

（Docker経由の場合は `docker-compose.yml` の起動コマンドに同じ
`--dart-define`を足す。）

端末登録・打刻・タイムカード・集計・管理者設定まで一通り操作して問題なければ、
`Constants.webAppUrl`のデフォルト値を本番のVercel URLに変更し、コミット・push
する（GitHub Pagesが自動デプロイされ、これが実際の切り替えになる）。

GASのデプロイはすぐには削除せず、切り戻し用に残しておく
（`Constants.webAppUrl`を元のGAS URLに戻すだけで即座にロールバックできる）。
