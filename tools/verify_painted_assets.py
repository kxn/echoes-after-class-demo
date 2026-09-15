"""Validate exact-pixel layers, animation alphas, and real rendered shadow comparisons."""
import json
from pathlib import Path
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
checks=[]
def check(condition,label,detail=None):
    checks.append(dict(passed=bool(condition),label=label,detail=detail))

source=np.asarray(Image.open(ROOT/'assets/painted/classroom_composite.png').convert('RGB'))
layers=json.loads((ROOT/'assets/painted/layers.json').read_text())
for d in layers['layers']:
    card=np.asarray(Image.open(ROOT/'assets/painted'/d['file']))
    original=source[d['y']:d['y']+d['h'],d['x']:d['x']+d['w']]
    check(np.array_equal(card[:,:,:3],original),d['file']+' RGB copied unchanged from the complete painting')
    check((card[:,:,3]==0).any() and (card[:,:,3]==255).any(),d['file']+' has actual cutout alpha')

animation=json.loads((ROOT/'assets/relit/walk.json').read_text())
atlas=np.asarray(Image.open(ROOT/'assets/relit/walk_albedo.png'))
heights=[]
for f in range(animation['frames']):
    a=atlas[f//8*640:(f//8+1)*640,f%8*384:(f%8+1)*384,3]
    ys,xs=np.where(a>128)
    heights.append(int(ys.max()-ys.min()+1))
    check(abs(ys.max()-610)<=6 and xs.min()>2 and xs.max()<381,'walk frame %d stays within ground tolerance with complete silhouette'%f)
check(max(heights)-min(heights)<28,'natural gait height variation without per-frame resizing',heights)

for actor in range(4):
    idle=np.asarray(Image.open(ROOT/f'assets/relit/actor_{actor}_albedo.png'))
    blink=np.asarray(Image.open(ROOT/f'assets/relit/actor_{actor}_blink.png'))
    check(np.array_equal(idle[:,:,3],blink[:,:,3]),f'blink {actor} preserves silhouette alpha')
    check(np.array_equal(idle[132:],blink[132:]) and np.array_equal(idle[:80],blink[:80]),f'blink {actor} leaves body and head outside eyelid band unchanged')
stop=np.asarray(Image.open(ROOT/'assets/relit/stop_albedo.png'))
for f in range(8):
    a=stop[:640,f*384:(f+1)*384,3]
    ys,xs=np.where(a>128)
    check(xs.min()>2 and xs.max()<381 and ys.min()>2 and ys.max()<637,f'settling frame {f} has no clipped limbs')
check(np.array_equal(stop[:640,7*384:8*384],np.asarray(Image.open(ROOT/'assets/relit/actor_0_albedo.png'))),'settling ends on exact idle image without a final pose pop')

on=np.asarray(Image.open(ROOT/'docs/painted/05-desk-shadow-on.png').convert('RGB'),dtype=float)
off=np.asarray(Image.open(ROOT/'docs/painted/06-desk-shadow-off.png').convert('RGB'),dtype=float)
diff=off-on
regions={'shadow':(445,513,555,528),'desk_apron':(447,542,514,560),'wall':(1010,300,1040,440)} if (ROOT/'assets/painted/layout_v3.json').exists() else {'shadow':(438,480,559,503),'desk_apron':(370,515,525,542),'wall':(620,310,655,410)}
metrics={}
for name,(l,t,r,b) in regions.items():
    crop=diff[t:b,l:r]
    metrics[name]=dict(mean_darkening=float(crop.mean()),mean_abs_difference=float(np.abs(crop).mean()))
check(metrics['shadow']['mean_darkening']>3,'real screenshot: shadow darkens the tabletop',metrics['shadow'])
check(metrics['desk_apron']['mean_abs_difference']<2,'shadow does not paint across desk apron',metrics['desk_apron'])
check(metrics['wall']['mean_abs_difference']<2,'shadow toggle does not relight background',metrics['wall'])
roi=diff[505:533,430:580].mean(2) if (ROOT/'assets/painted/layout_v3.json').exists() else diff[475:510,350:565].mean(2)
check(((roi>2)&(roi<15)).sum()>100,'rendered penumbra includes intermediate darkening values',int(((roi>2)&(roi<15)).sum()))
result=dict(success=all(c['passed'] for c in checks),checks=checks)
(ROOT/'docs/painted/asset-validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(dict(success=result['success'],checks=len(checks),failures=[c for c in checks if not c['passed']],metrics=metrics),ensure_ascii=False))
raise SystemExit(0 if result['success'] else 1)
