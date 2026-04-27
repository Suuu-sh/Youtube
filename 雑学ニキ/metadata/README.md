# 雑学ニキ metadata

投稿タイトル、説明文、出典メモ、AI生成開示判断、動画仕様を管理する。

## YAML stock workflow

動画作成は手動で行い、完成した動画は `metadata/videos/stock/<category_key>/<id>.yaml` に1本1ファイルで登録する。
API automation はYAML在庫から、翌日のレベルとカテゴリに合う5本を選んで Private upload + `publishAt` 予約公開し、upload成功時に返る `id` を `video_id` として保存する。公開後は、時刻別コメントジョブが `video_id` と `comment_text` を使って固定コメント用テキストを投稿する。

### category_key と公開時刻

| category_key | カテゴリ | 公開時刻 | コメント時刻 |
| --- | --- | --- | --- |
| `animal` | 動物 | 07:30 | 07:35 |
| `food_drink` | 食べ物・飲み物 | 12:00 | 12:05 |
| `body_health` | 人体・健康 | 18:00 | 18:05 |
| `science_tech` | 科学・テクノロジー | 21:00 | 21:05 |
| `scary_danger` | 怖い・危険 | 23:30 | 23:35 |

### 曜日レベル

- 月・水・金: `Lv1`
- 火・木: `Lv2`
- 土: `Lv3`
- 日: `Lv4`
- 毎月末: `Lv5`（曜日より優先）

### 必須フィールド

```yaml
id: animal_octopus_three_hearts_001
category: 動物
category_key: animal
level: Lv1
topic_key: animal_octopus_three_hearts
fact_summary: タコには心臓が3つある
status: stock
video_path: /absolute/path/to/movie.mp4
title: タイトル #雑学 #shorts
description: |
  説明文
comment_text: |
  動画の補足👇

  1. 見出し
  補足本文。

  2. 見出し
  補足本文。

  いくつわかりましたか？
source_urls:
  - https://example.com/source
created_at: 2026-04-27T00:00:00+09:00
publish_at:
comment_after_at:
video_id:
```

### status

- `stock`: 未使用在庫
- `scheduled`: 当日の枠に選択済み、YouTube upload 待ち
- `uploaded`: Private upload + 予約公開済み、コメント待ち
- `commented`: コメント投稿済み
- `rejected`: 使用しない

### 重複防止

`topic_key` の完全一致はブロックする。さらに `fact_summary` の文字類似度が高いものも警告・除外する。
過去投稿済みだけでなく、予約済み・アップロード済みも重複対象に含める。

## CLI

```bash
ruby scripts/zatsugaku_inventory.rb validate
ruby scripts/zatsugaku_inventory.rb plan --date 2026-04-28 --dry-run
ruby scripts/zatsugaku_inventory.rb plan --date tomorrow
ruby scripts/zatsugaku_inventory.rb upload-due
ruby scripts/zatsugaku_inventory.rb comment-due
ruby scripts/zatsugaku_inventory.rb comment-due --slot 07:35
ruby scripts/zatsugaku_api_automation.sh plan-0400
ruby scripts/zatsugaku_api_automation.sh comment-0735
```

YouTube API を使うコマンドは以下の環境変数が必要。

```bash
YOUTUBE_CLIENT_ID=...
YOUTUBE_CLIENT_SECRET=...
YOUTUBE_REFRESH_TOKEN=...
```

必要 OAuth scope: `https://www.googleapis.com/auth/youtube.upload` と `https://www.googleapis.com/auth/youtube.force-ssl`。
