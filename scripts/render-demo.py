#!/usr/bin/env python3
"""Renders the DeskArt demo GIF frames.

Draws real macOS-style folder icons on a Desktop and animates them between
layouts produced by the app's actual placement engine — so what the GIF shows
is what the app does, not an illustration of it.
"""
import json
import math
import os
import subprocess
import sys

S = "/private/tmp/claude-501/-Users-firaslatrach-Desktop-finder/c8571278-d676-4e3c-8b61-85599a56af23/scratchpad"
DATA = json.load(open(f"{S}/gif.json"))
OUT = f"{S}/frames"
os.makedirs(OUT, exist_ok=True)

# Output size. 1280x800 keeps a 16:10 Desktop ratio and stays under the size
# ceiling social platforms impose on GIFs once palettised.
W, H = 1280, 800
FPS = 25

# The sequence: settle on the grid, then move through shapes. Each entry is
# (layout key, caption).
SEQUENCE = [
    ("start", "46 icons on your Desktop"),
    ("text", 'Text — "HI"'),
    ("heart", "Heart"),
    ("star", "Star"),
    ("spiral", "Spiral"),
    ("smiley", "Smiley"),
    ("start", "Undo — everything back"),
]

HOLD = 26      # frames held on each arrangement
MOVE = 22      # frames spent travelling between arrangements


def ease_out_cubic(t):
    """Entrances decelerate — motion that arrives gently reads as physical."""
    return 1 - pow(1 - t, 3)


def lerp(a, b, t):
    return a + (b - a) * t


def draw_icon(d, x, y, size, kind, alpha=1.0):
    """A folder glyph: back tab, front face, subtle top highlight."""
    w = size
    h = size * 0.78
    x0, y0 = x - w / 2, y - h / 2

    # Colours: macOS folder blue, dimmed for parked icons so the shape reads
    # as the subject and the leftovers as background.
    if kind == 1:
        top = (122, 190, 240)
        bot = (74, 148, 214)
    else:
        top = (86, 104, 124)
        bot = (62, 76, 92)

    def rgba(c, a=alpha):
        return (c[0], c[1], c[2], int(255 * a))

    # Back tab
    tab_w = w * 0.42
    d.rounded_rectangle(
        [x0, y0 - h * 0.14, x0 + tab_w, y0 + h * 0.3],
        radius=max(2, size * 0.07), fill=rgba(top, alpha * 0.9),
    )
    # Front face, drawn as a short vertical gradient for a little depth
    steps = 8
    for i in range(steps):
        t = i / (steps - 1)
        c = (
            int(lerp(top[0], bot[0], t)),
            int(lerp(top[1], bot[1], t)),
            int(lerp(top[2], bot[2], t)),
        )
        yy0 = y0 + (h * i / steps)
        yy1 = y0 + (h * (i + 1) / steps) + 1
        r = max(2, size * 0.09)
        d.rounded_rectangle([x0, yy0, x0 + w, yy1], radius=r if i in (0, steps - 1) else 0,
                            fill=rgba(c))
    # Top highlight
    d.rounded_rectangle(
        [x0 + w * 0.06, y0 + h * 0.04, x0 + w * 0.94, y0 + h * 0.16],
        radius=max(1, size * 0.05), fill=rgba((255, 255, 255), alpha * 0.16),
    )


