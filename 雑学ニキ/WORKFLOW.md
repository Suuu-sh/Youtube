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

- Codex app の `雑学ニキ stock maker` は、在庫補充用の動画制作だけを行う。
- YouTube API による自動アップロード、予約公開、コメント投稿は使わない。
- 投稿やアップロードは、ユーザーが明示的に依頼した場合だけ手動で行う。
- 詳細・補足は `description` に集約する。
- コメント投稿用の文面やキューは作らない。

## 動画作成の基本手順

1. テーマを選ぶ。
2. 出典確認・事実確認を行う。
3. 台本を作る。
4. 雑学ニキ用のトーン、画作り、音声で素材を作る。
5. 雑学ニキ用のレンダースクリプトで動画を書き出す。
6. contact sheet を作成し、字幕・レイアウト・出典・権利・AI生成開示の必要性を確認する。
7. `metadata.md` と `stock.yaml` を更新する。
8. `ruby scripts/zatsugaku_inventory.rb validate` を通す。
9. stock maker が実行されている場合も、アップロードは行わず在庫として保存する。
10. ユーザーが明示的に依頼した場合だけ Private upload する。

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
5. YAMLの `status` は未投稿なら `stock`、投稿済みなら `uploaded`。
6. `topic_key` と `fact_summary` があり、過去投稿と重複しない。
7. `ruby scripts/zatsugaku_inventory.rb validate` が通る。

## category_key

| category_key | カテゴリ |
| --- | --- |
| `animal` | 動物 |
| `food_drink` | 食べ物・飲み物 |
| `body_health` | 人体・健康 |
| `science_tech` | 科学・テクノロジー |
| `scary_danger` | 怖い・危険 |

## レベル運用

- Lv1: 広く伝わる、わかりやすい雑学
- Lv2: 少し意外性があるが、まだ身近な雑学
- Lv3: 仕組みや背景が少し濃い雑学
- Lv4: 数字・科学・歴史などの専門性が強い雑学
- Lv5: 博士級として扱う深めの雑学

## YAML作成時の注意

- `video_path` と `contact_sheet_path` は絶対パスにする。
- `topic_key` は英数字・snake_caseで、同じ内容なら同じキーになるようにする。
- `fact_summary` は重複検知用に、動画全体の事実内容を短く書く。
- 新規動画を考える前に `metadata/stock/**/stock.yaml` の同カテゴリ `topic_key` / `fact_summary` を確認し、同じ題材・同じ食品・同じ人体部位・同じ危険/技術テーマの被りすぎを避ける。
- stock maker は `ruby scripts/zatsugaku_inventory.rb next-missing-set --date today` の結果を見て、不足している level / category の在庫を作る。
- 下書き後に `ruby scripts/zatsugaku_inventory.rb overlap-report --category <category_key>` で被り候補を確認する。
- `description` は公開時にそのまま使われるため、`【詳細・補足】` の下に各雑学の仕組み・例外・注意点を2〜3文程度で書く。
- コメント投稿APIは使わない。補足・出典・誘導は `description` に集約する。
