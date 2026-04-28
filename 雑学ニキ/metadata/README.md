# 雑学ニキ metadata

投稿タイトル、説明文、出典メモ、AI生成開示判断、動画仕様を管理する。

## YAML stock workflow

4時 automation が在庫補充として動画を作成し、完成した動画は `metadata/stock/<level>/<category_key>/<id>/stock.yaml` に1本1ファイルで登録する。手動制作した動画も同じ形式で登録する。
API automation はYAML在庫から、その日のレベルとカテゴリに合う5本を選んで Private upload + `publishAt` 予約公開し、upload成功時に返る `id` を `video_id` として保存する。4時ジョブはさらに、今日以降の投稿日をシミュレーションして次に不足する日付・レベルを判定し、そのレベルの5カテゴリ分を stock として追加制作する。公開後は、時刻別コメントジョブが `video_id` と `comment_text` を使って固定コメント用テキストを投稿する。

### category_key と公開時刻

| category_key | カテゴリ | 公開時刻 | コメント時刻 |
| --- | --- | --- | --- |
| `animal` | 動物 | 07:30 | 07:35 |
| `food_drink` | 食べ物・飲み物 | 12:00 | 12:05 |
| `body_health` | 人体・健康 | 18:00 | 18:05 |
| `science_tech` | 科学・テクノロジー | 21:00 | 21:05 |
| `scary_danger` | 怖い・危険 | 25:00（翌日01:00） | 25:05（翌日01:05） |

### 曜日レベル

- 月: `Lv1`
- 火: `Lv2`
- 水: `Lv1`
- 木: `Lv2`
- 金: `Lv3`
- 土: `Lv4`
- 日: `Lv5`

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

新規stockを作る時は、必ず同カテゴリの既存 `topic_key` / `fact_summary` を先に読み、題材そのものの重複しすぎを避ける。完全一致しなくても、同じ食品・同じ人体部位・同じ危険/技術テーマの大量再利用は避ける。動物カテゴリは既存1本あたり同じ動物種の被りを最大1体までにする。確認用に次を使う。

```bash
ruby scripts/zatsugaku_inventory.rb overlap-report --category animal
ruby scripts/zatsugaku_inventory.rb overlap-report --category food_drink
```

`overlap-report` は `topic_key` 内の具体語を比較し、同カテゴリ内で共有語が多いstock候補を出す。特に動物カテゴリは、猫・犬・ナマケモノのような動物種名が2体以上被った時点でテーマ差し替えを検討する。1体だけの被りは許容範囲。
過去投稿済みだけでなく、予約済み・アップロード済みも重複対象に含める。

## CLI

```bash
ruby scripts/zatsugaku_inventory.rb validate
ruby scripts/zatsugaku_inventory.rb plan --date 2026-04-28 --dry-run
ruby scripts/zatsugaku_inventory.rb plan --date today
ruby scripts/zatsugaku_inventory.rb next-missing-set --date today
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
