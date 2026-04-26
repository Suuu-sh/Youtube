#!/usr/bin/env python3
import math, random, struct, sys, wave
if len(sys.argv) != 3:
    print('Usage: generate_eerie_psych_bgm.py <duration_seconds> <output.wav>', file=sys.stderr); sys.exit(1)
duration=float(sys.argv[1]); out=sys.argv[2]
sr=44100; n=int(duration*sr); random.seed(20260425)
# 不気味だけど声を邪魔しない心理学系BGM: 低音ドローン、半音の揺れ、薄いパルス
with wave.open(out,'w') as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(sr)
    frames=bytearray()
    for i in range(n):
        t=i/sr
        fade=min(1.0, t/3.0, max(0.0,(duration-t)/3.2))
        s=0.0
        # low uneasy drone: A + tritone + minor second rub
        for amp,f,ph in [(0.070,55.0,0.0),(0.045,58.27,1.1),(0.038,77.78,2.0),(0.030,116.54,0.4)]:
            wob=0.8*math.sin(2*math.pi*0.045*t+ph)
            s += amp*math.sin(2*math.pi*(f+wob)*t+ph)
        # heartbeat-like soft pulse every ~0.9s
        beat=t%0.92
        pulse=math.exp(-beat*9.0)
        s += 0.055*math.sin(2*math.pi*82.41*t)*pulse
        # sparse glassy motif
        step=int(t/1.84)
        local=t-step*1.84
        motif=[220.0,207.65,233.08,196.0]
        f=motif[step%len(motif)]
        if local<0.85:
            dec=math.exp(-local*4.2)
            s += 0.032*math.sin(2*math.pi*f*t)*dec
            s += 0.018*math.sin(2*math.pi*(f*2.01)*t+0.5)*dec
        # whispery air/noise, slow filtered illusion by amplitude modulation
        noise=(random.random()*2-1)*0.010*(0.4+0.6*math.sin(2*math.pi*0.17*t)**2)
        s += noise
        s *= fade*0.58
        s=math.tanh(s*1.7)*0.70
        pan=0.10*math.sin(2*math.pi*0.07*t)
        l=s*(0.95+pan); r=s*(0.95-pan)
        frames += struct.pack('<hh', int(max(-1,min(1,l))*32767), int(max(-1,min(1,r))*32767))
    w.writeframes(frames)
