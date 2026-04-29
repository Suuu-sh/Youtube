# 雑学ニキ 制作・投稿手順

## 目的

雑学解説系の Shorts / 動画を、知恵ネキとは別の素材・手順・検証基準で制作する。

## 材料の置き場所

- 企画: `ideas/`
- リサーチメモ・出典メモ: `ideas/` または `metadata/`
- 画像・音声・manifest: `assets/generated/stock/<level>/<category_key>/<id>/`
- メタデータ: `metadata/stock/<level>/<category_key>/<id>/metadata.md`
- 動画: `renders/stock/<level>/<category_key>/<id>/`
- ブランド素材: `branding/`

## 現在の基本方針

- Codex app の `Lv雑学作成予約` は、毎日20:00に不足分の動画作成、在庫検証、対象日への Private upload、YouTube `publishAt` 設定までを1回で行う。
- 旧 `Lv雑学定期投稿` の21:00別実行は停止し、動画作成が完了した段階で `next-missing-set` が示した日程へ予約公開する。
- YouTube コメントAPIは使わない。コメント投稿用の文面やキューは作らない。
- 詳細・補足は `description` に集約する。

## 予約公開スケジュール

今後は1日3本を次の時刻で予約公開する。科学・テクノロジーと怖い・危険は今後扱わない。

| category_key | カテゴリ | 公開時刻 | 備考 |
| --- | --- | --- | --- |
| `animal` | 動物 | 07:30 | 朝の軽い視聴枠 |
| `food_drink` | 食べ物・飲み物 | 12:00 | 昼食・休憩枠 |
| `body_health` | 人体・健康 | 18:00 | 夕方の帰宅・休憩枠 |

### 3カテゴリ化後の運用方針

- 3カテゴリに減った分、短時間に詰め込まず、朝・昼・夕方の3枠に分散する。
- 21:00と25:00の旧枠は使わない。夜枠を増やして本数を補うより、各動画の品質と説明欄の補足を優先する。
- `Lv雑学作成予約` は不足している3カテゴリだけを作成し、カテゴリ外の在庫は作らない。
- 作成後の validate と contact sheet QA が通った場合だけ、対象日分3本を Private upload し、YouTube `publishAt` で予約する。

## 動画作成の基本手順

1. テーマを選ぶ。
2. 出典確認・事実確認を行う。
3. 台本を作る。
4. 雑学ニキ用のトーン、画作り、音声で素材を作る。
5. 雑学ニキ用のレンダースクリプトで動画を書き出す。
6. contact sheet を作成し、字幕・レイアウト・出典・権利・AI生成開示の必要性を確認する。
   - 各カードの画像が題材に直接合っているか確認する。
   - シャコにタコ、ミツバチに巣だけ、胃に食事中の人物だけのような「近そうなだけの代用」は不可。
   - 同じ動画内、または直近動画との画像使い回しが多すぎないか確認する。
7. `metadata.md` と `stock.yaml` を更新する。
8. `stock.yaml` に `visual_audit` を記録し、`ruby scripts/zatsugaku_inventory.rb validate` を通す。
9. 未投稿動画は `status: stock` として保存する。
10. `Lv雑学作成予約` が `next-missing-set` の対象日・レベル・カテゴリの在庫を `status: scheduled` にし、Private upload 後に `status: uploaded` と `video_id` を記録する。

## BGMルール

- 動画作成時は、原則として `Escort / もっぴーさうんど（DOVA-SYNDROME）` をBGMとして薄く入れる。
- BGMファイル: `/Users/yota/Projects/Automation/Youtube/_shared/bgm/dova-syndrome/escort_moppy_sound.mp3`
- 標準音量はナレーション `1.0`、BGM `0.10`。声が聞き取りづらい場合はBGMを `0.06〜0.08` に下げる。
- 動画説明欄に `BGM: Escort / もっぴーさうんど（DOVA-SYNDROME）` を入れる。
- レンダー後、BGMが声を邪魔していないか必ず確認する。

## 完了条件

1. 最新MP4が `renders/stock/<level>/<category_key>/<id>/` にある。
2. contact sheet を作成し、視覚確認済み。
3. タイトル、説明文がある。説明文には `【詳細・補足】` を作り、各雑学を番号付きで細かく補足する。
4. `metadata/stock/<level>/<category_key>/<id>/stock.yaml` を作成済み。
5. YAMLの `status` は未投稿なら `stock`、予約対象なら `scheduled`、アップロード済みなら `uploaded`。
6. `topic_key` と `fact_summary` があり、過去投稿と重複しない。
7. `visual_audit` で画像の題材一致、無関係な代用なし、過剰な使い回しなしを確認済み。
8. `ruby scripts/zatsugaku_inventory.rb validate` が通る。

## category_key

| category_key | カテゴリ |
| --- | --- |
| `animal` | 動物 |
| `food_drink` | 食べ物・飲み物 |
| `body_health` | 人体・健康 |

## レベル運用

- Lv1: 広く伝わる、わかりやすい雑学
- Lv2: 少し意外性があるが、まだ身近な雑学
- Lv3: 仕組みや背景が少し濃い雑学
- Lv4: 数字・歴史・仕組みなどの専門性が強い雑学
- Lv5: 博士級として扱う深めの雑学

## Lv雑学作成予約 確認コマンド

```bash
ruby scripts/zatsugaku_inventory.rb validate
ruby scripts/zatsugaku_inventory.rb plan --date <target-date> --dry-run
ruby scripts/zatsugaku_inventory.rb upload-due --dry-run
scripts/zatsugaku_api_automation.sh dry-run
```

作成後は `ruby scripts/zatsugaku_inventory.rb plan --date <next-missing-set の date>` と `ruby scripts/zatsugaku_inventory.rb upload-due` を実行する。
ローカルの YouTube API secret env を使い、コメント投稿は行わない。

## YAML作成時の注意

- `video_path` と `contact_sheet_path` は絶対パスにする。
- `topic_key` は英数字・snake_caseで、同じ内容なら同じキーになるようにする。
- `fact_summary` は重複検知用に、動画全体の事実内容を短く書く。
- 新規動画を考える前に `metadata/stock/**/stock.yaml` の同カテゴリ `topic_key` / `fact_summary` を確認し、同じ題材・同じ食品・同じ人体部位の被りすぎを避ける。
- `Lv雑学作成予約` は `ruby scripts/zatsugaku_inventory.rb next-missing-set --date today` の結果を見て、不足している level / category の在庫を作る。
- 作成後、同じ automation 内で `ruby scripts/zatsugaku_inventory.rb plan --date <next-missing-set の date>` を実行して対象日分を予約対象にし、`ruby scripts/zatsugaku_inventory.rb upload-due` で YouTube API に Private upload する。
- 下書き後に `ruby scripts/zatsugaku_inventory.rb overlap-report --category <category_key>` で被り候補を確認する。
- `description` は公開時にそのまま使われるため、`【詳細・補足】` の下に各雑学の仕組み・例外・注意点を2〜3文程度で書く。
- コメント投稿APIは使わない。補足・出典・誘導は `description` に集約する。
- 2026-04-29 12:30 JST 以降に作る新規在庫は、`visual_audit` に次の項目が必要。
  - `contact_sheet_checked: true`
  - `image_subject_match_checked: true`
  - `no_unrelated_placeholder_images: true`
  - `no_excessive_reuse: true`
  - `checked_at`
  - `notes`
- `plan` / `upload-due` / `next-missing-set` は、作成日時に関係なく `visual_audit` 済みの在庫だけを使用対象にする。未確認の古い在庫は自動予約・自動アップロードしない。
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

