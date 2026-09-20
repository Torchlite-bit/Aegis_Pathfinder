#!/usr/bin/env python3
"""Generate AEGIS: Pathfinder's texture assets.

Every file under media/ that this script names is generated -- do not hand-edit
them, edit this and re-run:

    pip install Pillow
    python3 Tools/make_assets.py

Output format matches the two textures the addon already shipped and is known
to load on the 1.12 client (see media/dead.tga): 32-bit RLE truecolor TGA,
bottom-left origin, 8 alpha bits, no colour map and no ID field. PIL's own TGA
writer does not pin all of that down, so the encoder here is explicit.

Shapes are written as white masks wherever the colour is applied at runtime
with SetVertexColor -- Theme.lua owns the palette, so a colour change is a Lua
edit and never a re-render. Only genuinely multi-colour art (the navigation
arrow, the progress gradient) bakes colour in.

Geometry is drawn at 4x and downsampled, which is how the rounded corners and
circles get their antialiasing; the 1.12 client does no filtering of its own.
"""

import os
import struct

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MEDIA = os.path.join(ROOT, "media")
FONTS = os.path.join(MEDIA, "fonts")

SS = 4  # supersampling factor

# Concept palette. Only the entries baked into art are used here; the full set
# lives in Theme.lua.
ACCENT_DEEP = (46, 133, 14)
ACCENT_GLOW = (143, 224, 102)

WHITE = (255, 255, 255)


# --------------------------------------------------------------------------
# TGA encoding
# --------------------------------------------------------------------------

def _rle_scanline(pixels):
    """Encode one scanline as TGA RLE packets (max 128 pixels per packet)."""
    out = bytearray()
    i, n = 0, len(pixels)
    while i < n:
        run = 1
        while run < 128 and i + run < n and pixels[i + run] == pixels[i]:
            run += 1
        if run > 1:
            out.append(0x80 | (run - 1))
            b, g, r, a = pixels[i][2], pixels[i][1], pixels[i][0], pixels[i][3]
            out += bytes((b, g, r, a))
            i += run
            continue
        # Raw packet: pixels up to the next run of 2+ identical pixels.
        start = i
        while (i < n and i - start < 128 and
               not (i + 1 < n and pixels[i] == pixels[i + 1])):
            i += 1
        chunk = pixels[start:i]
        out.append(len(chunk) - 1)
        for r, g, b, a in chunk:
            out += bytes((b, g, r, a))
    return out


def write_tga(img, path):
    """Write RGBA image as 32-bit RLE TGA, bottom-left origin."""
    img = img.convert("RGBA")
    w, h = img.size
    for label, value in (("width", w), ("height", h)):
        if value == 0 or value & (value - 1):
            raise ValueError("%s: %s %d is not a power of two" % (path, label, value))
    header = struct.pack(
        "<BBBHHBHHHHBB",
        0,      # ID length
        0,      # no colour map
        10,     # RLE truecolor
        0, 0, 0,  # colour map spec
        0, 0,   # x/y origin
        w, h,
        32,     # bits per pixel
        0x08,   # 8 alpha bits, bottom-left origin
    )
    px = img.load()
    body = bytearray()
    for y in range(h - 1, -1, -1):  # bottom-left origin: last row first
        body += _rle_scanline([px[x, y] for x in range(w)])
    with open(path, "wb") as fh:
        fh.write(header)
        fh.write(body)
    return os.path.getsize(path)


def canvas(size):
    return Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))


def finish(img, size, path):
    img = img.resize((size, size), Image.LANCZOS)
    return write_tga(img, os.path.join(MEDIA, path))


# --------------------------------------------------------------------------
# Panel / widget shapes (white masks, tinted in Lua)
# --------------------------------------------------------------------------

def solid():
    img = Image.new("RGBA", (8, 8), (255, 255, 255, 255))
    return write_tga(img, os.path.join(MEDIA, "solid.tga"))


