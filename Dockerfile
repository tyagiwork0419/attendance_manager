# ビルドステージ
FROM ghcr.io/cirruslabs/flutter:3.7.10 AS builder

# ARG APP_NAME="/attendance_manager/"

WORKDIR /app
COPY app/ .
RUN flutter pub get && \
    flutter build web --release \
      --base-href "/attendance_manager/"

# 本番ステージ
FROM nginx:alpine
COPY --from=builder /app/build/web /usr/share/nginx/html
EXPOSE 80