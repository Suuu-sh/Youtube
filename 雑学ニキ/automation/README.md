# 雑学ニキ automation

雑学ニキ用のアップロードログ、予約投稿ログ、検証ログを置く。
知恵ネキの automation とは混ぜない。

## API automation policy

動画制作は automation では行わない。手動で作成済みの YAML stock だけを対象にする。

- Single Codex automation: `scripts/zatsugaku_api_automation.sh run`
  - 04時台だけ、今日の曜日/月末ルールからレベルを決定して5カテゴリから1本ずつ stock を選択
  - 選択した YAML を `status: scheduled` に更新
  - 毎回、YouTube Data API で未アップロード分を Private upload し、`publishAt` を設定
  - 毎回、公開5分後以降の動画に対応する `comment_text` を投稿
  - 余分な起動時刻では due 対象がなければ何もしない

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
ruby scripts/zatsugaku_inventory.rb validate
```