def rounded(size, radius, width=None, path=None):
    """Rounded rectangle, filled or outlined, as a white mask."""
    img = canvas(size)
    d = ImageDraw.Draw(img)
    box = [0, 0, size * SS - 1, size * SS - 1]
    if width:
        inset = width * SS / 2.0
        d.rounded_rectangle([box[0] + inset, box[1] + inset, box[2] - inset, box[3] - inset],
                            radius=radius * SS, outline=WHITE + (255,), width=width * SS)
    else:
        d.rounded_rectangle(box, radius=radius * SS, fill=WHITE + (255,))
    return finish(img, size, path)


def circle(size, width=None, path=None, pad=1):
    img = canvas(size)
    d = ImageDraw.Draw(img)
    p = pad * SS
    box = [p, p, size * SS - 1 - p, size * SS - 1 - p]
    if width:
        d.ellipse(box, outline=WHITE + (255,), width=width * SS)
    else:
        d.ellipse(box, fill=WHITE + (255,))
    return finish(img, size, path)


def glow(size=64):
    """Radial falloff for the auto-detect pulse and focus rings."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    c = (size - 1) / 2.0
    for y in range(size):
        for x in range(size):
            dist = ((x - c) ** 2 + (y - c) ** 2) ** 0.5 / c
            a = max(0.0, 1.0 - dist)
            px[x, y] = WHITE + (int(255 * a * a),)
    return write_tga(img, os.path.join(MEDIA, "glow.tga"))


def shadow(size=64):
    """Soft drop shadow behind floating panels."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    c = (size - 1) / 2.0
    for y in range(size):
        for x in range(size):
            dist = max(abs(x - c), abs(y - c)) / c
            a = max(0.0, 1.0 - dist) ** 1.6
            px[x, y] = (0, 0, 0, int(210 * a))
    return write_tga(img, os.path.join(MEDIA, "shadow.tga"))


# --------------------------------------------------------------------------
# Baked-colour art
# --------------------------------------------------------------------------

def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def progress_fill(w=64, h=8):
    """accent-deep -> accent-glow, matching the concept's progress gradient."""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for x in range(w):
        col = lerp(ACCENT_DEEP, ACCENT_GLOW, x / float(w - 1))
        for y in range(h):
            px[x, y] = col + (255,)
    return write_tga(img, os.path.join(MEDIA, "progress-fill.tga"))


# --------------------------------------------------------------------------
# Action icons
# --------------------------------------------------------------------------
# One 32x32 white glyph per action code in the guide DSL. They are silhouettes
# rather than line art because they render at roughly 14px in the status bar,
# where strokes thinner than ~2px disappear. Tinted in Lua.

def _icon(draw_fn, name, size=32):
    img = canvas(size)
    d = ImageDraw.Draw(img)
    draw_fn(d, size * SS)
    return finish(img, size, os.path.join("icons", name + ".tga"))


W = WHITE + (255,)


def _scroll(d, s):           # A / T -- quest scroll
    d.rounded_rectangle([s * .22, s * .14, s * .78, s * .86], radius=s * .06, fill=W)
    d.rectangle([s * .30, s * .30, s * .70, s * .36], fill=(0, 0, 0, 0))
    d.rectangle([s * .30, s * .46, s * .70, s * .52], fill=(0, 0, 0, 0))
    d.rectangle([s * .30, s * .62, s * .58, s * .68], fill=(0, 0, 0, 0))


def _swords(d, s):           # C -- complete objectives
    d.line([s * .18, s * .82, s * .82, s * .18], fill=W, width=int(s * .13))
    d.line([s * .18, s * .18, s * .82, s * .82], fill=W, width=int(s * .13))


def _note(d, s):             # N -- note
    d.rounded_rectangle([s * .20, s * .16, s * .80, s * .84], radius=s * .08, fill=W)
    for i, frac in enumerate((.34, .50, .66)):
        right = .68 if i < 2 else .56
        d.rectangle([s * .30, s * frac, s * right, s * (frac + .07)], fill=(0, 0, 0, 0))


def _run(d, s):              # R -- travel on foot
    for off in (-.18, .10):
        d.polygon([(s * (.42 + off), s * .18), (s * (.78 + off), s * .50),
                   (s * (.42 + off), s * .82), (s * (.42 + off), s * .62),
                   (s * (.58 + off), s * .50), (s * (.42 + off), s * .38)], fill=W)


