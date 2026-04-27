# 雑学ニキ automation

雑学ニキ用のアップロードログ、予約投稿ログ、検証ログを置く。
知恵ネキの automation とは混ぜない。

## API automation policy

04:00 ジョブは翌日分の YAML stock を選び、YouTube Data API で Private upload して `publishAt` を設定する。
アップロード成功レスポンスの `id` は `video_id` として YAML に保存し、コメントジョブはこの `video_id` を使う。

## 5 automation jobs

1. `scripts/zatsugaku_api_automation.sh plan-0400`
   - 04時台だけ、翌日の曜日/月末ルールからレベルを決定して5カテゴリから1本ずつ stock を選択
   - 選択した YAML を `status: scheduled` に更新
   - Private upload + `publishAt` 設定を行い、返ってきた `video_id` を YAML に保存

2. `scripts/zatsugaku_api_automation.sh comment-0735`
   - 07:35 に `comment_after_at` が来た動画へ YouTube API でコメント追加

3. `scripts/zatsugaku_api_automation.sh comment-1205`
   - 12:05 に `comment_after_at` が来た動画へ YouTube API でコメント追加

4. `scripts/zatsugaku_api_automation.sh comment-1805`
   - 18:05 に `comment_after_at` が来た動画へ YouTube API でコメント追加

5. `scripts/zatsugaku_api_automation.sh comment-night`
   - 21:05 / 23:35 の夜枠に `comment_after_at` が来た動画へ YouTube API でコメント追加

`scripts/zatsugaku_api_automation.sh run` は後方互換用のまとめ実行として残す。

## Daily slots

| category_key | category | publishAt | comment after |
| --- | --- | --- | --- |
| animal | 動物 | 07:30 | 07:35 |
| food_drink | 食べ物・飲み物 | 12:00 | 12:05 |
| body_health | 人体・健康 | 18:00 | 18:05 |
| science_tech | 科学・テクノロジー | 21:00 | 21:05 |
| scary_danger | 怖い・危険 | 23:30 | 23:35 |

## YouTube API env

Codex automation の実行環境に以下を設定する。

```bash
YOUTUBE_CLIENT_ID=...
YOUTUBE_CLIENT_SECRET=...
YOUTUBE_REFRESH_TOKEN=...
```

ローカルの Codex automation では、次の git 管理外ファイルが存在すれば `scripts/zatsugaku_api_automation.sh` が自動で読み込む。

```text
/Users/yota/.codex/secrets/youtube_zatsugaku_api.env
```

このファイルに実値を保存し、リポジトリには絶対にコミットしない。

OAuth scope:

- `https://www.googleapis.com/auth/youtube.upload`
- `https://www.googleapis.com/auth/youtube.force-ssl`

## Safe local checks

```bash
scripts/zatsugaku_api_automation.sh dry-run
scripts/zatsugaku_api_automation.sh run
scripts/zatsugaku_api_automation.sh plan-0400
scripts/zatsugaku_api_automation.sh comment-0735
ruby scripts/zatsugaku_inventory.rb validate
```