def main():
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        print("Pillow required: pip3 install pillow", file=sys.stderr)
        sys.exit(1)

    # Fonts: SF is present on macOS; fall back rather than crash.
    def font(sz, bold=False):
        for p in [
            "/System/Library/Fonts/SFNS.ttf",
            "/System/Library/Fonts/Helvetica.ttc",
        ]:
            if os.path.exists(p):
                try:
                    return ImageFont.truetype(p, sz, index=1 if bold else 0)
                except Exception:
                    try:
                        return ImageFont.truetype(p, sz)
                    except Exception:
                        pass
        return ImageFont.load_default()

    F_CAP = font(30, bold=True)
    F_SUB = font(19)
    F_MENU = font(15, bold=True)

    # Desktop drawing area, inset for the menu bar and a caption strip.
    MENUBAR = 34
    CAPTION = 78
    pad = 54
    area = (pad, MENUBAR + pad, W - pad, H - CAPTION - pad * 0.4)
    aw = area[2] - area[0]
    ah = area[3] - area[1]

    ICON = 26  # icon draw size; the real footprint ratio at this scale

    def positions(key):
        d = DATA[key]
        pts = []
        for (nx, ny), kind in zip(d["points"], d["kinds"]):
            pts.append((area[0] + nx * aw, area[1] + ny * ah, kind))
        return pts

    frame_idx = 0

    def render(pts, caption, sub, wallpaper_t=0.0):
        nonlocal frame_idx
        img = Image.new("RGB", (W, H), (14, 16, 20))
        d = ImageDraw.Draw(img, "RGBA")

        # Wallpaper: a soft radial wash, so the Desktop reads as a Desktop
        # without competing with the icons.
        for i in range(28):
            t = i / 27
            r = int(560 * (1 - t)) + 60
            a = int(16 * (1 - t))
            cx, cy = W * 0.5, H * 0.34
            d.ellipse([cx - r * 1.7, cy - r, cx + r * 1.7, cy + r],
                      fill=(40, 78, 120, a))

        # Menu bar
        d.rectangle([0, 0, W, MENUBAR], fill=(10, 11, 14, 235))
        d.text((22, MENUBAR / 2), "", font=F_MENU, fill=(235, 238, 244), anchor="lm")
        d.text((46, MENUBAR / 2), "DeskArt", font=F_MENU, fill=(235, 238, 244), anchor="lm")
        for i, m in enumerate(["File", "Edit", "View", "Help"]):
            d.text((122 + i * 54, MENUBAR / 2), m, font=F_MENU,
                   fill=(235, 238, 244, 150), anchor="lm")
        d.text((W - 22, MENUBAR / 2), "Wed 1:09 PM", font=F_MENU,
               fill=(235, 238, 244, 170), anchor="rm")

        # Icons, parked first so the shape always sits on top.
        for x, y, kind in sorted(pts, key=lambda p: p[2]):
            draw_icon(d, x, y, ICON, kind)

        # Caption strip
        cy = H - CAPTION + 20
        d.text((W / 2, cy), caption, font=F_CAP, fill=(238, 240, 244), anchor="mt")
        if sub:
            d.text((W / 2, cy + 38), sub, font=F_SUB, fill=(150, 158, 170), anchor="mt")

        img.save(f"{OUT}/f{frame_idx:05d}.png")
        frame_idx += 1

    # Build the sequence
    for i, (key, caption) in enumerate(SEQUENCE):
        cur = positions(key)
        d = DATA[key]
        sub = (f"{d['shapeCount']} in shape · {d['parked']} parked"
               if d["parked"] else f"{d['shapeCount']} icons")
        if key == "start" and i == 0:
            sub = "Every icon, exactly where you left it"
        if key == "start" and i > 0:
            sub = "One click restores the original layout"

        # Hold
        for _ in range(HOLD):
            render(cur, caption, sub)

        # Travel to the next arrangement
        if i + 1 < len(SEQUENCE):
            nk, ncap = SEQUENCE[i + 1]
            nxt = positions(nk)
            nd = DATA[nk]
            nsub = (f"{nd['shapeCount']} in shape · {nd['parked']} parked"
                    if nd["parked"] else f"{nd['shapeCount']} icons")
            if nk == "start":
                nsub = "One click restores the original layout"
            for f in range(MOVE):
                t = ease_out_cubic((f + 1) / MOVE)
                pts = []
                for (x0, y0, k0), (x1, y1, k1) in zip(cur, nxt):
                    # Stagger by index so the move reads as icons rearranging
                    # one after another rather than a single rigid slide.
                    pts.append((lerp(x0, x1, t), lerp(y0, y1, t), k1 if t > 0.5 else k0))
                render(pts, ncap if t > 0.55 else caption,
                       nsub if t > 0.55 else sub)

    print(f"rendered {frame_idx} frames")


if __name__ == "__main__":
    main()
