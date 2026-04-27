# 雑学ニキ

雑学解説系チャンネル用の作業領域です。
知恵ネキとは素材、台本形式、投稿手順、検証観点を分けて管理します。

## ディレクトリ

- `ideas/` — 企画、テーマ候補、構成メモ
- `prompts/` — 台本・リサーチ・メタデータ生成用プロンプト
- `metadata/generated/` — 投稿用メタデータ、動画仕様 JSON
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


## BGMルール

- 動画作成時は、原則として `Escort / もっぴーさうんど（DOVA-SYNDROME）` をBGMとして薄く入れる。
- BGMファイル: `/Users/yota/Projects/Automation/Youtube/_shared/bgm/dova-syndrome/escort_moppy_sound.mp3`
- 標準音量はナレーション `1.0`、BGM `0.10`。声が聞き取りづらい場合はBGMを `0.06〜0.08` に下げる。
- 動画説明欄に `BGM: Escort / もっぴーさうんど（DOVA-SYNDROME）` を入れる。
- レンダー後、BGMが声を邪魔していないか必ず確認する。

## 現在の投稿運用（他スレッド向け要約）

このワークスペースの現在の方針は **動画制作は手動、YouTube API処理は automation** です。
他スレッドで作業する場合も、まずこの運用を前提にしてください。

### 役割分担

- 手動 / Codex 5.5 で行うこと
  - ネタ選定、台本、VOICEVOX、動画レンダー、contact sheet確認
  - 投稿タイトル、説明文、固定コメント案の作成
  - 完成動画を automation 在庫に入れるための YAML 作成
- Codex automation で行うこと
  - 4時ジョブの冒頭で、動画作成前リサーチ用に公開RSS/Atomをスクレイピングして `research/daily/` に保存
  - YAML在庫から翌日分を選ぶ
  - YouTube Data APIで Private upload
  - `publishAt` を設定して予約公開
  - upload成功時に返る `id` を `video_id` としてYAMLに保存
  - 公開後に `comment_text` を投稿

### 完成動画を作ったら必ず作るもの

自動投稿に回す動画は、MP4だけではなく次の YAML を必ず作ります。

```text
metadata/videos/stock/<category_key>/<id>.yaml
```

YAMLがない動画は automation から見えないため、自動 upload / schedule / comment の対象になりません。

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

04時台だけ翌日5本を選んで Private upload + 予約公開し、それ以外の起動では due 判定された comment だけ処理します。