def _house(d, s, dot=False):  # H / h -- hearth
    d.polygon([(s * .50, s * .14), (s * .88, s * .48), (s * .12, s * .48)], fill=W)
    d.rectangle([s * .24, s * .48, s * .76, s * .84], fill=W)
    if dot:
        d.ellipse([s * .42, s * .58, s * .58, s * .74], fill=(0, 0, 0, 0))


def _wing(d, s, outline=False):  # F / f -- flight
    # Gull silhouette: two swept wings meeting at a low centre. Reads as
    # "bird" at icon size where a feather or a detailed wing turns to mush.
    left = [(s * .06, s * .34), (s * .30, s * .30), (s * .50, s * .62),
            (s * .50, s * .74), (s * .26, s * .48)]
    right = [(s * .94, s * .34), (s * .70, s * .30), (s * .50, s * .62),
             (s * .50, s * .74), (s * .74, s * .48)]
    if outline:                  # f -- flight point not yet discovered
        d.polygon(left, outline=W, width=max(1, int(s * .05)))
        d.polygon(right, outline=W, width=max(1, int(s * .05)))
    else:                        # F -- take a known flight path
        d.polygon(left, fill=W)
        d.polygon(right, fill=W)


def _coin(d, s):             # B -- buy. Stacked coins read better at 14px
    for i, top in enumerate((.56, .38, .20)):   # back to front
        d.ellipse([s * .16, s * top, s * .84, s * (top + .24)], fill=W)
        if i < 2:                                # separate the stacked discs
            d.ellipse([s * .16, s * (top + .17), s * .84, s * (top + .28)], fill=(0, 0, 0, 0))


def _boat(d, s):             # b -- boat
    d.polygon([(s * .12, s * .58), (s * .88, s * .58), (s * .72, s * .84), (s * .28, s * .84)], fill=W)
    d.polygon([(s * .46, s * .12), (s * .74, s * .52), (s * .46, s * .52)], fill=W)
    d.rectangle([s * .42, s * .12, s * .50, s * .52], fill=W)


def _skull(d, s, bones=False):
    """K / G -- kill and grind share a glyph, as they do in the concept.

    D (die) adds crossbones so a death step is never mistaken for a kill step.
    """
    if bones:
        for a, b in (((.10, .52), (.90, .94)), ((.90, .52), (.10, .94))):
            d.line([s * a[0], s * a[1], s * b[0], s * b[1]], fill=W, width=int(s * .10))
            for end in (a, b):
                d.ellipse([s * (end[0] - .07), s * (end[1] - .07),
                           s * (end[0] + .07), s * (end[1] + .07)], fill=W)
    d.ellipse([s * .20, s * .10, s * .80, s * .64], fill=W)
    d.rectangle([s * .36, s * .54, s * .64, s * .78], fill=W)
    eye = (0, 0, 0, 0)
    d.ellipse([s * .31, s * .30, s * .45, s * .46], fill=eye)
    d.ellipse([s * .55, s * .30, s * .69, s * .46], fill=eye)
    d.rectangle([s * .46, s * .56, s * .54, s * .74], fill=eye)


def _box(d, s):              # U -- use item
    d.polygon([(s * .50, s * .12), (s * .88, s * .32), (s * .50, s * .52), (s * .12, s * .32)], fill=W)
    d.polygon([(s * .12, s * .34), (s * .50, s * .54), (s * .50, s * .88), (s * .12, s * .68)], fill=W)
    d.polygon([(s * .88, s * .34), (s * .88, s * .68), (s * .50, s * .88), (s * .50, s * .54)], fill=W)


def _book(d, s):             # t -- trainer. Open book, splayed pages
    d.polygon([(s * .08, s * .26), (s * .46, s * .36), (s * .46, s * .84),
               (s * .08, s * .74)], fill=W)
    d.polygon([(s * .92, s * .26), (s * .54, s * .36), (s * .54, s * .84),
               (s * .92, s * .74)], fill=W)
    d.rectangle([s * .46, s * .34, s * .54, s * .86], fill=W)   # spine


def _paw(d, s):              # P -- pet
    d.ellipse([s * .30, s * .44, s * .70, s * .82], fill=W)
    for cx in (.22, .40, .60, .78):
        d.ellipse([s * (cx - .09), s * .18, s * (cx + .09), s * .40], fill=W)


