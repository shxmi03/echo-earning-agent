#!/usr/bin/env python3
"""Placeholder app icon for Handspan, drawn from the logo brief in brand.md.

    python3 make_app_icon.py      # writes the three 1024x1024 PNGs into the app's AppIcon set

The mark is the brief's "span": one flat arc reaching across a row of keys, white on the
Sky gradient. This is a placeholder so TestFlight builds can upload; the real logo is
still to be made (brand.md, Logo brief). Needs Pillow.
"""
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "app", "Handspan", "Assets.xcassets", "AppIcon.appiconset")
SIZE, SS = 1024, 4          # draw at 4x, then downsample for smooth edges


def gradient(top, bottom):
    im = Image.new("RGB", (1, SIZE * SS))
    px = im.load()
    for y in range(SIZE * SS):
        t = y / (SIZE * SS - 1)
        px[0, y] = tuple(round(a + (b - a) * t) for a, b in zip(top, bottom))
    return im.resize((SIZE * SS, SIZE * SS))


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mark(im, color):
    """A row of keys, and one flat arc spanning the row: the reach of a hand across the keyboard."""
    import math
    s = SIZE * SS
    m = Image.new("L", (s, s), 0)               # mask of everything drawn in `color`
    d = ImageDraw.Draw(m)
    # five white keys, small gaps, rounded bottoms
    left, right, top, bottom = s * 0.20, s * 0.80, s * 0.56, s * 0.80
    n, gap = 5, s * 0.016
    kw = (right - left - gap * (n - 1)) / n
    for i in range(n):
        x0 = left + i * (kw + gap)
        d.rounded_rectangle((x0, top, x0 + kw, bottom), radius=s * 0.025, fill=255)
    # four black keys: cut out of the white keys where the gaps are (C# D# . F# G# pattern)
    bw, bh = kw * 0.56, (bottom - top) * 0.58
    for i in (0, 1, 3):                         # between keys 1-2, 2-3, 4-5
        cx = left + (i + 1) * (kw + gap) - gap / 2
        d.rounded_rectangle((cx - bw / 2, top - 1, cx + bw / 2, top + bh), radius=s * 0.012, fill=0)
    # the span: a flat arc from above the first key to above the last
    w = round(s * 0.046)
    box = (s * 0.21, s * 0.25, s * 0.79, s * 0.71)
    a0, a1 = 200, 340
    d.arc(box, start=a0, end=a1, fill=255, width=w)
    cx, cy = (box[0] + box[2]) / 2, (box[1] + box[3]) / 2
    rx, ry = (box[2] - box[0]) / 2 - w / 2, (box[3] - box[1]) / 2 - w / 2
    for ang in (a0, a1):                       # round caps on the arc
        a = math.radians(ang)
        x, y = cx + rx * math.cos(a), cy + ry * math.sin(a)
        d.ellipse((x - w / 2, y - w / 2, x + w / 2, y + w / 2), fill=255)
    im.paste(Image.new("RGB", (s, s), color), (0, 0), m)
    return im


def save(im, name):
    im.resize((SIZE, SIZE), Image.LANCZOS).convert("RGB").save(os.path.join(OUT, name), optimize=True)


def main():
    # light: Sky gradient (tokens.json light sky-top to tint), white mark; no transparency
    save(mark(gradient(hexrgb("#557f97"), hexrgb("#0b62a4")), (255, 255, 255)), "AppIcon.png")
    # dark: the dark sky, mark in the dark theme's tint
    save(mark(gradient(hexrgb("#10314d"), hexrgb("#04080c")), hexrgb("#6cc0f2")), "AppIcon-Dark.png")
    # tinted: grayscale, iOS applies the user's tint
    save(mark(gradient((40, 40, 40), (8, 8, 8)), (235, 235, 235)), "AppIcon-Tinted.png")
    print("wrote 3 icons to", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
