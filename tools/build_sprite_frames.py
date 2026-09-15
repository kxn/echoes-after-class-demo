"""H3 video -> keyed/stabilized RGBA frames, auxiliary normals and a loop atlas.

Normal maps are a silhouette/fold approximation, not recovered 3D geometry.
The original source video and all extracted frames remain available for review.
"""
import argparse
import json
import subprocess
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import gaussian_filter, distance_transform_edt, binary_fill_holes, label

ROOT = Path(__file__).resolve().parents[1]
SIZE = (384, 640)

def cutout(image):
    rgb = np.asarray(image.convert('RGB'), dtype=np.float32) / 255
    key = np.minimum(rgb[..., 0], rgb[..., 2]) - rgb[..., 1]
    alpha = np.clip((0.32 - key) / 0.21, 0, 1)
    binary = alpha > 0.5
    components, count = label(binary)
    if count:
        areas = np.bincount(components.ravel()); areas[0] = 0
        foreground = components == areas.argmax()
        # Keep small nearby details only when supported by the main silhouette.
        support = distance_transform_edt(~foreground) < 3
        alpha *= support
    spill = np.maximum(0, np.minimum(rgb[..., 0], rgb[..., 2]) - rgb[..., 1] - 0.07)
    rgb[..., 0] -= spill * (1-alpha) * 0.85
    rgb[..., 2] -= spill * (1-alpha) * 0.85
    return Image.fromarray(np.uint8(np.clip(np.dstack((rgb, alpha)), 0, 1)*255))

def normal_map(rgba):
    data = np.asarray(rgba, dtype=np.float32)/255
    mask = data[..., 3] > 0.5
    # Smooth rounded silhouette plus low-amplitude local cloth variation.
    distance = gaussian_filter(distance_transform_edt(mask), 2.3)
    volume = 11.0 * np.sqrt(np.minimum(distance, 32) / 32)
    luma = data[..., :3] @ np.array([.2126,.7152,.0722])
    detail = gaussian_filter(luma, 1.1)-gaussian_filter(luma, 5.5)
    height = volume + detail * 1.6 * mask
    dy, dx = np.gradient(height)
    normal = np.dstack((-dx*1.6, dy*1.6, np.ones_like(dx)))
    normal /= np.maximum(np.linalg.norm(normal, axis=2, keepdims=True), 1e-6)
    return Image.fromarray(np.uint8(np.clip(normal*.5+.5,0,1)*255))

def anchor(rgba):
    a = np.asarray(rgba)[...,3] > 120
    ys,xs = np.where(a)
    if len(xs) < 100:
        raise ValueError('Missing character / black or invalid video frame')
    top,bottom = int(ys.min()),int(ys.max())
    lo = int(top+(bottom-top)*.30); hi = int(top+(bottom-top)*.57)
    weights = distance_transform_edt(a[lo:hi]) ** 2
    xx = np.arange(a.shape[1])[None,:]
    center = float((weights*xx).sum()/max(weights.sum(),1))
    out = Image.new('RGBA', SIZE)
    out.paste(rgba, (round(192-center), 610-bottom))
    return out, {'center_x':center,'bottom_y':bottom,'height':bottom-top+1}

