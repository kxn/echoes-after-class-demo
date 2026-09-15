"""Copy occlusion cards directly from the ONE finished painting; no relighting.

Contours are in the 2048x683 review coordinate system. Each card retains the
original RGB, geometry and placement. The complete source stays behind them,
so fixed furniture needs no independently generated clean plate.
"""
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/painted'
src=Image.open(OUT/'classroom_composite.png').convert('RGB')
scale=src.width/2048
layers=[]

def rect(x0,y0,x1,y1): return [(x0,y0),(x1,y0),(x1,y1),(x0,y1)]

def save_card(name,row,polygons,top,clutter):
    mask=Image.new('L',src.size)
    draw=ImageDraw.Draw(mask)
    for p in polygons:
        draw.polygon([(round(x*scale),round(y*scale)) for x,y in p],fill=255)
    draw.polygon([(round(x*scale),round(y*scale)) for x,y in top],fill=0)
    for p in clutter:
        draw.polygon([(round(x*scale),round(y*scale)) for x,y in p],fill=255)
    bounds=mask.getbbox()
    if not bounds: raise ValueError(name)
    image=src.convert('RGBA');image.putalpha(mask)
    image.crop(bounds).save(OUT/f'{name}.png')
    x,y,r,b=bounds
    layers.append(dict(file=f'{name}.png',row=row,x=x,y=y,w=r-x,h=b-y,polygons_review_coordinates=polygons,top_review_coordinates=top))

layout_spec=OUT/'layout_v3.json'
if layout_spec.exists():
    for item in json.loads(layout_spec.read_text())['desks']:
        save_card(item['name'],item['row'],item['polygons'],item['top'],item['clutter'])
else:
    # Table surface/front panel, visible side, narrow legs and chair back.
    back=[(267,482,398,373,443),(518,701,398,588,657),(759,929,398,808,879),(978,1149,398,1049,1120),(1212,1387,399,1239,1308),(1438,1615,398,1464,1537),(1658,1849,399,1676,1744)]
    for i,(l,r,t,cl,cr) in enumerate(back):
        p=[[(l,t+10),(l+28,t),(r-7,t),(r,t+3),(r,t+13),(r-33,t+24),(l,t+22)],
           rect(l+7,t+20,r-36,t+74),
           [(r-35,t+15),(r-7,t+7),(r-8,t+140),(r-21,t+150),(r-22,t+64),(r-35,t+75)],
           rect(l+8,t+67,l+20,t+162),rect(r-50,t+66,r-37,t+153),
           rect(cl,382,cr,402),rect(cl,397,cl+8,417),rect(cr-8,397,cr,417)]
        if i==0:p.append([(292,400),(327,397),(360,403),(359,460),(348,487),(337,485),(345,408)])
        if i==2:p.append(rect(846,391,902,403))
        if i==4:p.append(rect(1218,382,1255,403))
        top=[(l+29,t+1),(r-8,t+1),(r-33,t+18),(l+2,t+18)]
        clutter=p[7:]
        save_card(f'back_desk_{i}',0,p,top,clutter)

    front=[(111,378,481,268,359),(402,655,483,529,616),(679,902,483,754,857),(947,1168,484,997,1113),(1232,1464,484,1284,1388),(1494,1719,484,1519,1616),(1749,1999,484,1767,1868)]
    for i,(l,r,t,cl,cr) in enumerate(front):
        p=[[(l,t+28),(l+39,t+1),(r-2,t),(r,t+13),(r-27,t+39),(l,t+41)],
           rect(l+9,t+40,r-30,t+88),
           [(r-30,t+33),(r-4,t+15),(r-5,683),(r-19,683),(r-20,t+72),(r-30,t+90)],
           rect(l+10,t+83,l+23,683),rect(r-48,t+82,r-33,683),
           rect(cl,451,cr,478),rect(cl,476,cl+10,t+9),rect(cr-10,474,cr,t+3)]
        # Stool/near chair: seat and legs, keeping floor visible through the frame.
        sl=l+47; sr=r-49
        p += [rect(sl,579,sr,594),rect(sl+4,591,sl+17,683),rect(sr-17,591,sr-4,683),rect(sl+13,653,sr-12,665)]
        if i==0:
            p += [[(146,488),(172,478),(205,474),(246,479),(275,488),(260,509),(257,565),(267,576),(255,589),(242,581),(238,511),(159,503)]]
        if i in [1,4]:
            bl=l+65;br=r-71
            p += [[(bl,554),(bl+8,543),(br-6,545),(br,552),(br+5,603),(br-8,637),(bl+1,635),(bl-7,622)],rect(bl+3,633,bl+14,683),rect(br-11,633,br,683)]
        if i in [1,3,4,5]:
            p.append(rect(l+124 if i==1 else l+82,t-10,r-36,t+8))
        top=[(l+40,t+2),(r-4,t+2),(r-29,t+35),(l+2,t+35)]
        if i==5:
            # This desk slopes right in the painting, unlike the left-hand desks.
            top=[(1494,486),(1678,486),(1728,508),(1529,508)]
            p[0]=[(1494,486),(1678,486),(1728,508),(1728,521),(1529,523),(1494,498)]
            p.append([(1494,498),(1529,523),(1529,570),(1503,554)])
        clutter=p[11:]
        save_card(f'front_desk_{i}',1,p,top,clutter)


