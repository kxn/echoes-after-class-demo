from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
source = Image.open(root / 'assets/relit/students_albedo_key.png').convert('RGB')
hero = source.crop((50, 24, 380, 1004))
hero = hero.resize((round(hero.width * 560 / hero.height), 560), Image.Resampling.LANCZOS)
canvas = Image.new('RGB', (384, 640), (255, 0, 255))
canvas.paste(hero, ((384 - hero.width) // 2, 50))
canvas.save(root / 'assets/animation/h3-first.png')
