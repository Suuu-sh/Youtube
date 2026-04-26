#!/usr/bin/env python3
import math, random, struct, sys, wave
if len(sys.argv) != 4:
    print('Usage: generate_mood_bgm.py <duration_seconds> <mood> <output.wav>', file=sys.stderr); sys.exit(1)
duration=float(sys.argv[1]); mood=sys.argv[2]; out=sys.argv[3]
sr=44100; n=int(duration*sr); random.seed(abs(hash(mood)) & 0xffffffff)
# Original local synthetic BGM: no samples, no external assets.
settings={
  'work':  {'root':146.83,'scale':[0,2,4,7,9,12], 'tempo':0.36, 'bright':0.09, 'drone':0.035},
  'calm':  {'root':130.81,'scale':[0,3,5,7,10,12], 'tempo':0.54, 'bright':0.045,'drone':0.055},
  'money': {'root':164.81,'scale':[0,2,4,7,11,12], 'tempo':0.42, 'bright':0.075,'drone':0.045},
  'social':{'root':146.83,'scale':[0,2,5,7,9,12], 'tempo':0.40, 'bright':0.07, 'drone':0.040},
  'focus': {'root':110.00,'scale':[0,3,5,7,10,12], 'tempo':0.50, 'bright':0.055,'drone':0.060},
}
s=settings.get(mood,settings['work'])
def note(semi): return s['root']*(2**(semi/12))
with wave.open(out,'w') as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(sr)
    frames=bytearray()
    for i in range(n):
        t=i/sr
        fade=min(1.0,t/1.8,max(0.0,(duration-t)/2.2))
        sample=0.0
        # warm bed
        for k,f in enumerate([note(0)/2,note(7)/2,note(12)/2]):
            sample += s['drone']*math.sin(2*math.pi*f*t + k*.8)*(0.72+0.28*math.sin(2*math.pi*0.07*t+k))
        # soft pulse/arpeggio
        step=int(t/s['tempo']); local=t-step*s['tempo']
        semi=s['scale'][step%len(s['scale'])]
        f=note(semi)
        decay=math.exp(-local*7.0)
        sample += s['bright']*math.sin(2*math.pi*f*t)*decay
        sample += s['bright']*0.35*math.sin(2*math.pi*(f*2.003)*t)*decay
        # gentle high shimmer and very low noise
        sample += 0.012*math.sin(2*math.pi*880*t + 0.35*math.sin(2*math.pi*0.09*t))
        sample += 0.003*(random.random()*2-1)
        sample *= fade*0.62
        sample=math.tanh(sample*1.45)*0.75
        l=sample*(0.97+0.03*math.sin(2*math.pi*0.13*t))
        r=sample*(0.97+0.03*math.sin(2*math.pi*0.11*t+1.4))
        frames += struct.pack('<hh', int(max(-1,min(1,l))*32767), int(max(-1,min(1,r))*32767))
    w.writeframes(frames)
