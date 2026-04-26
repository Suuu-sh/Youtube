# 知恵ネキ 制作・投稿手順

## 目的

「上手く生きる知恵」を短く、実用的に伝える Shorts を作る。
仕事術、人間関係、習慣、お金、SNS などを扱う。

## 材料の置き場所

- 企画: `ideas/`
- 画像・音声・manifest: `assets/generated/<slug>/`
- メタデータ: `metadata/generated/<slug>.md`
- 動画: `renders/<slug>.mp4`
- 確認画像: `renders/check_<slug>/contact.png`
- 投稿・予約・検証ログ: `automation/`
- ブランド素材: `branding/`

## 動画作成の基本手順

1. `ideas/theme_backlog.md` からカテゴリが偏らないようにテーマを選ぶ。
2. 25〜40秒目安で、フック・結論・理由・具体例・行動・締めの構成にする。
3. 各動画・各シーンごとに画像を新規生成する。
4. VOICEVOX ナースロボ＿タイプＴを基準にナレーションを作る。
5. `scripts/render_grouped_fullcaptions_short.swift` 系で縦動画を書き出す。
6. contact sheet で字幕、タイトルフレーム、画像品質、重複を確認する。
7. private で YouTube Studio へアップロードする。
8. YouTube Studio の公式音源を低音量で追加する。
9. 必要な場合だけ予約公開を設定する。

## 投稿方針

- デフォルトは private アップロード。
- 公開予約が必要な場合は、アップロード完了後にスケジュールを設定する。
- Shorts のカバーは、動画冒頭のタイトルフレームを使う前提で作る。
- 焼き込み BGM は原則使わず、YouTube Studio 側の公式音源を追加する。
