# YouTube Automation Workspace

YouTube チャンネルごとの素材・企画・投稿メタデータ・自動化ログ・制作手順を管理します。

## チャンネル

- `知恵ネキ/` — 知恵ネキの処世術
- `雑学ニキ/` — 雑学ニキ
- `_shared/` — 複数チャンネルで共通利用するものだけ

## 運用ルール

1. チャンネル固有の素材・ログ・メタデータは必ず対象チャンネル配下に置く。
2. 知恵ネキと雑学ニキで、台本テンプレート、音声、BGM、アップロード手順を混ぜない。
3. 共通化できるものだけ `_shared/` に置く。
4. 新しいチャンネルを増やす場合は `/Users/yota/Projects/Automation/Youtube/<チャンネル名>/` を作る。

## パス

- 知恵ネキ: `/Users/yota/Projects/Automation/Youtube/知恵ネキ/`
- 雑学ニキ: `/Users/yota/Projects/Automation/Youtube/雑学ニキ/`
- 共通: `/Users/yota/Projects/Automation/Youtube/_shared/`

## 予約公開後コメント自動化

このワークスペースでは、YouTube側の予約公開で動画を公開し、公開後の補足コメント投稿だけを自動化する。

- 共通スクリプト: `_shared/youtube-scheduler/comment_due.mjs`
- 雑学ニキのキュー例: `雑学ニキ/automation/comment_queue.sample.json`
- GitHub Actions例: `.github/workflows/youtube-comment-due.yml`

基本運用:

1. 各チャンネル配下で動画を作成する。
2. YouTube Studioで予約公開する。
3. 動画ID、予約公開日時、コメント本文を `automation/comment_queue.json` に入れる。
4. cron または GitHub Actions で `_shared/youtube-scheduler/comment_due.mjs` を定期実行する。
5. スクリプトが公開済み動画だけにコメントし、成功したらキューへ `commentedAt` を記録する。

雑学ニキのdry-run例:

```bash
cd /Users/yota/Projects/Automation/Youtube
cp 雑学ニキ/automation/comment_queue.sample.json 雑学ニキ/automation/comment_queue.json
node _shared/youtube-scheduler/comment_due.mjs \
  --queue 雑学ニキ/automation/comment_queue.json \
  --dry-run
```

本番実行には以下の環境変数が必要。

```bash
export YOUTUBE_CLIENT_ID='...'
export YOUTUBE_CLIENT_SECRET='...'
export YOUTUBE_REFRESH_TOKEN='...'
```
