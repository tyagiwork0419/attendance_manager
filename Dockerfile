# ビルドステージ
FROM ghcr.io/cirruslabs/flutter:3.7.10 AS builder

# 配信パス。GitHub Pages のようなサブパス配信では "/<repo名>/" を渡す。
# 未指定時はルート配信 ("/") とし、ローカルでの docker run をそのまま動かせるようにする。
ARG BASE_HREF="/"

WORKDIR /app
COPY app/ .

RUN flutter pub get && \
    flutter build web --release \
      --web-renderer html \
      --base-href "$BASE_HREF"

# 本番ステージ
FROM nginx:alpine AS runner
COPY --from=builder /app/build/web /usr/share/nginx/html
EXPOSE 80