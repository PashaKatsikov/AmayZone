"""Generates launcher icons from tool/icon/icon.png.

Adaptive icon: 108dp canvas, artwork occupies the central 72dp, the rest of
the background layer is filled by stretching the image edges so the mask never
reveals an empty border. Legacy (pre-26) icons are produced as well.
"""
import os
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), '..')
SRC = Image.open(os.path.join(ROOT, 'tool', 'icon', 'icon.png')).convert('RGBA')
RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')

DENSITIES = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0}


def adaptive_layers(scale):
    full = round(108 * scale)
    inner = round(72 * scale)
    art = SRC.resize((inner, inner), Image.LANCZOS)

    # background: heavily blurred, enlarged copy so the safe-zone border blends in
    bg = SRC.resize((full, full), Image.LANCZOS).filter(ImageFilter.GaussianBlur(full / 14))
    bg.alpha_composite(art, ((full - inner) // 2, (full - inner) // 2))

    fg = Image.new('RGBA', (full, full), (0, 0, 0, 0))
    fg.alpha_composite(art, ((full - inner) // 2, (full - inner) // 2))
    return bg.convert('RGB'), fg


def legacy(scale, round_shape):
    size = round(48 * scale)
    art = SRC.resize((size, size), Image.LANCZOS)
    mask = Image.new('L', (size * 4, size * 4), 0)
    d = ImageDraw.Draw(mask)
    if round_shape:
        d.ellipse((0, 0, size * 4 - 1, size * 4 - 1), fill=255)
    else:
        d.rounded_rectangle((0, 0, size * 4 - 1, size * 4 - 1), radius=size * 4 // 6, fill=255)
    mask = mask.resize((size, size), Image.LANCZOS)
    out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    out.paste(art, (0, 0), mask)
    return out


for name, scale in DENSITIES.items():
    d = os.path.join(RES, f'mipmap-{name}')
    os.makedirs(d, exist_ok=True)
    bg, fg = adaptive_layers(scale)
    bg.save(os.path.join(d, 'ic_launcher_background.png'))
    fg.save(os.path.join(d, 'ic_launcher_foreground.png'))
    legacy(scale, False).save(os.path.join(d, 'ic_launcher.png'))
    legacy(scale, True).save(os.path.join(d, 'ic_launcher_round.png'))

anydpi = os.path.join(RES, 'mipmap-anydpi-v26')
os.makedirs(anydpi, exist_ok=True)
xml = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
'''
for n in ('ic_launcher.xml', 'ic_launcher_round.xml'):
    open(os.path.join(anydpi, n), 'w', encoding='utf-8').write(xml)
print('icons done')
