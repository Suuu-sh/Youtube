# Escort / もっぴーさうんど

- Track: Escort
- Composer: もっぴーさうんど
- Source: DOVA-SYNDROME
- Track page: https://dova-s.jp/bgm/play12633.html
- Download page: https://dova-s.jp/bgm/detail/12633/download
- Local file: `/Users/yota/Projects/Automation/Youtube/_shared/bgm/dova-syndrome/escort_moppy_sound.mp3`

## 雑学ニキでの使い方

動画作成時は、このBGMを薄く敷く。

標準音量:

- ナレーション: `1.0`
- BGM: `0.50`

BGM入り動画を作る例:

```bash
cd /Users/yota/Projects/Automation/Youtube
swift _shared/youtube-scheduler/add_bgm_to_video.swift \
  雑学ニキ/renders/input.mp4 \
  _shared/bgm/dova-syndrome/escort_moppy_sound.mp3 \
  雑学ニキ/renders/output_bgm.mp4 \
  1.0 0.50
```

## クレジット表記

動画説明欄には以下を入れる。

```text
BGM: Escort / もっぴーさうんど（DOVA-SYNDROME）
```

DOVA-SYNDROMEのライセンスと利用規約は制作時に確認すること。
