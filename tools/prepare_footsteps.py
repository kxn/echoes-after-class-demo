"""Short, softened CC0 concrete foley; onset at the animation's contact event."""
from pathlib import Path
import json,wave
import numpy as np
from scipy.signal import butter,sosfilt
ROOT=Path(__file__).resolve().parents[1]
report=[]
for i in range(3):
    with wave.open(str(ROOT/f'references/audio/concrete{i}.wav'),'rb') as f:
        rate=f.getframerate();data=np.frombuffer(f.readframes(f.getnframes()),dtype='<i2').astype(float)/32768
    data=sosfilt(butter(2,[90,2200],btype='bandpass',fs=rate,output='sos'),data)
    envelope=np.convolve(data**2,np.ones(176)/176,'same')**.5
    hit=np.where(envelope>envelope.max()*.15)[0][0]
    data=data[max(0,hit-88):max(0,hit-88)+int(rate*.24)]
    data*=np.minimum(1,np.arange(len(data))/max(rate*.003,1))
    data*=np.minimum(1,np.arange(len(data))[::-1]/(rate*.028))
    data*=.28/max(abs(data).max(),1e-6)
    with wave.open(str(ROOT/f'assets/audio/cloth_brick_{i}.wav'),'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(rate);f.writeframes(np.int16(data*32767).tobytes())
    report.append(dict(variant=i,seconds=len(data)/rate,source_onset_trim_ms=hit/rate*1000,peak_db=-11.06))
(ROOT/'docs/revision2/footstep-processing.json').write_text(json.dumps(report,indent=2))
print(report)
