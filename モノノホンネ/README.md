# モノノホンネ 試作

日用品の擬人化ショート動画を試作するためのワークスペースです。

## 生成済みサンプル

- `output/mononohonne_sample_10s_with_voice.mp4`
  - 10秒
  - 9:16 縦動画
  - 牛乳パック擬人化キャラ
  - 簡易アニメーション、字幕、macOS TTS音声入り

## 生成方法

```bash
swift scripts/generate_sample.swift
say -v Kyoko -r 290 -o output/narration.aiff '俺を捨てるな。牛乳パックは、まだ働ける。肉や魚を切るとき、広げて下に敷け。使い終わったら、そのまま処分できる。だから次から、即ゴミ箱はやめろ。'
swift scripts/mux_audio.swift
```

この試作はSora等の動画生成AIではなく、Codex側で作れる簡易アニメーションの確認用です。実運用では、Soraで作った短尺MP4を素材として差し替え、字幕・音声・BGM合成をこのワークスペースで自動化します。
