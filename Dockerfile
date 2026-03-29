# ビルドステージ
FROM ghcr.io/cirruslabs/flutter:3.7.10 AS builder


WORKDIR /app
COPY app/ .

RUN flutter pub get && \
    flutter build web --release \
      --web-renderer html \
      --base-href "/attendance_manager/"

# 本番ステージ
FROM nginx:alpine AS runner
COPY --from=builder /app/build/web /usr/share/nginx/html
EXPOSE 80