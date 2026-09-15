"""Submit once to the documented H3 gateway and retain the accepted job for recovery."""
import os
import base64
import json
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/animation/h3-walk-v1'
OUT.mkdir(exist_ok=False)
BASE = os.environ['H3_BASE_URL'].rstrip('/')
def api(path, body=None):
    request = urllib.request.Request(BASE + path, data=json.dumps(body).encode() if body is not None else None, headers={'Content-Type':'application/json'})
    with urllib.request.urlopen(request, timeout=120) as response:
        return json.load(response)

body = {
    'profile':'fl2va', 'width':384, 'height':640, 'video_frames':56,
    'seed':19720916, 'sample_params':{'sample_steps':28},
    'prompt': 'A clean 2D hand-painted game character walking animation on a perfectly flat solid magenta background. The same teenage Chinese boy from the first image walks IN PLACE facing right at a relaxed steady everyday pace. Natural alternating left and right steps, feet lift and land, gentle opposite arm swing and subtle weight shift. The pelvis stays at the same center of the frame; this is treadmill locomotion for a game sprite, no travel across the screen. Begin walking immediately and keep walking continuously for two full gait cycles, never stop or turn. Locked camera, no camera motion, no zoom. Whole body including shoes always in frame with generous margin. Preserve his face, short dark hair, grey-blue 1970s buttoned jacket and dark trousers. Preserve hand-painted illustration style. Flat neutral diffuse illumination, no sunset, no bright rim light, no colored lighting, no shadows on background. Background stays perfectly uniform saturated magenta, including gaps between legs and arms. No other objects, no text.',
    'init_image':base64.b64encode((ROOT / 'assets/animation/h3-first.png').read_bytes()).decode()
}
(OUT / 'request.json').write_text(json.dumps(body, ensure_ascii=False, indent=2), encoding='utf-8')
job = api('/sdcpp/v1/vid_gen', body)
(OUT / 'job.json').write_text(json.dumps(job, indent=2), encoding='utf-8')
print('ACCEPTED ' + job['id'], flush=True)
start = time.monotonic()
previous = None
while True:
    result = api(job['poll_url'])
    state = result['status']
    if state != previous:
        print(f'{time.monotonic()-start:.1f}s {state}', flush=True)
        previous = state
    if state in ('completed', 'failed', 'cancelled'):
        break
    time.sleep(5)
if state != 'completed':
    (OUT / 'result.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    raise RuntimeError(state)
media = result['result']
(OUT / 'video.webm').write_bytes(base64.b64decode(media.pop('b64_json')))
result['elapsed_seconds'] = round(time.monotonic()-start, 2)
(OUT / 'result.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print(f'SAVED {OUT / "video.webm"}', flush=True)
