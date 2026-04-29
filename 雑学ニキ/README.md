# 雑学ニキ

雑学解説系チャンネル用の作業領域です。
知恵ネキとは素材、台本形式、投稿手順、検証観点を分けて管理します。

## ディレクトリ

- `ideas/` — 企画、テーマ候補、構成メモ
- `prompts/` — 台本・リサーチ・メタデータ生成用プロンプト
- `metadata/stock/` — 動画ごとのメタデータとYAML
- `assets/generated/` — 生成画像、音声、manifest などの動画素材
- `renders/` — 書き出し済み mp4 と確認用画像
- `branding/` — チャンネルアイコン、トーン、デザインルール
- `scripts/` — 雑学ニキ向けの制作・確認補助スクリプト
- `analytics/` — 投稿後の計測メモ

## 初期運用メモ

- 知恵ネキ用の素材やログを流用しない。
- 出典確認、事実確認、誤情報チェックを制作フローに含める。
- 投稿方法や使用する音声・BGM・画作りは、雑学ニキ用 README/手順書に追記していく。

## BGMルール

- 動画作成時は、原則として `Escort / もっぴーさうんど（DOVA-SYNDROME）` をBGMとして薄く入れる。
- BGMファイル: `/Users/yota/Projects/Automation/Youtube/_shared/bgm/dova-syndrome/escort_moppy_sound.mp3`
- 標準音量はナレーション `1.0`、BGM `0.10`。声が聞き取りづらい場合はBGMを `0.06〜0.08` に下げる。
- 動画説明欄に `BGM: Escort / もっぴーさうんど（DOVA-SYNDROME）` を入れる。
- レンダー後、BGMが声を邪魔していないか必ず確認する。

## 現在の投稿運用

- Codex app の `Lv雑学作成予約` が、毎日20:00に不足分の動画作成、在庫検証、対象日への Private upload、YouTube `publishAt` による予約公開までを1本の automation で行う。
- 旧 `Lv雑学定期投稿` の21:00別実行は停止し、作成完了時点で対象日へスケジュールする。
- YouTube コメントAPIは使わない。固定コメント用テキストやコメントキューも作らない。
- 詳細・補足は YouTube の `description` に集約する。
- 今後は1日3本を次の枠で予約公開する。科学・テクノロジーと怖い・危険は今後扱わない。

| category_key | カテゴリ | 公開時刻 |
| --- | --- | --- |
| `animal` | 動物 | 07:30 |
| `food_drink` | 食べ物・飲み物 | 12:00 |
| `body_health` | 人体・健康 | 18:00 |

### 3カテゴリ化後の公開戦略

- 1日3本に絞り、朝・昼・夕方の生活導線に合わせてカテゴリを固定する。
- 07:30は軽く見られる動物、12:00は昼食文脈に合う食べ物・飲み物、18:00は帰宅後に見やすい人体・健康を出す。
- `body_health` は Shorts / Longform の両方で、少し笑える・ニヤッとする体の雑学を積極的に混ぜる。
- `body_health` では、出典に基づく健康・人体の範囲に収まるなら、恋愛、匂い、心拍、汗、キス、ホルモンなど「少しえっちに見えるが科学で説明できる」題材も入れてよい。
- ただし露骨な性描写、性的なハウツー、未成年を性的に扱う内容、身体いじり、医療助言に見える断定は避け、タイトル・字幕・画像は広告安全な軽い下ネタ程度に抑える。
- `body_health` の台本を作る前に `prompts/body_health.md` を確認する。
- 21:00以降の追加枠は使わず、同じ日の投稿密度を上げすぎない。
- レベル運用は曜日ごとに維持し、各日3カテゴリが同じ Lv で揃うようにする。

## 完成動画を作ったら残すもの

動画ごとのメタデータと確認素材は、動画・素材と同じ level / category / id でまとめます。

```text
metadata/stock/<level>/<category_key>/<id>/
  metadata.md
  stock.yaml

renders/stock/<level>/<category_key>/<id>/
  <id>_bgm050.mp4
  contact.png

assets/generated/stock/<level>/<category_key>/<id>/
```

YAML の `video_path` と `contact_sheet_path` は絶対パスにします。

## 画像・イラスト確認ルール

- 各雑学カードのメイン画像は、必ずそのカードの題材に直接対応する いらすとや画像を使う。
  - 例: シャコの話にタコ画像、ミツバチの話に巣だけ、胃の話に単なる食事中の人物だけ、のような代用は禁止。
- 同じ動画内で、タイトル・説明欄カード以外に同じ画像を使い回さない。
- 直近動画と同じ代表画像ばかりにならないよう、contact sheet で過去作との被りも確認する。
- アップロード前に contact sheet を目視し、`stock.yaml` の `visual_audit` に次の4項目を `true` で記録する。
  - `contact_sheet_checked`
  - `image_subject_match_checked`
  - `no_unrelated_placeholder_images`
  - `no_excessive_reuse`
- 2026-04-29 12:30 JST 以降に作る新規在庫は、この `visual_audit` がないと `validate` が失敗する。
- `plan` / `upload-due` / `next-missing-set` は、作成日時に関係なく `visual_audit` 済みの在庫だけを使用対象にする。

## 確認コマンド

```bash
ruby scripts/zatsugaku_inventory.rb validate
ruby scripts/zatsugaku_inventory.rb plan --date <target-date> --dry-run
ruby scripts/zatsugaku_inventory.rb upload-due --dry-run
ruby scripts/zatsugaku_inventory.rb next-missing-set --date today
ruby scripts/zatsugaku_inventory.rb overlap-report --category animal
scripts/zatsugaku_api_automation.sh dry-run
```

実アップロードと予約公開は、動画作成後に `ruby scripts/zatsugaku_inventory.rb plan --date <next-missing-set の date>` と `ruby scripts/zatsugaku_inventory.rb upload-due` で行う。
YouTube API 認証情報はローカルの secret env から読み込み、コメント投稿は行わない。
## Longform automation

- Codex app automation `Long作成投稿` runs every day at 04:00 JST.
- It creates one normal/long-form video with fresh research, validates it, schedules the next unplanned 06:00 JST publication slot, uploads it as Private, and sets YouTube `publishAt`.
- Longform upload/schedule helper:

```bash
ruby scripts/zatsugaku_longform_inventory.rb validate
ruby scripts/zatsugaku_longform_inventory.rb schedule-next --dry-run
ruby scripts/zatsugaku_longform_inventory.rb upload-due --dry-run
```

- Finished longform YAML should use `status: stock` before scheduling. The scheduler updates it to `scheduled`, then `uploaded` with `video_id` after YouTube API upload.
- Longform standard audio mix follows the accepted Shorts-style mix: narration `1.0`, BGM `0.50`.

