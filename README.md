# attendance_manager

勤怠管理用の Flutter Web アプリケーション。

タイムカードの入力・参照を行い、バックエンドには Google Apps Script (GAS) の
[Apps Script API](https://developers.google.com/apps-script/api/reference/rest/v1/scripts/run) を利用する。

## 構成

| | |
|---|---|
| フレームワーク | Flutter 3.7.10 (Dart SDK `>=2.19.6 <3.0.0`) |
| ターゲット | Web (`--web-renderer html`) |
| バックエンド | Google Apps Script (`scripts.run` API) |
| 配信 | nginx (Docker) / GitHub Pages |
| ロケール | `ja` 固定 |

```
.
├── app/                       Flutter プロジェクト本体
│   ├── lib/
│   │   ├── main.dart          エントリポイント。GasClient / AttendanceService を組み立てる
│   │   ├── application/
│   │   │   └── constants.dart バージョン・API 認証情報・ユーザー一覧・配色
│   │   ├── models/            attend_data, calendar, date, member, user,
│   │   │                      daily_timecard, monthly_timecard, timecard_data, encoder
│   │   ├── services/
│   │   │   ├── gas_client.dart        OAuth トークン取得 + GAS 関数呼び出し
│   │   │   └── attendance_service.dart 勤怠ドメインロジック
│   │   └── ui/
│   │       ├── pages/         my_home_page, timecard_page, test_page
│   │       └── components/    my_app_bar, data_table_view, command_buttons,
│   │                          dialogs/ (login, datetime_picker, paid_holiday,
│   │                                    delete, error)
│   └── pubspec.yaml
├── Dockerfile                 マルチステージ: Flutter build → nginx:alpine
├── docker-compose.yml         開発用 web-server (:8080)
└── .github/workflows/deploy.yml  main push で GitHub Pages へデプロイ
```

## 開発環境の起動

Docker Compose でホットリロード付きの dev サーバーを立てる。ローカルに Flutter SDK は不要。

```sh
docker compose up
```

`./app` がコンテナの `/app` にマウントされ、`flutter run -d web-server` が
`0.0.0.0:8080` で待ち受ける。ブラウザで http://localhost:8080 を開く。

停止:

```sh
docker compose down
```

> ポート 8080 が使用中というエラーが出る場合は、既にこのコンテナが起動している。
> `docker compose down` してから起動し直す。

ローカルに Flutter SDK がある場合は直接実行してもよい:

```sh
cd app
flutter pub get
flutter run -d chrome
```

## 本番ビルド

```sh
docker build -t attendance-manager .
docker run --rm -p 8000:80 attendance-manager
```

nginx が `/usr/share/nginx/html` から静的ファイルを配信する (コンテナ内 port 80)。

## デプロイ

`main` への push で [.github/workflows/deploy.yml](.github/workflows/deploy.yml) が動き、
GitHub Pages へ公開される。Pull Request ではビルドのみ実行しデプロイはしない。

`base-href` は GitHub Pages のサブパス配信に合わせて `/attendance_manager/` を指定する。

## バージョン

アプリ内表示のバージョンは [app/lib/application/constants.dart](app/lib/application/constants.dart) の
`Constants.version` で管理している (`pubspec.yaml` の `version` とは別)。

## リモートリポジトリ

- GitHub (GitHub Pages デプロイ元)
- GitLab: `https://gitlab.com/tyagiwork0419/attendance_manager.git`
