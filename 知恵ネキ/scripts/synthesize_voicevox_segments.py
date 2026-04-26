#!/usr/bin/env python3
import json, os, pathlib, sys, urllib.parse, urllib.request

if len(sys.argv) < 5:
    print('Usage: synthesize_voicevox_segments.py <speaker_id> <out_dir> <text1> [<text2> ...]', file=sys.stderr)
    sys.exit(1)

speaker = int(sys.argv[1])
out_dir = pathlib.Path(sys.argv[2])
out_dir.mkdir(parents=True, exist_ok=True)
text_files = [pathlib.Path(p) for p in sys.argv[3:]]
base = 'http://127.0.0.1:50021'
speed_scale = float(os.environ.get('VOICEVOX_SPEED', '1.50'))

def post_json(path, params=None, body=None):
    url = base + path
    if params:
        url += '?' + urllib.parse.urlencode(params)
    data = json.dumps(body or {}, ensure_ascii=False).encode('utf-8')
    req = urllib.request.Request(url, data=data, headers={'Content-Type':'application/json'}, method='POST')
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read().decode('utf-8'))

def post_bytes(path, params=None, body=None):
    url = base + path
    if params:
        url += '?' + urllib.parse.urlencode(params)
    data = json.dumps(body or {}, ensure_ascii=False).encode('utf-8')
    req = urllib.request.Request(url, data=data, headers={'Content-Type':'application/json'}, method='POST')
    with urllib.request.urlopen(req) as r:
        return r.read()

outs=[]
for idx, tf in enumerate(text_files, 1):
    text = tf.read_text().strip()
    query = post_json('/audio_query', {'text': text, 'speaker': speaker})
    # Shorts向けに速め。VOICEVOX_SPEED で調整可能（例: 1.35〜1.55）
    query['speedScale'] = speed_scale
    query['intonationScale'] = 1.08
    query['volumeScale'] = 1.0
    wav = post_bytes('/synthesis', {'speaker': speaker}, query)
    out = out_dir / f'voicevox_segment_{idx:02d}.wav'
    out.write_bytes(wav)
    outs.append(str(out))
    print(out)
