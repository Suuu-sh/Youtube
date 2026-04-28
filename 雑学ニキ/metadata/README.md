# 雑学ニキ metadata

投稿タイトル、説明文、出典メモ、AI生成開示判断、動画仕様を管理する。

## YAML workflow

完成した動画は `metadata/stock/<level>/<category_key>/<id>/stock.yaml` に1本1ファイルで登録する。
Codex app の `Lv雑学作成予約` は毎日20:00に不足分の動画制作、在庫検証、対象日への Private upload、YouTube `publishAt` 設定までを1回で行う。
旧 `Lv雑学定期投稿` の21:00別実行は停止し、作成完了時点で `next-missing-set` が示した日程へ予約する。
YouTube コメントAPIは使わない。詳細・補足は `description` に集約する。

### category_key

| category_key | カテゴリ |
| --- | --- |
| `animal` | 動物 |
| `food_drink` | 食べ物・飲み物 |
| `body_health` | 人体・健康 |

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
contact_sheet_path: /absolute/path/to/contact.png
title: タイトル #雑学 #shorts
description: |
  説明文

  【詳細・補足】

  1. 見出し
  仕組み、例外、注意点などを2〜3文で細かく補足する。

  2. 見出し
  画面に出し切れない背景まで説明する。

  いくつわかりましたか？
source_urls:
  - https://example.com/source
created_at: 2026-04-27T00:00:00+09:00
schedule_date:
publish_at:
publish_slot:
scheduled_at:
video_id:
uploaded_at:
last_error:
```

### status

- `stock`: 未投稿・保管中
- `scheduled`: `Lv雑学作成予約` が予約対象にした未アップロード動画
- `uploaded`: Private upload 済み。`publishAt` で予約公開される、または公開済み
- `rejected`: 使用しない

### 予約公開スケジュール

今後の通常予約対象は3カテゴリのみ。科学・テクノロジーと怖い・危険は作成・通常予約しない。

| category_key | カテゴリ | publish_slot | publish_at |
| --- | --- | --- | --- |
| `animal` | 動物 | `07:30` | 当日 07:30 |
| `food_drink` | 食べ物・飲み物 | `12:00` | 当日 12:00 |
| `body_health` | 人体・健康 | `18:00` | 当日 18:00 |

21:00 と 25:00 の旧公開枠は使わない。翌日分はこの3本だけを `scheduled` / `uploaded` に進める。

### 重複防止

`topic_key` の完全一致はブロックする。さらに `fact_summary` の文字類似度が高いものも警告する。

新規動画を作る時は、必ず同カテゴリの既存 `topic_key` / `fact_summary` を先に読み、題材そのものの重複しすぎを避ける。完全一致しなくても、同じ食品・同じ人体部位の大量再利用は避ける。動物カテゴリは既存1本あたり同じ動物種の被りを最大1体までにする。

確認用に次を使う。

```bash
ruby scripts/zatsugaku_inventory.rb validate
ruby scripts/zatsugaku_inventory.rb plan --date <target-date> --dry-run
ruby scripts/zatsugaku_inventory.rb upload-due --dry-run
ruby scripts/zatsugaku_inventory.rb next-missing-set --date today
ruby scripts/zatsugaku_inventory.rb overlap-report --category animal
ruby scripts/zatsugaku_inventory.rb overlap-report --category food_drink
scripts/zatsugaku_api_automation.sh dry-run
```
