#!/usr/bin/env python3
import math
import random
import struct
import sys
import wave

if len(sys.argv) != 3:
    print('Usage: generate_psych_bgm.py <duration_seconds> <output.wav>', file=sys.stderr)
    sys.exit(1)

duration = float(sys.argv[1])
out = sys.argv[2]
sr = 44100
n = int(duration * sr)
random.seed(42)

# Dark psychology-style ambient bed: low drone, minor arpeggio pulses, subtle noise.
base_freqs = [55.0, 82.41, 110.0]  # A minor-ish low bed
arp = [220.0, 261.63, 329.63, 392.0, 329.63, 261.63]  # A/C/E/G style pulse

with wave.open(out, 'w') as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(sr)
    frames = bytearray()
    for i in range(n):
        t = i / sr
        # slow fade in/out
        fade = min(1.0, t / 2.5, max(0.0, (duration - t) / 3.0))
        # low drone with slow tremolo
        trem = 0.55 + 0.45 * math.sin(2 * math.pi * 0.08 * t)
        sample = 0.0
        for j, f in enumerate(base_freqs):
            sample += 0.055 * math.sin(2 * math.pi * f * t + j * 0.7) * trem
            sample += 0.022 * math.sin(2 * math.pi * (f * 2.0) * t + j * 1.1)
        # sparse pluck every 0.5s with exponential decay
        step = int(t / 0.48)
        local = t - step * 0.48
        f = arp[step % len(arp)]
        decay = math.exp(-local * 7.5)
        pulse_gate = 1.0 if local < 0.36 else 0.0
        sample += 0.075 * math.sin(2 * math.pi * f * t) * decay * pulse_gate
        sample += 0.035 * math.sin(2 * math.pi * (f * 2.01) * t) * decay * pulse_gate
        # airy high pad
        sample += 0.016 * math.sin(2 * math.pi * 523.25 * t + 0.7 * math.sin(2*math.pi*0.05*t))
        # tiny noise texture
        sample += 0.006 * (random.random() * 2 - 1)
        sample *= fade * 0.55
        # soft clipping
        sample = math.tanh(sample * 1.6) * 0.72
        # slight stereo widening
        left = sample * (0.96 + 0.04 * math.sin(2 * math.pi * 0.13 * t))
        right = sample * (0.96 + 0.04 * math.sin(2 * math.pi * 0.11 * t + 1.4))
        frames += struct.pack('<hh', int(max(-1, min(1, left)) * 32767), int(max(-1, min(1, right)) * 32767))
    w.writeframes(frames)
