# 雑学ニキ automation

雑学ニキ用のアップロードログ、予約投稿ログ、検証ログを置く。
知恵ネキの automation とは混ぜない。

## API automation policy

動画制作は automation では行わない。手動で作成済みの YAML stock だけを対象にする。

- 04:00: `scripts/zatsugaku_api_automation.sh daily-upload`
  - 今日の曜日/月末ルールからレベルを決定
  - 5カテゴリから1本ずつ stock を選択
  - `status: scheduled` に更新
  - YouTube Data API で Private upload
  - `publishAt` に以下の公開時刻を設定
- 07:35 / 12:05 / 18:05 / 21:05 / 23:35: `scripts/zatsugaku_api_automation.sh comment-due`
  - 公開5分後以降の動画に対応する `comment_text` を投稿

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

OAuth scope:

- `https://www.googleapis.com/auth/youtube.upload`
- `https://www.googleapis.com/auth/youtube.force-ssl`

## Safe local checks

```bash
scripts/zatsugaku_api_automation.sh dry-run
ruby scripts/zatsugaku_inventory.rb validate
```
