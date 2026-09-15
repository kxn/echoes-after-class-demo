"""Extract generated eyelid patches and H3 settling frames; retain painted RGB."""
import json,runpy
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw,ImageFilter
from build_sprite_frames import cutout,anchor,normal_map,atlas
ROOT=Path(__file__).resolve().parents[1]
out=ROOT/'docs/detail-v4'
out.mkdir(exist_ok=True)
original=Image.open(ROOT/'assets/relit/students_revision3_key.png').convert('RGB')
closed=Image.open(ROOT/'assets/relit/students_blink_key.png').convert('RGB')
eyes=[(230,125,291,149),(528,184,588,209),(958,121,1018,145),(1285,191,1347,219)]
boxes=[(45,28,380,1002),(455,100,730,997),(815,26,1139,1003),(1227,125,1491,997)]
combined=original.copy()
for box in eyes:
    mask=Image.new('L',original.size)
    ImageDraw.Draw(mask).rounded_rectangle(box,radius=4,fill=255)
    mask=mask.filter(ImageFilter.GaussianBlur(1.0))
    combined.paste(closed,(0,0),mask)
preview=Image.new('RGB',(4*256,2*200),'#4e4945')
for i,box in enumerate(boxes):
    item=cutout(combined.crop(box)); item=item.crop(item.getbbox())
    item=item.resize((round(item.width*560/item.height),560),Image.Resampling.LANCZOS)
    frame=Image.new('RGBA',(384,640));frame.paste(item,((384-item.width)//2,51));frame,_=anchor(frame)
    base=Image.open(ROOT/f'assets/relit/actor_{i}_albedo.png').convert('RGBA')
    original_alpha=base.getchannel('A')
    # Keep the already shipped body byte-for-byte; only the head's eye band changes.
    band=(0,80,384,132)
    base.paste(frame.crop(band),band)
    base.putalpha(original_alpha)
    base.save(ROOT/f'assets/relit/actor_{i}_blink.png')
    for row,im in enumerate([Image.open(ROOT/f'assets/relit/actor_{i}_albedo.png'),base]):
        crop=im.crop((110,45,290,175)).resize((256,185))
        preview.paste(crop,(i*256,row*200),crop)
preview.save(out/'blink-comparison.png')

raw=sorted((ROOT/'assets/animation/stop-v1/raw').glob('*.png'))
frames=[cutout(Image.open(p)) for p in raw[:7]]
frames[0]=Image.open(ROOT/'assets/animation/h3-walk-v2/rgba/frame_013.png').convert('RGBA')
frames.append(Image.open(ROOT/'assets/relit/actor_0_albedo.png').convert('RGBA'))
atlas(frames,ROOT/'assets/relit/stop_albedo.png')
atlas([normal_map(f) for f in frames],ROOT/'assets/relit/stop_normal.png')
response=runpy.run_path(str(ROOT/'tools/extract_painted_layers.py'))['response']
atlas([response(f) for f in frames],ROOT/'assets/painted/stop_response.png')
shadows=[]
for f in frames:
    s=Image.new('RGBA',f.size,'white');s.putalpha(f.getchannel('A').filter(ImageFilter.GaussianBlur(2.6)));shadows.append(s)
atlas(shadows,ROOT/'assets/painted/stop_shadow.png')
(ROOT/'assets/relit/stop.json').write_text(json.dumps({'frames':len(frames),'source':'stop-v1/video.webm','source_frames':[0,1,2,3,4,5,6],'last_frame':'actor_0_albedo.png','duration':0.24,'columns':8},indent=2))
preview=[]
for f in frames:
    bg=Image.new('RGB',f.size,'#4e4945');bg.paste(f,(0,0),f);preview.append(bg)
preview[0].save(out/'stop-loop.gif',save_all=True,append_images=preview[1:]+[preview[-1]]*20,duration=30,loop=0)
print('Four registered blink textures and eight settling frames saved.')
