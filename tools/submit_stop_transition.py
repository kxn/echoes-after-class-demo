"""One accepted H3 first+last-frame job, retained for reproducibility."""
import os
import base64,json,time,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/animation/stop-v1'
OUT.mkdir(exist_ok=True)
BASE=os.environ['H3_BASE_URL'].rstrip('/')
def api(path,body=None):
    req=urllib.request.Request(BASE+path,data=json.dumps(body).encode() if body is not None else None,headers={'Content-Type':'application/json'})
    with urllib.request.urlopen(req,timeout=120) as r:return json.load(r)
frame=base64.b64encode((ROOT/'assets/animation/stop-first.png').read_bytes()).decode()
body=dict(profile='fl2va',width=384,height=640,video_frames=22,seed=19720927,sample_params={'sample_steps':28},init_image=frame,end_image=base64.b64encode((ROOT/'assets/animation/stop-last.png').read_bytes()).decode(),
prompt='A short continuous hand-painted game sprite transition. The boy finishes walking, gently brings his trailing foot alongside the planted foot, relaxes both arms, then turns his shoulders and head slightly toward the viewer into the exact three-quarter standing pose in the final image. One small quiet settling action, no additional walking steps, no marching, no body jump. Feet remain on the same ground line, hips stay horizontally centered, camera fixed. Preserve olive uniform, military soft cap, red star and face identity. No zoom, no moving background. Pure uniform magenta background. Neutral diffuse painterly lighting. The movement smoothly progresses from first pose to final pose, then stops completely.')
(OUT/'request.json').write_text(json.dumps(body,ensure_ascii=False,indent=2),encoding='utf-8')
job=api('/sdcpp/v1/vid_gen',body)
(OUT/'job.json').write_text(json.dumps(job,indent=2))
print('ACCEPTED '+job['id'],flush=True)
start=time.monotonic(); previous=None
while True:
    result=api(job['poll_url']);state=result['status']
    if state!=previous: print(f'{time.monotonic()-start:.1f}s {state}',flush=True);previous=state
    if state in ('completed','failed','cancelled'):break
    time.sleep(5)
if state=='completed':
    (OUT/'video.webm').write_bytes(base64.b64decode(result['result'].pop('b64_json')))
result['elapsed_seconds']=round(time.monotonic()-start,2)
(OUT/'result.json').write_text(json.dumps(result,indent=2))
if state!='completed':raise RuntimeError(state)
print('SAVED '+str(OUT/'video.webm'),flush=True)
