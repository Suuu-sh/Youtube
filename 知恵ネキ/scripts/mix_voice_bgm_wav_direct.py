#!/usr/bin/env python3
import sys, wave, struct, math
if len(sys.argv) != 6:
    print('Usage: mix_voice_bgm_wav_direct.py <voice.wav> <bgm.wav> <out.wav> <voice_gain> <bgm_gain>', file=sys.stderr)
    sys.exit(1)
voice_path, bgm_path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
vg, bg = float(sys.argv[4]), float(sys.argv[5])

def read_wav(path):
    with wave.open(path, 'rb') as w:
        ch=w.getnchannels(); sw=w.getsampwidth(); sr=w.getframerate(); n=w.getnframes(); data=w.readframes(n)
    if sw != 2:
        raise SystemExit(f'{path}: only 16-bit wav supported')
    samples=list(struct.unpack('<'+'h'*(len(data)//2), data))
    return sr,ch,samples

vsr,vch,vs=read_wav(voice_path)
bsr,bch,bs=read_wav(bgm_path)
if vsr != bsr:
    raise SystemExit(f'sample rate mismatch: {vsr} vs {bsr}')
# normalize channel to stereo sample pairs
def to_stereo(samples,ch):
    if ch == 2: return samples
    if ch == 1:
        out=[]
        for x in samples: out += [x,x]
        return out
    raise SystemExit('unsupported channels')
vs=to_stereo(vs,vch); bs=to_stereo(bs,bch)
N=len(vs)
if len(bs)<N:
    reps=N//len(bs)+1
    bs=(bs*reps)[:N]
else:
    bs=bs[:N]

mixed=[]
for i in range(0,N,2):
    t=i/(2*vsr)
    # Make BGM definitely audible but duck slightly when voice is loud.
    vL=vs[i]/32768.0; vR=vs[i+1]/32768.0
    bL=bs[i]/32768.0; bR=bs[i+1]/32768.0
    voice_level=(abs(vL)+abs(vR))*0.5
    duck=0.95 - min(0.35, voice_level*0.75)  # still audible under speech
    # small fade in/out for BGM
    duration=N/(2*vsr)
    fade=min(1.0, t/1.2, max(0.0,(duration-t)/1.8))
    L=vg*vL + bg*duck*fade*bL
    R=vg*vR + bg*duck*fade*bR
    # limiter / soft clip
    L=math.tanh(L*1.15)/math.tanh(1.15)
    R=math.tanh(R*1.15)/math.tanh(1.15)
    mixed.append(int(max(-1,min(1,L))*32767))
    mixed.append(int(max(-1,min(1,R))*32767))
with wave.open(out_path,'wb') as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(vsr)
    w.writeframes(struct.pack('<'+'h'*len(mixed), *mixed))
