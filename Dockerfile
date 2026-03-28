FROM ubuntu:22.04 AS builder

ARG FLUTTER_VERSION=3.22.
ARG APP_NAME="/attendance_manager"
ENV PATH="/flutter/bin:$PATH"

RUN apt-get update && apt-get install -y \
    curl git unzip xz-utils zip \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/flutter/flutter.git \
    -b ${FLUTTER_VERSION} --depth 1 /flutter

WORKDIR /app
COPY app/ .
RUN flutter pub get && \
    flutter build web --release \
      --base-href ${APP_NAME}    # ← ここ重要！