def atlas(frames, path, columns=8):
    sheet = Image.new(frames[0].mode, (SIZE[0]*columns,SIZE[1]*((len(frames)+columns-1)//columns)))
    for i, frame in enumerate(frames):
        sheet.paste(frame, ((i%columns)*SIZE[0], (i//columns)*SIZE[1]))
    sheet.save(path)

def make_idle():
    revised=ROOT/'assets/relit/students_revision3_key.png'
    if not revised.exists(): revised=ROOT/'assets/relit/students_revision2_key.png'
    src = Image.open(revised if revised.exists() else ROOT/'assets/relit/students_albedo_key.png')
    boxes = [(45,28,380,1002),(455,100,730,997),(815,26,1139,1003),(1227,125,1491,997)]
    for i,box in enumerate(boxes):
        item = cutout(src.crop(box))
        bbox = item.getbbox()
        item = item.crop(bbox)
        item = item.resize((round(item.width*560/item.height),560), Image.Resampling.LANCZOS)
        frame = Image.new('RGBA',SIZE)
        frame.paste(item, ((384-item.width)//2, 51))
        frame, _ = anchor(frame)
        frame.save(ROOT/f'assets/relit/actor_{i}_albedo.png')
        normal_map(frame).save(ROOT/f'assets/relit/actor_{i}_normal.png')
    print('Four neutral RGBA actors and auxiliary normals saved.',flush=True)

def make_video(start=None,end=None):
    job = ROOT/'assets/animation/h3-walk-v1'
    raw = job/'raw'; raw.mkdir(exist_ok=True)
    subprocess.run(['ffmpeg','-y','-hide_banner','-loglevel','error','-i',str(job/'video.webm'),'-fps_mode','passthrough',str(raw/'frame_%03d.png')],check=True)
    paths = sorted(raw.glob('frame_*.png'))
    clean = job/'rgba'; clean.mkdir(exist_ok=True)
    frames=[]; measurements=[]
    for i,p in enumerate(paths):
        frame,measure=anchor(cutout(Image.open(p)))
        frame.save(clean/f'frame_{i:03d}.png'); frames.append(frame); measurements.append(measure)
    # Use one scale for the whole video, preserving natural body rise/fall.
    # The generated opening stance is also our idle pose, avoiding a size/identity pop.
    video_scale=560.0/measurements[0]['height']
    frames=[anchor(f.resize((round(f.width*video_scale),round(f.height*video_scale)),Image.Resampling.LANCZOS))[0] for f in frames]
    for i,frame in enumerate(frames):
        frame.save(clean/f'frame_{i:03d}.png')
    frames[0].save(ROOT/'assets/relit/actor_0_albedo.png')
    normal_map(frames[0]).save(ROOT/'assets/relit/actor_0_normal.png')
    contact = Image.new('RGB',(8*144,((len(frames)+7)//8)*254),'#504b4a')
    draw=ImageDraw.Draw(contact)
    for i,f in enumerate(frames):
        thumb=f.resize((144,240))
        x=i%8*144;y=i//8*254
        contact.paste(thumb,(x,y),thumb)
        draw.text((x+6,y+237),str(i),fill='#f5d4a0')
    contact.save(ROOT/'docs/relighting/walk-contact-sheet.jpg')
    measures=[]
    small=[np.asarray(f.resize((96,160)),dtype=np.float32)/255 for f in frames]
    for a in range(5,len(frames)-20):
        for b in range(a+20,min(a+35,len(frames))):
            aa,bb=small[a],small[b]
            score=float(np.abs(aa[50:]-bb[50:]).mean())
            measures.append((score,a,b))
    measures.sort()
    if start is None:
        _,start,end=measures[0]
    selected=frames[start:end]
    atlas(selected,ROOT/'assets/relit/walk_albedo.png')
    atlas([normal_map(f) for f in selected],ROOT/'assets/relit/walk_normal.png')
    manifest={'source':'h3-walk-v1/video.webm','source_frames':len(frames),'start':start,'end_exclusive':end,'frames':len(selected),'fps':24,'columns':8,'cell_width':384,'cell_height':640,'foot_y':610,'constant_video_scale':video_scale,'idle_source_frame':0,'auxiliary_normal_method':'rounded silhouette distance field + restrained cloth detail; approximate','measurements':measurements,'loop_candidates':measures[:10]}
    (ROOT/'assets/relit/walk.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    preview=[]
    for frame in selected:
        bg=Image.new('RGB',SIZE,'#55545c');bg.paste(frame,(0,0),frame);preview.append(bg.resize((288,480)))
    preview[0].save(ROOT/'docs/relighting/walk-loop.gif',save_all=True,append_images=preview[1:],duration=42,loop=0)
    print(json.dumps({k:v for k,v in manifest.items() if k not in ('measurements','loop_candidates')}),flush=True)
    print('Best loop candidates: '+str(measures[:10]),flush=True)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--video',action='store_true');p.add_argument('--start',type=int);p.add_argument('--end',type=int);a=p.parse_args()
    make_idle()
    if a.video:make_video(a.start,a.end)
