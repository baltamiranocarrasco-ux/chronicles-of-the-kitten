"""Genera los sprites de los objetos móviles del nivel (pixel art).

Uso:  python3 tools/generate_objects.py
Requiere Pillow (pip install pillow).

Salida en objects/:
  moving_platform.png  48x12   plataforma de piedra con musgo
  crusher.png          32x160  tronco aplastador colgado de una cuerda
                               (cuerda arriba, tronco de 48 px abajo)
  spike_ball.png       16x16   castaña con púas que rueda
"""

import math
from pathlib import Path

from PIL import Image

OUT_DIR = Path(__file__).resolve().parent.parent / "objects"


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


EDGE = rgb("#2b1d14")
STONE = rgb("#7d8088")
STONE_LIGHT = rgb("#a2a6ad")
STONE_DARK = rgb("#5b5e66")
MOSS = rgb("#5fae4a")
MOSS_LIGHT = rgb("#86cc5a")
BARK = rgb("#6b4529")
BARK_DARK = rgb("#4a2f1c")
BARK_LIGHT = rgb("#8a5c38")
RING = rgb("#c9a26b")
RING_DARK = rgb("#9c7648")
ROPE = rgb("#c7a46a")
ROPE_DARK = rgb("#8f7045")
METAL = rgb("#b8bec7")
METAL_DARK = rgb("#6d737c")
NUT = rgb("#8a4f2a")
NUT_LIGHT = rgb("#b06a3a")
NUT_SPIKE = rgb("#d9b36a")


def moving_platform():
    w, h = 48, 12
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y in range(h):
        for x in range(w):
            if y in (0, h - 1) or x in (0, w - 1):
                c = EDGE
            elif y <= 3:
                c = MOSS_LIGHT if (x * 7 + y) % 5 == 0 else MOSS
            elif y == 4 and x % 6 in (1, 2):
                c = MOSS
            elif (x % 12 == 0) or y == 7 and x % 12 < 6:
                c = STONE_DARK
            elif y == 5:
                c = STONE_LIGHT
            else:
                c = STONE if (x + y * 5) % 9 else STONE_DARK
            img.putpixel((x, y), c)
    return img


def crusher():
    w, h = 32, 160
    log_top = h - 48
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    # Cuerda trenzada
    for y in range(0, log_top):
        for x in (15, 16):
            img.putpixel((x, y), ROPE if (y + x) % 4 < 2 else ROPE_DARK)
        img.putpixel((14, y), EDGE)
        img.putpixel((17, y), EDGE)
    # Tronco vertical con corteza (las últimas 8 filas son púas)
    for y in range(log_top, h - 8):
        for x in range(2, w - 2):
            if x in (2, w - 3) or y == log_top:
                c = EDGE
            elif (x * 3 + (y // 5) * 7) % 11 == 0:
                c = BARK_DARK
            elif x in (4, 5):
                c = BARK_LIGHT
            else:
                c = BARK
            img.putpixel((x, y), c)
    # Abrazadera de metal
    for x in range(2, w - 2):
        for y in (log_top + 6, log_top + 7):
            img.putpixel((x, y), METAL if y == log_top + 6 else METAL_DARK)
    # Púas de metal en la base
    base = h - 8
    for x in range(2, w - 2):
        img.putpixel((x, base), EDGE)
    for i in range(4):
        cx = 5 + i * 7
        for dy in range(7):
            half = max(0, 3 - dy // 2)
            for dx in range(-half, half + 1):
                img.putpixel((cx + dx, base + 1 + dy), METAL if dx <= 0 else METAL_DARK)
    return img


def spike_ball():
    s = 16
    c = 7.5
    px = {}
    # Cuerpo redondo
    for y in range(s):
        for x in range(s):
            d = math.hypot(x - c, y - c)
            if d <= 4.6:
                px[(x, y)] = NUT_LIGHT if (x - c) + (y - c) < -2 else NUT
    # 8 púas de 2 px hacia afuera
    for i in range(8):
        a = i * math.pi / 4
        for r in (5.2, 6.2):
            x, y = round(c + math.cos(a) * r - 0.01), round(c + math.sin(a) * r - 0.01)
            px[(x, y)] = NUT_SPIKE
    # Contorno automático
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    for (x, y) in list(px):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if n not in px and 0 <= n[0] < s and 0 <= n[1] < s:
                img.putpixel(n, EDGE)
    for (x, y), col in px.items():
        img.putpixel((x, y), col)
    # Ojos enojados
    for x, y in ((6, 8), (9, 8), (5, 7), (10, 7)):
        img.putpixel((x, y), EDGE)
    return img


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, fn in (("moving_platform", moving_platform), ("crusher", crusher),
                     ("spike_ball", spike_ball)):
        fn().save(OUT_DIR / f"{name}.png")
        print(f"Guardado {OUT_DIR / name}.png")


if __name__ == "__main__":
    main()
