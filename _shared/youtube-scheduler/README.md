# YouTube scheduled comment automation

予約公開は YouTube 側に任せ、公開後の補足コメント投稿だけを自動化する。

## 仕組み

1. 動画を事前に YouTube Studio へアップロードし、予約公開を設定する。
2. `automation/comment_queue.json` に `videoId`, `scheduledAt`, `commentText` を入れる。
3. cron / GitHub Actions が1日5回または数分おきに `comment_due.mjs` を実行する。
4. スクリプトは公開予定時刻を過ぎた未コメント動画を探す。
5. YouTube Data APIで動画が `public` になっていることを確認する。
6. `commentThreads.insert` でコメントする。
7. 成功したら `commentedAt`, `commentThreadId`, `commentId` をキューへ保存する。

固定コメント化は YouTube Data API の通常機能では扱いにくいため、このスクリプトは「コメント投稿」までを担当する。

## 必要な環境変数

OAuth の refresh token を使う。

```bash
export YOUTUBE_CLIENT_ID='...'
export YOUTUBE_CLIENT_SECRET='...'
export YOUTUBE_REFRESH_TOKEN='...'
```

必要スコープはコメント投稿なら通常 `https://www.googleapis.com/auth/youtube.force-ssl`。

## 雑学ニキでの実行例

```bash
cd /Users/yota/Projects/Automation/Youtube
cp 雑学ニキ/automation/comment_queue.sample.json 雑学ニキ/automation/comment_queue.json
# comment_queue.json の videoId と scheduledAt を実データにする
node _shared/youtube-scheduler/comment_due.mjs \
  --queue 雑学ニキ/automation/comment_queue.json \
  --dry-run
```

本番:

```bash
node _shared/youtube-scheduler/comment_due.mjs \
  --queue 雑学ニキ/automation/comment_queue.json \
  --grace-minutes 2 \
  --max 5
```

## cron例

JSTの 7:02 / 11:02 / 15:02 / 19:02 / 23:02 に実行する例。

```cron
2 7,11,15,19,23 * * * cd /Users/yota/Projects/Automation/Youtube && /usr/bin/env node _shared/youtube-scheduler/comment_due.mjs --queue 雑学ニキ/automation/comment_queue.json --grace-minutes 2 --max 5 >> 雑学ニキ/automation/comment_due.log 2>&1
```

公開予約時刻ぴったりではなく2分後にすると、YouTube側の公開反映待ちに強くなる。

## GitHub Actionsで使う場合

- `YOUTUBE_CLIENT_ID`
- `YOUTUBE_CLIENT_SECRET`
- `YOUTUBE_REFRESH_TOKEN`

を repository secrets に入れる。

キューJSONをGitHub上で更新するなら、実行後に `commentedAt` をコミットする処理を追加する。コミットしない運用なら、Google Sheetsや小さなDBに状態を置く方がよい。
