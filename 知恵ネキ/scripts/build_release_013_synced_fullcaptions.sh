#!/bin/zsh
set -euo pipefail
ROOT="/Users/yota/Projects/Automation/Youtube/知恵ネキ"
SLUG="release_013_reply_trust_synced_fullcaptions"
BUILD="$ROOT/assets/generated/$SLUG"
IMG_DIR="$BUILD/real_images"
OUT="$ROOT/renders/$SLUG.mp4"
mkdir -p "$IMG_DIR" "$ROOT/renders" "$ROOT/metadata/generated"

python3 - <<'PY'
import json, pathlib, shutil
root=pathlib.Path('/Users/yota/Projects/Automation/Youtube/知恵ネキ')
slug='release_013_reply_trust_synced_fullcaptions'
build=root/'assets/generated'/slug
img_dir=build/'real_images'
img_dir.mkdir(parents=True,exist_ok=True)
src_dir=root/'assets/generated/release_009_reply_trust_hq/real_images'
sources=[src_dir/f'frame_{i:02d}.png' for i in range(1,8)]
# Each item is one actual spoken segment, so scene duration == this audio duration.
items=[
('返信が遅いだけで\n信用は落ちる', '返信が遅いだけで、信用は落ちる。', ['信用'], 1),
('返信が遅くなりがちな人は\n完璧な返事を作ろうとして', '返信が遅くなりがちな人は、完璧な返事を作ろうとして、', ['返信','完璧な返事'], 2),
('逆に信用を\n落とすことがあります', '逆に信用を落とすことがあります。', ['信用'], 2),
('相手が不安になるのは\n答えが遅いことだけではありません', '相手が不安になるのは、答えが遅いことだけではありません。', ['不安','遅い'], 3),
('見ているのか\n忘れているのか', '見ているのか、忘れているのか、', ['見ている','忘れている'], 4),
('判断できないことです', '判断できないことです。', ['判断できない'], 4),
('だから、すぐ答えられない時は\n中間返信を入れます', 'だから、すぐ答えられない時は、中間返信を入れます。', ['中間返信'], 5),
('確認します。\n今日の夕方までに返します。', '確認します。今日の夕方までに返します。', ['確認します','夕方'], 5),
('これだけで\n全然違います', 'これだけで、全然違います。', ['全然違います'], 6),
('たとえば、少し確認が必要なので\n十五時までに一度返します', 'たとえば、少し確認が必要なので、十五時までに一度返します。', ['十五時','一度返します'], 4),
('こう言われると、相手は\n待つ予定を立てられます', 'こう言われると、相手は待つ予定を立てられます。', ['待つ予定'], 4),
('逆に、既読だけで放置すると', '逆に、既読だけで放置すると、', ['既読','放置'], 6),
('相手の頭の中では\n不安が勝手に大きくなります', '相手の頭の中では、不安が勝手に大きくなります。', ['不安'], 6),
('悪気がなくても損です', '悪気がなくても損です。', ['損'], 6),
('丁寧な長文より\n早い一言が信用を守る場面は多いです', '丁寧な長文より、早い一言が信用を守る場面は多いです。', ['早い一言','信用'], 7),
('完璧に答える前に\nまず受け取ったことを伝えます', '完璧に答える前に、まず受け取ったことを伝えます。', ['受け取った'], 7),
('まとめると、すぐ返せない時は\n確認します、何時までに返します', 'まとめると、すぐ返せない時は、確認します、何時までに返します。', ['確認します','何時まで'], 1),
('この一言だけで\n返信の印象はかなり変わります', 'この一言だけで、返信の印象はかなり変わります。', ['一言','印象'], 1),
]
scenes=[]; audio=[]
for i,(sub,voice,hi,srcidx) in enumerate(items,1):
    dst=img_dir/f'frame_{i:02d}.png'
    shutil.copy2(sources[srcidx-1], dst)
    tf=build/f'voice_segment_{i:02d}.txt'
    tf.write_text(voice,encoding='utf-8')
    audio.append(str(build/f'voicevox_segment_{i:02d}.wav'))
    scenes.append({'tag':'','title':'','subtitle':sub,'highlightWords':hi,'imageFile':str(dst)})
manifest={'width':1080,'height':1920,'fps':18,'badge':'','footer':'','pauseSeconds':0.03,'showCounter':False,'segmentAudioFiles':audio,'scenes':scenes}
(build/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
meta=f'''# {slug}\n\n## Title\n返信が遅くても信用を落とさない一言 #shorts\n\n## Description\nすぐ返せない時ほど、先に一言だけ返す。完璧な返信より、相手を不安にさせない中間返信が信用を守ります。\n\n#人間関係 #仕事術 #返信 #処世術 #shorts\n\n## Video\n/Users/yota/Projects/Automation/Youtube/知恵ネキ/renders/{slug}.mp4\n'''
(root/'metadata/generated'/f'{slug}.md').write_text(meta,encoding='utf-8')
print('prepared', len(items), 'segments')
PY

# Generate one audio file per displayed subtitle.
text_files=($BUILD/voice_segment_*.txt)
VOICEVOX_SPEED=1.25 python3 "$ROOT/scripts/synthesize_voicevox_segments.py" 47 "$BUILD" "${text_files[@]}"
wavs=($BUILD/voicevox_segment_*.wav)
swift "$ROOT/scripts/concat_audio_files.swift" "$BUILD/voice.m4a" 0.03 "${wavs[@]}"
DURATION=$(afinfo "$BUILD/voice.m4a" | awk '/estimated duration/ {print $3; exit}')
python3 "$ROOT/scripts/generate_mood_bgm.py" "$DURATION" calm "$BUILD/bgm.wav"
swift "$ROOT/scripts/mix_voice_bgm.swift" "$BUILD/voice.m4a" "$BUILD/bgm.wav" "$BUILD/mixed.m4a" 1.0 0.23
swiftc -O -o /tmp/render_fullcaptions_short "$ROOT/scripts/render_fullcaptions_short.swift"
/tmp/render_fullcaptions_short "$BUILD/manifest.json" "$BUILD/mixed.m4a" "$OUT"
echo "$OUT"
