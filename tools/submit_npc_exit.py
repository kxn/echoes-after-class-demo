"""One accepted H3 first+last-frame job, retained for reproducibility."""
import os
import base64,json,time,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/animation/npc-exit-v1'
OUT.mkdir(exist_ok=True)
BASE=os.environ['H3_BASE_URL'].rstrip('/')
def api(path,body=None):
    req=urllib.request.Request(BASE+path,data=json.dumps(body).encode() if body is not None else None,headers={'Content-Type':'application/json'})
    with urllib.request.urlopen(req,timeout=120) as r:return json.load(r)
frame=base64.b64encode((ROOT/'assets/animation/npc-exit-first.png').read_bytes()).decode()
body=dict(profile='fl2va',width=384,height=640,video_frames=56,seed=19720928,sample_params={'sample_steps':32},init_image=frame,end_image=frame,
prompt='A smooth stable hand-painted 2D game walk cycle in slow motion, facing RIGHT. The boy wears the exact same grey jacket and grey trousers, bare head with short dark hair, holding his small book in one hand. Starting from standing, briefly begin walking and then, perform ONE COMPLETE WALKING CYCLE and finish standing at the identical initial pose. Alternate the legs: rear leg smoothly swings forward, heel lands, weight transfers, then the other leg smoothly advances and heel lands to return to the starting pose. Gentle opposite arm swing. Quiet upright torso, level cap and head, relaxed everyday walking, no military march. IN PLACE on a treadmill: hips stay centered, no horizontal travel, no camera movement or zoom. Continuous flowing movement, no pauses, no twitching, no rapid gestures, no head turning, no fluttering fabric, no changing face or hair. Keep lines and clothing folds stable. Whole body and both shoes always visible. Perfectly uniform magenta background including gaps between limbs, no ground shadow, no scene or objects. Neutral diffuse painted lighting. Exactly one full slow-motion cycle, not several fast steps.')
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