(OUT/'layers.json').write_text(json.dumps(dict(width=src.width,height=src.height,layers=layers),indent=2),encoding='utf-8')
print(f'{len(layers)} original-pixel occlusion cards saved.')

def response(im):
    rgba=np.asarray(im.convert('RGBA'),dtype=np.float32)/255
    a=rgba[...,3]
    yy,xx=np.where(a>.5)
    y=(np.arange(im.height)[:,None]-yy.min())/max(yy.max()-yy.min(),1)
    # Art-selectable body regions; strong head/shoulders, moderate sleeves, restrained trousers.
    allow=np.where(y<.27,.95,np.where(y<.40,1.0,np.where(y<.67,.58,.06)))
    rgb=rgba[...,:3]
    skin=(rgb[...,0]>rgb[...,1]*1.12)&(rgb[...,1]>rgb[...,2]*1.07)&(rgb[...,0]>.3)
    skin &= (y<.29)|((y>.46)&(y<.71))
    return Image.fromarray(np.uint8(np.dstack((allow*a,skin*a,a))*255),'RGB')

for i in range(4):
    frame=Image.open(ROOT/f'assets/relit/actor_{i}_albedo.png').convert('RGBA')
    response(frame).save(OUT/f'actor_{i}_response.png')
    shadow=Image.new('RGBA',frame.size,'white');shadow.putalpha(frame.getchannel('A').filter(ImageFilter.GaussianBlur(2.6)))
    shadow.save(OUT/f'actor_{i}_shadow.png')
info=json.loads((ROOT/'assets/relit/walk.json').read_text())
walk_source=Image.open(ROOT/'assets/relit/walk_albedo.png').convert('RGBA')
sheet=Image.new('RGB',walk_source.size)
shadow_sheet=Image.new('RGBA',walk_source.size)
for cell in range(info['frames']):
    x=cell%8*384;y=cell//8*640
    frame=walk_source.crop((x,y,x+384,y+640))
    sheet.paste(response(frame),(cell%8*384,cell//8*640))
    shadow=Image.new('RGBA',frame.size,'white');shadow.putalpha(frame.getchannel('A').filter(ImageFilter.GaussianBlur(2.6)))
    shadow_sheet.paste(shadow,(cell%8*384,cell//8*640))
sheet.save(OUT/'walk_response.png')
shadow_sheet.save(OUT/'walk_shadow.png')
print(f"Four idle and {info['frames']} walking response masks saved.")
