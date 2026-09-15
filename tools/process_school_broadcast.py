"""Original school announcement, local SAPI voice, outdoor PA treatment."""
from pathlib import Path
import json,wave
import numpy as np
from scipy.signal import butter,sosfilt
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/audio/broadcast'
rate=22050
lines=json.loads((OUT/'lines.json').read_text(encoding='utf-8-sig'))
parts=[np.zeros(int(rate*.7))]; elapsed=.7;cues=[]
for i,text in enumerate(lines):
    with wave.open(str(OUT/f'voice-{i}.wav'),'rb') as w:
        assert w.getframerate()==rate and w.getnchannels()==1
        x=np.frombuffer(w.readframes(w.getnframes()),dtype='<i2').astype(float)/32768
    cues.append(dict(start=round(elapsed,3),end=round(elapsed+len(x)/rate,3),text=text))
    parts += [x,np.zeros(int(rate*.32))];elapsed+=len(x)/rate+.32
parts.append(np.zeros(int(rate*.8)))
dry=np.concatenate(parts)
voice=sosfilt(butter(3,[420,2700],btype='bandpass',fs=rate,output='sos'),dry)
voice=np.tanh(voice*3.5)*.40
t=np.arange(len(voice))/rate
voice=np.interp(np.arange(len(voice))+rate*.00016*np.sin(t*2*np.pi*.6),np.arange(len(voice)),voice)
wet=voice.copy()
for delay,gain in [(.105,.24),(.218,.12),(.365,.055)]:
    n=int(delay*rate);wet[n:]+=voice[:-n]*gain
rng=np.random.default_rng(19720916)
hiss=sosfilt(butter(2,[600,4200],btype='bandpass',fs=rate,output='sos'),rng.normal(0,.005,len(wet)))
wet+=hiss+np.sin(t*2*np.pi*100)*.0018
envelope=np.minimum(np.minimum(t/.18,(t[-1]-t)/.32),1).clip(0,1)
wet*=envelope
wet*=.72/max(abs(wet).max(),1e-6)
with wave.open(str(OUT/'school-outdoor.wav'),'wb') as w:
    w.setparams((1,2,rate,0,'NONE','not compressed'));w.writeframes((wet.clip(-1,1)*32767).astype('<i2').tobytes())
(OUT/'cues.json').write_text(json.dumps({'duration':len(wet)/rate,'cues':cues},ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'seconds':len(wet)/rate,'peak':float(abs(wet).max()),'cues':len(cues)}))
