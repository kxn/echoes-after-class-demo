import runpy
from pathlib import Path
from PIL import Image,ImageFilter
from build_sprite_frames import atlas
response=runpy.run_path('tools/extract_painted_layers.py')['response']
frames=[Image.open(p).convert('RGBA') for p in sorted(Path('assets/animation/npc-exit-v1/rgba').glob('*.png'))]
atlas([response(f) for f in frames],Path('assets/painted/npc_2_walk_response.png'))
shadows=[]
for f in frames:
 s=Image.new('RGBA',f.size,'white');s.putalpha(f.getchannel('A').filter(ImageFilter.GaussianBlur(2.6)));shadows.append(s)
atlas(shadows,Path('assets/painted/npc_2_walk_shadow.png'))
