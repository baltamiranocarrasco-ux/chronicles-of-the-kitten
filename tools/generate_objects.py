"""Genera los sprites de los objetos móviles del nivel (pixel art cyberpunk).

Uso:  python3 tools/generate_objects.py
Requiere Pillow (pip install pillow).

Salida en objects/ (mismos tamaños que usan las escenas y colisiones):
  moving_platform.png  48x12   plataforma antigravedad con propulsores cian
  crusher.png          32x160  prensa hidráulica: vástago de cromo arriba y
                               cabezal de acero de 48 px abajo (las últimas
                               8 filas son los dientes que hacen daño)
  spike_ball.png       16x16   mina de seguridad con púas y LED rojo (rueda;
                               también la usa la lluvia de objects/chestnut_rain.gd)
"""

import math
from pathlib import Path

from PIL import Image

OUT_DIR = Path(__file__).resolve().parent.parent / "objects"


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


EDGE = rgb("#0a0812")
STEEL = rgb("#4a5068")
STEEL_HI = rgb("#8a92b4")
STEEL_DK = rgb("#2c3044")
CHROME = rgb("#c4ccde")
CHROME_DK = rgb("#7a8298")
HAZARD = rgb("#f0c030")
HAZARD_DK = rgb("#1a1624")
THRUST = rgb("#6af0ff")
THRUST_DK = rgb("#2a8aa8")
LED = rgb("#ff2a3a")
LED_DK = rgb("#7a1020")


def moving_platform():
    w, h = 48, 12
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y in range(h - 3):
        for x in range(w):
            if y in (0, h - 4) or x in (0, w - 1):
                c = EDGE
            elif y == 1:
                c = STEEL_HI
            elif y == h - 5:
                c = STEEL_DK
            elif y == 3 and x % 8 in (2, 3, 4, 5):
                c = HAZARD if (x // 2) % 2 == 0 else HAZARD_DK  # franja de peligro
            else:
                c = STEEL if x % 12 else STEEL_DK
            img.putpixel((x, y), c)
    # Propulsores antigravedad debajo, con resplandor cian
    for nx in (6, 22, 38):
        for x in range(nx, nx + 5):
            img.putpixel((x, h - 3), EDGE)
        for x in range(nx + 1, nx + 4):
            img.putpixel((x, h - 2), THRUST)
        img.putpixel((nx + 2, h - 1), THRUST_DK)
    return img


def crusher():
    w, h = 32, 160
    head_top = h - 48
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    # Vástago hidráulico de cromo
    for y in range(0, head_top):
        for x in range(13, 19):
            if x in (13, 18):
                c = EDGE
            elif x == 14:
                c = CHROME
            elif x == 17:
                c = CHROME_DK
            else:
                c = CHROME if (y // 3) % 5 else CHROME_DK
            img.putpixel((x, y), c)
    # Cabezal de acero con franjas de peligro y remaches
    for y in range(head_top, h - 8):
        for x in range(2, w - 2):
            if x in (2, w - 3) or y == head_top:
                c = EDGE
            elif y in (head_top + 1, head_top + 2):
                c = STEEL_HI
            elif head_top + 26 <= y < head_top + 32:
                c = HAZARD if ((x + y) // 3) % 2 == 0 else HAZARD_DK
            elif x in (3, 4):
                c = STEEL_HI
            elif x in (w - 5, w - 4):
                c = STEEL_DK
            else:
                c = STEEL
            if (x, y - head_top) in ((6, 6), (25, 6), (6, 20), (25, 20)):
                c = CHROME
            img.putpixel((x, y), c)
    # Dientes de acero en la base (zona de daño)
    base = h - 8
    for x in range(2, w - 2):
        img.putpixel((x, base), EDGE)
    for i in range(4):
        cx = 5 + i * 7
        for dy in range(7):
            half = max(0, 3 - dy // 2)
            for dx in range(-half, half + 1):
                img.putpixel((cx + dx, base + 1 + dy), CHROME if dx <= 0 else CHROME_DK)
    return img


def spike_ball():
    s = 16
    c = 7.5
    px = {}
    for y in range(s):
        for x in range(s):
            d = math.hypot(x - c, y - c)
            if d <= 4.6:
                px[(x, y)] = STEEL_HI if (x - c) + (y - c) < -2 else STEEL
    for i in range(8):
        a = i * math.pi / 4
        for r in (5.2, 6.2):
            x, y = round(c + math.cos(a) * r - 0.01), round(c + math.sin(a) * r - 0.01)
            px[(x, y)] = CHROME
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    for (x, y) in list(px):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if n not in px and 0 <= n[0] < s and 0 <= n[1] < s:
                img.putpixel(n, EDGE)
    for (x, y), col in px.items():
        img.putpixel((x, y), col)
    # Ojo LED rojo en el centro
    for x, y in ((7, 7), (8, 7), (7, 8), (8, 8)):
        img.putpixel((x, y), LED)
    img.putpixel((7, 7), rgb("#ff9aa0"))
    for x, y in ((6, 7), (9, 8), (7, 9), (8, 6)):
        img.putpixel((x, y), LED_DK)
    return img


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, fn in (("moving_platform", moving_platform), ("crusher", crusher),
                     ("spike_ball", spike_ball)):
        fn().save(OUT_DIR / f"{name}.png")
        print(f"Guardado {OUT_DIR / name}.png")


if __name__ == "__main__":
    main()
