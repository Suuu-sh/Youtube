#!/bin/zsh
set -euo pipefail
ROOT="/Users/yota/Projects/Automation/Youtube/知恵ネキ"
OUT_DIR="$ROOT/renders"
META_DIR="$ROOT/metadata/generated"
mkdir -p "$OUT_DIR" "$META_DIR"
RENDER_BIN="/tmp/render_reference_clean_short"
swiftc -O -o "$RENDER_BIN" "$ROOT/scripts/render_reference_clean_short.swift"

python3 - <<'PY'
import json, pathlib, shutil
ROOT=pathlib.Path('/Users/yota/Projects/Automation/Youtube/知恵ネキ')
base_imgs=[
'/Users/yota/Projects/Automation/Youtube/知恵ネキ/assets/generated/release_002_refusal_wisdom_55s/real_images/frame_01.png',
'/Users/yota/Projects/Automation/Youtube/知恵ネキ/assets/generated/release_002_refusal_wisdom_55s/real_images/frame_02.png',
'/Users/yota/Projects/Automation/Youtube/知恵ネキ/assets/generated/release_002_refusal_wisdom_55s/real_images/frame_03.png',
'/Users/yota/Projects/Automation/Youtube/知恵ネキ/assets/generated/release_002_refusal_wisdom_55s/real_images/frame_04.png',
'/Users/yota/Projects/Automation/Youtube/知恵ネキ/assets/generated/release_002_refusal_wisdom_55s/real_images/frame_05.png',
'/Users/yota/Projects/Automation/Youtube/知恵ネキ/assets/generated/release_002_refusal_wisdom_55s/real_images/frame_06.png',
'/Users/yota/Projects/Automation/Youtube/知恵ネキ/assets/generated/release_002_refusal_wisdom_55s/real_images/frame_07.png',
'/Users/yota/Projects/Automation/Youtube/知恵ネキ/assets/generated/release_002_refusal_wisdom_55s/real_images/frame_08.png',
'/Users/yota/Projects/Automation/Youtube/知恵ネキ/assets/generated/release_002_refusal_wisdom_55s/real_images/frame_09.png',
'/Users/yota/Projects/Automation/Youtube/知恵ネキ/assets/generated/short_008_psych_5_bgm/real_images/frame_02.png',
'/Users/yota/Projects/Automation/Youtube/知恵ネキ/assets/generated/short_008_psych_5_bgm/real_images/frame_03.png',
'/Users/yota/Projects/Automation/Youtube/知恵ネキ/assets/generated/short_008_psych_5_bgm/real_images/frame_05.png',
'/Users/yota/Projects/Automation/Youtube/知恵ネキ/assets/generated/short_008_psych_5_bgm/real_images/frame_07.png',
'/Users/yota/Projects/Automation/Youtube/知恵ネキ/assets/generated/short_008_psych_5_bgm/real_images/frame_10.png',
'/Users/yota/Projects/Automation/Youtube/知恵ネキ/assets/generated/short_008_psych_5_bgm/real_images/frame_12.png',
]
videos=[
{
'slug':'release_005_report_first', 'mood':'work', 'badge':'上手く生きる知恵',
'title':'仕事で信用される報告は、順番が違う #shorts',
'description':'仕事で信用を落としにくい報告の順番。悪い報告ほど「結論→影響→次の一手」で伝えると、相手は判断しやすくなります。\n\n#仕事術 #報告 #処世術 #知恵ネキ #shorts',
'img_offset':0,
'voice':[
'仕事で信用される人は、報告の順番が違います。特に悪い報告ほど、ここで差が出ます。',
'よくある失敗は、言い訳から入ることです。事情を全部話してから、最後に問題を言う。これだと相手は不安になります。',
'先に言うのは結論です。何が起きたのか。次に影響です。どこまで困るのか。最後に次の一手です。どう動くのか。',
'たとえば、納期が遅れそうです。影響は一日です。今日中に代案を二つ出します。これだけで判断しやすくなります。',
'大事なのは、怒られない説明をすることではありません。相手が次の判断をできる情報を、先に渡すことです。',
'悪い報告を早く短く出せる人は、ミスしても信用が残ります。隠す人より、動ける人だと思われるからです。',
'まとめると、悪い報告は、結論、影響、次の一手。この順番だけ覚えておくと、仕事の信用はかなり守れます。'
],
'scenes':[('仕事術','報告で信用は変わる','悪い報告ほど\n先に結論', ['悪い報告','結論']),('失敗例','言い訳から入らない','事情を並べるほど\n相手は不安になる',['言い訳','不安']),('型','結論 影響 次の一手','何が起きたか\nどこまで困るか\nどう動くか',['結論','影響','次の一手']),('具体例','納期が遅れそうな時','一日遅れます\n今日中に代案を出します',['一日','代案']),('本質','判断材料を渡す','怒られない説明より\n相手が動ける情報',['判断材料','動ける']),('信用','早い報告は信頼になる','ミスしても\n動ける人に見える',['早い報告','信頼']),('まとめ','報告は順番で決まる','結論 影響 次の一手\nこの順番で守る',['結論','影響','次の一手'])]
},
{
'slug':'release_006_request_specific', 'mood':'social', 'badge':'上手く生きる知恵',
'title':'頼みごとが通りやすい人は、お願いが具体的 #shorts',
'description':'頼みごとが通りやすい人は、相手に考えさせる量を減らしています。「いつまでに・何を・どのくらい」を先に出すだけで返事が変わります。\n\n#人間関係 #仕事術 #頼み方 #処世術 #shorts',
'img_offset':4,
'voice':[
'頼みごとが通りやすい人は、押しが強いわけではありません。お願いが具体的なんです。',
'やってもらえませんか、だけだと相手は考えることが多すぎます。いつ、何を、どれくらい。全部相手に考えさせています。',
'通りやすい頼み方は、相手の負担を先に小さく見せます。十分だけ、明日の午前まで、この一箇所だけ。こういう形です。',
'たとえば、資料を見てください、ではなく、三ページ目の数字だけ、今日の夕方までに確認してほしいです。これなら動きやすい。',
'さらに、断る余地も残すと強いです。難しければ明日でも大丈夫です、と添えるだけで、圧が減ります。',
'人は頼まれること自体より、面倒そう、重そう、逃げられなさそう、という感覚で断りたくなります。',
'まとめると、お願いは、短く、具体的に、逃げ道を残す。この三つで、相手はかなり動きやすくなります。'
],
'scenes':[('人間関係','頼み方で結果は変わる','通るお願いは\n具体的', ['具体的']),('失敗例','丸投げにしない','やってくださいだけだと\n相手が考える量が多い',['丸投げ','考える量']),('型','いつ 何を どれくらい','負担を先に\n小さく見せる',['いつ','何を','どれくらい']),('具体例','資料確認を頼む時','三ページ目の数字だけ\n今日の夕方まで',['三ページ目','夕方']),('コツ','逃げ道を残す','難しければ明日でも\n大丈夫です',['逃げ道','明日でも']),('理由','人は重そうな依頼を避ける','面倒そう\n逃げられなさそうが危険',['重そう','危険']),('まとめ','お願いは設計できる','短く 具体的に\n逃げ道を残す',['短く','具体的','逃げ道'])]
},
{
'slug':'release_007_habit_no_motivation', 'mood':'focus', 'badge':'上手く生きる知恵',
'title':'習慣が続く人は、やる気に頼っていない #shorts',
'description':'習慣が続く人は、やる気が強いのではなく、始める摩擦を減らしています。小さく・同じ時間に・見える場所へ置くのがコツです。\n\n#習慣化 #自己管理 #仕事術 #処世術 #shorts',
'img_offset':7,
'voice':[
'習慣が続く人は、意志が強い人ではありません。やる気に頼らない仕組みにしている人です。',
'多くの人は、明日からちゃんとやろう、と決めます。でも明日の自分は、今日の自分よりやる気があるとは限りません。',
'続けるコツは、始めるまでの摩擦を減らすことです。準備が面倒な習慣は、かなりの確率で止まります。',
'たとえば読書なら、一時間読むではなく、一ページだけ読む。机の上に本を開いて置く。これで始める壁が下がります。',
'運動も同じです。着替えてジムに行く、では重い。まずスクワット十回だけ。小さすぎるくらいでいいです。',
'習慣は、気合いで続けるものではありません。毎日同じ時間、同じ場所で、何も考えず始まるように設計します。',
'まとめると、習慣は小さく始める。見える場所に置く。同じ時間にやる。やる気より、環境を信じてください。'
],
'scenes':[('習慣','続く人は意志が強い？','本当は\n仕組みが強い', ['仕組み']),('落とし穴','明日のやる気を信じない','明日の自分は\n意外と疲れている',['明日の自分','疲れている']),('本質','摩擦を減らす','始めるまでが重いと\n続かない',['摩擦','続かない']),('具体例 読書','一ページだけ読む','本を開いて置くと\n始める壁が下がる',['一ページ','壁']),('具体例 運動','十回だけでいい','小さすぎるくらいが\n続けやすい',['十回','小さすぎる']),('設計','同じ時間 同じ場所','考えず始まる形を\n先に作る',['同じ時間','同じ場所']),('まとめ','やる気より環境','小さく始めて\n見える場所に置く',['やる気','環境'])]
},
{
'slug':'release_008_money_wait_24h', 'mood':'money', 'badge':'上手く生きる知恵',
'title':'無駄遣いを減らすなら、買う前に24時間置く #shorts',
'description':'無駄遣いを減らすコツは、我慢ではなく時間を置くこと。欲しいと思った瞬間の熱を冷ますだけで、本当に必要なものが見えやすくなります。\n\n#お金の知恵 #節約 #習慣 #処世術 #shorts',
'img_offset':10,
'voice':[
'無駄遣いを減らしたいなら、意志の力で我慢するより、買う前に二十四時間置く方が効きます。',
'人は、欲しいと思った瞬間がいちばん判断が甘いです。限定、セール、残りわずか。この言葉で今買う理由を作ります。',
'でも二十四時間置くと、欲しい熱が少し下がります。その時にまだ必要なら、買っても後悔しにくいです。',
'具体的には、カートに入れるだけで決済しない。メモに商品名と値段を書く。次の日の同じ時間にもう一度見る。',
'ここで、使う場面が三つ言えないものは、だいたい雰囲気で欲しくなっているだけです。',
'節約は、全部を我慢することではありません。本当に使うものにお金を残すために、熱で買う回数を減らすことです。',
'まとめると、欲しいと思ったら二十四時間置く。使う場面を三つ言えるか確認する。これだけで無駄遣いはかなり減ります。'
],
'scenes':[('お金の知恵','買う前に24時間置く','我慢より\n時間を置く', ['24時間','時間']),('理由','欲しい瞬間は判断が甘い','限定 セール 残りわずかで\n今買う理由を作る',['限定','セール']),('効果','熱が下がる','翌日まだ必要なら\n後悔しにくい',['熱','必要']),('具体例','カートで止める','決済せず\n次の日にもう一度見る',['カート','次の日']),('確認','使う場面を三つ言える？','言えないなら\n雰囲気で欲しいだけ',['三つ','雰囲気']),('本質','節約は我慢ではない','本当に使うものに\nお金を残す',['我慢','残す']),('まとめ','熱で買わない','24時間置いて\n使う場面を確認',['24時間','確認'])]
},
{
'slug':'release_009_reply_trust', 'mood':'calm', 'badge':'上手く生きる知恵',
'title':'返信が遅くても信用を落とさない一言 #shorts',
'description':'すぐ返せない時ほど、先に一言だけ返す。完璧な返信より、相手を不安にさせない中間返信が信用を守ります。\n\n#人間関係 #仕事術 #返信 #処世術 #shorts',
'img_offset':2,
'voice':[
'返信が遅くなりがちな人は、完璧な返事を作ろうとして、逆に信用を落とすことがあります。',
'相手が不安になるのは、答えが遅いことだけではありません。見ているのか、忘れているのか、判断できないことです。',
'だから、すぐ答えられない時は、中間返信を入れます。確認します。今日の夕方までに返します。これだけで全然違います。',
'たとえば、少し確認が必要なので、十五時までに一度返します。こう言われると、相手は待つ予定を立てられます。',
'逆に、既読だけで放置すると、相手の頭の中では不安が勝手に大きくなります。悪気がなくても損です。',
'丁寧な長文より、早い一言が信用を守る場面は多いです。完璧に答える前に、まず受け取ったことを伝えます。',
'まとめると、すぐ返せない時は、確認します、何時までに返します。この一言だけで、返信の印象はかなり変わります。'
],
'scenes':[('人間関係','返信で信用は変わる','完璧な返事より\n早い一言', ['早い一言']),('不安','相手が困る理由','見たのか忘れたのか\n判断できない',['判断できない']),('型','中間返信を入れる','確認します\n夕方までに返します',['確認します','夕方']),('具体例','待つ予定を作る','15時までに\n一度返します',['15時','一度返します']),('NG','既読だけで放置しない','不安は勝手に\n大きくなる',['既読','不安']),('信用','受け取ったことを伝える','長文より先に\n一言だけ返す',['受け取った','一言']),('まとめ','返信は途中でもいい','確認します\n何時までに返します',['確認します','何時まで'])]
}
]
for v in videos:
    b=ROOT/'assets/generated'/v['slug']; imgd=b/'real_images'; imgd.mkdir(parents=True,exist_ok=True)
    segs=[]; scenes=[]
    for i,sc in enumerate(v['scenes'],1):
        src=base_imgs[(v['img_offset']+i-1)%len(base_imgs)]
        dest=imgd/f'frame_{i:02d}.png'; shutil.copy2(src,dest)
        tag,title,subtitle,high=sc
        scenes.append({'tag':tag,'title':title,'subtitle':subtitle,'highlightWords':high,'imageFile':str(dest)})
    for i,text in enumerate(v['voice'],1):
        tf=b/f'voice_segment_{i:02d}.txt'; tf.write_text(text,encoding='utf-8')
        segs.append(str(b/f'voicevox_segment_{i:02d}.wav'))
    manifest={'width':1080,'height':1920,'fps':18,'badge':v['badge'],'footer':'','pauseSeconds':0.08,'showCounter':False,'segmentAudioFiles':segs,'scenes':scenes}
    (b/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    meta=f"""# {v['slug']}\n\n## Title\n{v['title']}\n\n## Description\n{v['description']}\n\n## Video\n/Users/yota/Projects/Automation/Youtube/知恵ネキ/renders/{v['slug']}.mp4\n\n## Voice\nVOICEVOX ナースロボ＿タイプＴ ノーマル speed 1.25\n\n## BGM\nLocal generated original mood BGM: {v['mood']}\n"""
    (ROOT/'metadata/generated'/f"{v['slug']}.md").write_text(meta,encoding='utf-8')
(ROOT/'metadata/generated/release_batch_005_009.json').write_text(json.dumps(videos,ensure_ascii=False,indent=2),encoding='utf-8')
print('Prepared', len(videos), 'videos')
PY

for slug in release_005_report_first release_006_request_specific release_007_habit_no_motivation release_008_money_wait_24h release_009_reply_trust; do
  BUILD_DIR="$ROOT/assets/generated/$slug"
  echo "== Voice: $slug =="
  text_files=($BUILD_DIR/voice_segment_*.txt)
  VOICEVOX_SPEED=1.25 python3 "$ROOT/scripts/synthesize_voicevox_segments.py" 47 "$BUILD_DIR" "${text_files[@]}"
  echo "== Concat audio: $slug =="
  wavs=($BUILD_DIR/voicevox_segment_*.wav)
  swift "$ROOT/scripts/concat_audio_files.swift" "$BUILD_DIR/voice.m4a" 0.08 "${wavs[@]}"
  DURATION=$(afinfo "$BUILD_DIR/voice.m4a" | awk '/estimated duration/ {print $3; exit}')
  mood=$(python3 - "$slug" <<'PY'
import json,sys
vs=json.load(open('/Users/yota/Projects/Automation/Youtube/知恵ネキ/metadata/generated/release_batch_005_009.json'))
print(next(v['mood'] for v in vs if v['slug']==sys.argv[1]))
PY
)
  python3 "$ROOT/scripts/generate_mood_bgm.py" "$DURATION" "$mood" "$BUILD_DIR/bgm.wav"
  swift "$ROOT/scripts/mix_voice_bgm.swift" "$BUILD_DIR/voice.m4a" "$BUILD_DIR/bgm.wav" "$BUILD_DIR/mixed.m4a" 1.0 0.23
  echo "== Render: $slug =="
  "$RENDER_BIN" "$BUILD_DIR/manifest.json" "$BUILD_DIR/mixed.m4a" "$OUT_DIR/$slug.mp4"
done