ICONS = {
    "accept": _scroll,
    "turnin": _scroll,
    "complete": _swords,
    "note": _note,
    "run": _run,
    "hearth": lambda d, s: _house(d, s, dot=False),
    "sethearth": lambda d, s: _house(d, s, dot=True),
    "fly": lambda d, s: _wing(d, s, outline=False),
    "getflightpoint": lambda d, s: _wing(d, s, outline=True),
    "buy": _coin,
    "boat": _boat,
    "kill": lambda d, s: _skull(d, s, bones=False),
    "grind": lambda d, s: _skull(d, s, bones=False),
    "use": _box,
    "train": _book,
    "die": lambda d, s: _skull(d, s, bones=True),
    "pet": _paw,
}


# --------------------------------------------------------------------------
# Branding
# --------------------------------------------------------------------------

def _shield(d, s, fill=W):
    d.polygon([(s * .50, s * .06), (s * .90, s * .22), (s * .90, s * .52),
               (s * .50, s * .94), (s * .10, s * .52), (s * .10, s * .22)], fill=fill)


def logo(size=64):
    """Minimap / FuBar icon: shield with the navigation arrow cut out."""
    img = canvas(size)
    d = ImageDraw.Draw(img)
    s = size * SS
    _shield(d, s)
    d.polygon([(s * .50, s * .24), (s * .74, s * .64), (s * .50, s * .55), (s * .26, s * .64)],
              fill=(0, 0, 0, 0))
    return finish(img, size, "logo.tga")


def wordmark(w=256, h=32):
    """PATHFINDER wordmark, pre-rendered in the display face.

    Pre-rendering keeps the concept's letterforms and tracking exact, and keeps
    the header readable even if the bundled TTF fails to load on a client.
    """
    img = Image.new("RGBA", (w * 2, h * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    path = os.path.join(FONTS, "Rajdhani-Bold.ttf")
    if not os.path.exists(path):
        print("  ! %s missing; skipping wordmark" % path)
        return 0
    text = "PATHFINDER"
    tracking = int(h * 2 * 0.18)   # the concept sets letter-spacing .18em
    font = ImageFont.truetype(path, int(h * 2 * 0.86))
    widths = [d.textlength(c, font=font) for c in text]
    total = sum(widths) + tracking * (len(text) - 1)
    x = (w * 2 - total) / 2.0
    for c, cw in zip(text, widths):
        d.text((x, h), c, font=font, fill=W, anchor="lm")
        x += cw + tracking
    img = img.resize((w, h), Image.LANCZOS)
    return write_tga(img, os.path.join(MEDIA, "wordmark.tga"))


# --------------------------------------------------------------------------

def main():
    os.makedirs(os.path.join(MEDIA, "icons"), exist_ok=True)
    total = 0
    made = []

    def record(name, nbytes):
        nonlocal total
        total += nbytes
        made.append((name, nbytes))

    record("solid.tga", solid())
    # 10px corner radius at a 32px slice, matching the concept's --radius:10px.
    record("panel-fill.tga", rounded(32, 10, path="panel-fill.tga"))
    record("panel-border.tga", rounded(32, 10, width=1, path="panel-border.tga"))
    record("pill-fill.tga", rounded(32, 16, path="pill-fill.tga"))
    record("pill-border.tga", rounded(32, 16, width=1, path="pill-border.tga"))
    record("tab-fill.tga", rounded(32, 6, path="tab-fill.tga"))
    record("tab-border.tga", rounded(32, 6, width=1, path="tab-border.tga"))
    record("circle-fill.tga", circle(32, path="circle-fill.tga"))
    record("circle-border.tga", circle(32, width=2, path="circle-border.tga"))
    record("glow.tga", glow())
    record("shadow.tga", shadow())
    record("progress-fill.tga", progress_fill())
    record("logo.tga", logo())
    record("wordmark.tga", wordmark())

    for name, fn in sorted(ICONS.items()):
        record("icons/%s.tga" % name, _icon(fn, name))

    for name, nbytes in made:
        print("  %-28s %6d bytes" % (name, nbytes))
    print("\n%d files, %.1f KiB total" % (len(made), total / 1024.0))


if __name__ == "__main__":
    main()
