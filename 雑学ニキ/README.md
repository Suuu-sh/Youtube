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

- Codex app の `雑学ニキ stock maker` は、在庫補充用の動画制作だけを行う。
- YouTube API による自動アップロード、予約公開、コメント投稿は使わない。
- 投稿やアップロードは、ユーザーの明示依頼がある単発作業として行う。
- 詳細・補足は YouTube の `description` に集約する。
- 固定コメント用テキストやコメントキューは作らない。

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

## 確認コマンド

```bash
ruby scripts/zatsugaku_inventory.rb validate
ruby scripts/zatsugaku_inventory.rb next-missing-set --date today
ruby scripts/zatsugaku_inventory.rb overlap-report --category animal
```
