# 雑学ニキ

雑学解説系チャンネル用の作業領域です。
知恵ネキとは素材、台本形式、投稿手順、検証観点を分けて管理します。

## ディレクトリ

- `ideas/` — 企画、テーマ候補、構成メモ
- `prompts/` — 台本・リサーチ・メタデータ生成用プロンプト
- `metadata/stock/` — stock用メタデータとYAML
- `assets/generated/` — 生成画像、音声、manifest などの動画素材
- `renders/` — 書き出し済み mp4 と確認用画像
- `automation/` — アップロード、予約投稿、検証ログ
- `branding/` — チャンネルアイコン、トーン、デザインルール
- `scripts/` — 雑学ニキ向けの制作・投稿補助スクリプト
- `analytics/` — 投稿後の計測メモ

## 初期運用メモ

- 知恵ネキ用の素材やログを流用しない。
- 出典確認、事実確認、誤情報チェックを制作フローに含める。
- 投稿方法や使用する音声・BGM・画作りは、雑学ニキ用 README/手順書に追記していく。


## Lv運用ルール

- 雑学は `Lv1`〜`Lv5` で管理する。
- 基本運用は `Lv1` と `Lv2` を中心にする。
- `Lv3` と `Lv4` はたまに出すアクセント枠にする。
- `Lv5` はごく稀に出す特別枠にして、博士レベル感を残す。
- 大カテゴリはまず `動物`、`食べ物・飲み物`、`人体・健康`、`科学・テクノロジー`、`怖い・危険` の5種類を主軸にする。
- 動画の最後には `いくつわかりましたか？` カードを入れて、コメントしやすくする。

目安:

- Lv1: 知って損しない、日常で刺さる、広く分かる。
- Lv2: 知ってたらちょっとすごい、会話に使いやすい。
- Lv3: 知ってたら普通にすごい、理由や仕組みが少し深い。
- Lv4: 知ってたらかなりすごい、数字・研究・専門性が強い。
- Lv5: 知ってたら博士レベル、希少性と意外性が高い。

## Private upload・コメント運用

- 動画作成が完了したら、原則として毎回 YouTube へ Private upload する。
- ログインは Automation プロファイル（`automationai1223@gmail.com`）を使う。
- ユーザーから明示がない限り、Public化や予約公開はしない。
- 投稿ごとにコメント案を作り、メタデータと完了報告に含める。
- コメント案は短い誘導だけにせず、各雑学の補足を番号付きで書く。

## BGMルール

- 動画作成時は、原則として `Escort / もっぴーさうんど（DOVA-SYNDROME）` をBGMとして薄く入れる。
- BGMファイル: `/Users/yota/Projects/Automation/Youtube/_shared/bgm/dova-syndrome/escort_moppy_sound.mp3`
- 標準音量はナレーション `1.0`、BGM `0.50`。声が聞き取りづらい場合はBGMを `0.35〜0.45` に下げる。
- 動画説明欄に `BGM: Escort / もっぴーさうんど（DOVA-SYNDROME）` を入れる。
- レンダー後、BGMが声を邪魔していないか必ず確認する。

## 現在の投稿運用（他スレッド向け要約）

このワークスペースの現在の方針は **4時 automation が在庫補充用の動画制作まで行い、YouTube API処理も automation が行う** です。
他スレッドで作業する場合も、まずこの運用を前提にしてください。

### 役割分担

- 手動 / Codex 5.5 で行うこと
  - 明示依頼がある単発動画の制作・確認
- Codex automation で行うこと
  - 4時ジョブの冒頭で、動画作成前リサーチ用に公開RSS/Atomをスクレイピングして `research/daily/` に保存
  - その日の5投稿を既存在庫から予約・アップロード
  - 次に在庫が不足する投稿日を先読みし、そのレベルの動画を5カテゴリ分追加制作
  - MP4 / contact sheet / metadata / stock YAML を作成
  - YouTube Data APIで Private upload
  - `publishAt` を設定して予約公開
  - upload成功時に返る `id` を `video_id` としてYAMLに保存
  - 公開後に `comment_text` を投稿

### 完成動画を作ったら必ず作るもの

自動投稿に回す動画は、MP4だけではなく次の YAML を必ず作ります。

```text
metadata/stock/<level>/<category_key>/<id>/stock.yaml
```

YAMLがない動画は automation から見えないため、自動 upload / schedule / comment の対象になりません。

### stockメタデータの保存場所

動画ごとの投稿用メタデータと automation YAML は、動画・素材と同じ level / category / id でまとめます。

```text
metadata/stock/<level>/<category_key>/<id>/
  metadata.md
  stock.yaml
```


### stock動画の保存場所

automation stock 用の動画と確認素材は、見返しやすいように次のフォルダへまとめます。

```text
renders/stock/<level>/<category_key>/<id>/
```

例:

```text
renders/stock/lv1/animal/zatsugaku_animal_lv1_001/
  zatsugaku_animal_lv1_001_bgm050.mp4
  zatsugaku_animal_lv1_001_raw.mp4
  contact.png
  frame_01_before.png
  frame_01_after.png
  times.txt
```

YAML の `video_path` と `contact_sheet_path` は、このフォルダ内の絶対パスを指すようにします。

### stock素材の保存場所

動画生成時の素材も、同じく level / category / id でまとめます。

```text
assets/generated/stock/<level>/<category_key>/<id>/
```

古い実験動画・未使用MP4・参照切れのメタデータ・一時ファイル・手動アップロードログは残さない方針です。

### 今日の投稿を確認するコマンド

```bash
ruby scripts/zatsugaku_inventory.rb validate
ruby scripts/zatsugaku_inventory.rb plan --date today --dry-run
```

### automation本体

Codex app 側の automation は1つだけです。

```text
雑学ニキ API scheduler
```

実行するコマンドは次です。

```bash
scripts/zatsugaku_api_automation.sh run
```

04時台は「今日の5投稿を予約・アップロード」し、その後に `next-missing-set` で次に不足する投稿日レベルを判定して5本の在庫動画を追加制作します。コメント時刻の automation は due 判定された comment だけ処理します。
