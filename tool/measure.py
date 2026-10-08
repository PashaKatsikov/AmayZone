"""Helper used once to find sprite bounds and reel window geometry inside the art."""
from PIL import Image
import numpy as np

A = 'assets/images/'


def components(path, thr=40):
    im = Image.open(path).convert('RGBA')
    a = np.array(im)[:, :, 3] > thr
    cols = a.any(axis=0)
    spans, start = [], None
    for x, v in enumerate(cols):
        if v and start is None:
            start = x
        if not v and start is not None:
            spans.append((start, x))
            start = None
    if start is not None:
        spans.append((start, len(cols)))
    out = []
    for s, e in spans:
        rows = np.where(a[:, s:e].any(axis=1))[0]
        out.append((s, int(rows[0]), e, int(rows[-1]) + 1))
    return im.size, out


print('buttons', components(A + 'ui/buttons_game_asset.webp'))
print('bet2', components(A + 'ui/button_bet_asset2.webp'))
print('bet', components(A + 'ui/button_bet_asset.webp'))
print('start', components(A + 'ui/button_start_asset.webp'))
print('name', components(A + 'branding/game_name.webp'))
print('frame', components(A + 'frame/slot_frame_asset.webp'))

# frame: find bright orange grid lines along a horizontal scan through a cell middle row
fr = np.array(Image.open(A + 'frame/slot_frame_asset.webp').convert('RGB')).astype(int)
h, w, _ = fr.shape
for y in (int(h * 0.30), int(h * 0.45)):
    row = fr[y]
    lum = row[:, 0] - row[:, 2]  # orange-ness
    xs = [x for x in range(w) if lum[x] > 110]
    groups, cur = [], []
    for x in xs:
        if cur and x - cur[-1] > 4:
            groups.append((cur[0], cur[-1]))
            cur = []
        cur.append(x)
    if cur:
        groups.append((cur[0], cur[-1]))
    print('row', y, groups)
for x in (int(w * 0.25), int(w * 0.5)):
    col = fr[:, x]
    lum = col[:, 0] - col[:, 2]
    ys = [y for y in range(h) if lum[y] > 110]
    groups, cur = [], []
    for y in ys:
        if cur and y - cur[-1] > 4:
            groups.append((cur[0], cur[-1]))
            cur = []
        cur.append(y)
    if cur:
        groups.append((cur[0], cur[-1]))
    print('col', x, groups)
