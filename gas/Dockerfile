# Apps Script をローカル編集・デプロイするための clasp 実行環境。
# ホストに Node.js や clasp を入れずに済ませるためのもの。
FROM node:20-alpine

# 再現性のためバージョンを固定する。
RUN npm install -g @google/clasp@2.4.2

# --- コンテナでログインするための調整 ---------------------------------------
#
# clasp login は OAuth のリダイレクトを受けるためにローカル HTTP サーバーを立てるが、
# 標準は listen(0)、つまり OS 任せのランダムポートで待ち受ける。
# ポートが不定だとコンテナ外へ publish できず、ホストのブラウザからの
# リダイレクトが届かない。そこで固定ポートに書き換える。
#
# ブラウザ不要の OOB フロー (--no-localhost) は Google が 2022 年に廃止しており、
# 使うと 400 invalid_request になる。したがってこの経路しか選べない。
ARG CLASP_LOGIN_PORT=3001
ENV CLASP_LOGIN_PORT=${CLASP_LOGIN_PORT}

# grep はパッチが当たったことの確認。将来 clasp の実装が変わって sed が
# 空振りした場合に、黙って壊れる代わりにビルドを失敗させる。
RUN AUTH=/usr/local/lib/node_modules/@google/clasp/build/src/auth.js && \
    sed -i "s/s\.listen(0,/s.listen(${CLASP_LOGIN_PORT},/" "$AUTH" && \
    grep -q "s.listen(${CLASP_LOGIN_PORT}," "$AUTH"

# コンテナにブラウザは無い。clasp は open() を投げっぱなしで呼ぶため
# (auth.js: `(async () => open(authUrl))()`)、失敗すると未処理 rejection になる。
# Node 20 はそれでプロセスを落とすので、警告に留めてログインを継続させる。
ENV NODE_OPTIONS=--unhandled-rejections=warn

# clasp の認証情報は ~/.clasprc.json に書き出される。
# HOME をリポジトリ外へ向けて named volume に隔離し、コミット事故を防ぐ。
ENV HOME=/claspauth

WORKDIR /gas

ENTRYPOINT ["clasp"]
CMD ["--help"]
