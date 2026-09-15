"""H3 v2: fixed canvas transform (no framewise foot/torso snapping), seam inspection."""
import argparse,json
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
from scipy.ndimage import gaussian_filter1d
from build_sprite_frames import cutout,normal_map,atlas
ROOT=Path(__file__).resolve().parents[1]
JOB=ROOT/'assets/animation/h3-walk-v2'
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--start',type=int);parser.add_argument('--end',type=int);parser.add_argument('--contacts',default='');args=parser.parse_args()
    frames=[cutout(Image.open(p)) for p in sorted((JOB/'raw').glob('frame_*.png'))]
    for i,f in enumerate(frames):
        data=np.asarray(f,dtype=float)/255
        spill=np.maximum(np.minimum(data[...,0],data[...,2])-data[...,1],0)*.96
        data[...,0]-=spill;data[...,2]-=spill
        frames[i]=Image.fromarray(np.uint8(np.clip(data,0,1)*255))
    boxes=[f.getbbox() for f in frames]
    scale=560/float(np.median([b[3]-b[1] for b in boxes]))
    ground=float(np.median([b[3]-1 for b in boxes]))
    # All frames share this one transform; no per-frame integer recentering.
    centers=[]
    for f,b in zip(frames,boxes):
        a=np.array(f.getchannel('A'),float)/255
        lo=int(b[1]+(b[3]-b[1])*.28);hi=int(b[1]+(b[3]-b[1])*.51)
        centers.append(float((a[lo:hi]*np.arange(f.width)[None,:]).sum()/a[lo:hi].sum()))
    cx=float(np.median(centers));dx=192-cx*scale;dy=610-ground*scale
    normalized=[]
    for f in frames:
        normalized.append(f.transform((384,640),Image.Transform.AFFINE,(1/scale,0,-dx/scale,0,1/scale,-dy/scale),Image.Resampling.BICUBIC))
    contact=Image.new('RGB',(8*144,7*254),'#514d4a');draw=ImageDraw.Draw(contact)
    for i,f in enumerate(normalized):
        im=f.resize((144,240));x=i%8*144;y=i//8*254;contact.paste(im,(x,y),im);draw.text((x+5,y+238),str(i),fill='white')
    contact.save(ROOT/'docs/revision2/normalized-contact.jpg')
    small=[np.asarray(f.resize((96,160)),float)/255 for f in normalized]
    candidates=[]
    for a in range(23,32):
        for b in range(max(a+24,49),min(a+31,56)):
            pose=float(np.abs(small[a]-small[b]).mean())
            velocity=float(np.abs((small[a+1]-small[a])-(small[b]-small[b-1])).mean())
            candidates.append((pose+velocity*.5,a,b,pose,velocity))
    candidates.sort();print('CANDIDATES',candidates[:8],flush=True)
    if args.start is None:return
    selected=normalized[args.start:args.end]
    out=JOB/'rgba';out.mkdir(exist_ok=True)
    for i,f in enumerate(selected):f.save(out/f'frame_{i:03d}.png')
    atlas(selected,ROOT/'assets/relit/walk_albedo.png')
    atlas([normal_map(f) for f in selected],ROOT/'assets/relit/walk_normal.png')
    contacts=[int(x) for x in args.contacts.split(',') if x]
    info=dict(source='h3-walk-v2/video.webm',rgba_directory='assets/animation/h3-walk-v2/rgba',source_frames=56,start=args.start,end_exclusive=args.end,frames=len(selected),fps=24,columns=8,cell_width=384,cell_height=640,foot_y=610,contact_frames=contacts,stride_world_units=2.3,transform=dict(scale=scale,dx=dx,dy=dy),stabilization='one shared subpixel transform; no framewise anchor snapping',loop_candidates=candidates[:8])
    (ROOT/'assets/relit/walk.json').write_text(json.dumps(info,indent=2))
    preview=[]
    for i,f in enumerate(selected):
        bg=Image.new('RGB',(384,640),'#514d4a');bg.paste(f,(0,0),f)
        if i in contacts:ImageDraw.Draw(bg).ellipse((176,617,208,631),fill='#d3a04d')
        preview.append(bg)
    preview[0].save(ROOT/'docs/revision2/walk-loop.gif',save_all=True,append_images=preview[1:],duration=42,loop=0)
    print(json.dumps(info),flush=True)
if __name__=='__main__':main()
