"""Genera el sprite sheet del gato (pixel art) usado por player.tscn.

Uso:  python3 tools/generate_cat_sprites.py
Requiere Pillow (pip install pillow).

Hoja de 6 columnas x 6 filas, cuadros de 32x32, gato mirando a la derecha:
  fila 0: idle (4 cuadros)   -> frames 0-3
  fila 1: run  (6 cuadros)   -> frames 6-11
  fila 2: jump (2 cuadros)   -> frames 12-13
  fila 3: fall (2 cuadros)   -> frames 18-19
  fila 4: vueltas y acostarse -> 24 frente, 25 lado opuesto, 26 espalda,
                                 27 agachado, 28 echado, 29 echado con la cabeza abajo
  fila 5: dormir y enojo     -> 30-32 durmiendo (respira, "z"),
                                 33 sobresalto, 34 lomo arqueado, 35 bufido
"""

import math
from pathlib import Path

from PIL import Image

FRAME = 32
COLS, ROWS = 6, 6

# Paleta (gato naranja atigrado)
OUTLINE = (43, 29, 20, 255)
FUR = (232, 146, 58, 255)
FUR_DARK = (184, 102, 42, 255)   # patas lejanas y rayas
BELLY = (246, 210, 160, 255)
EYE = (40, 120, 60, 255)
PUPIL = (20, 20, 20, 255)
NOSE = (232, 122, 138, 255)
EAR_IN = (240, 160, 160, 255)
MOUTH = (90, 30, 30, 255)
FANG = (250, 250, 245, 255)
ZZZ = (235, 240, 255, 255)

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "cat"
ICON_BG = "#3b6f8f"


class Canvas:
    def __init__(self):
        self.px = {}

    def set(self, x, y, c):
        if 0 <= x < FRAME and 0 <= y < FRAME:
            self.px[(x, y)] = c

    def ellipse(self, cx, cy, rx, ry, c):
        for y in range(FRAME):
            for x in range(FRAME):
                if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                    self.set(x, y, c)

    def line(self, x0, y0, x1, y1, c, width=2):
        steps = max(abs(x1 - x0), abs(y1 - y0), 1) * 2
        for i in range(steps + 1):
            t = i / steps
            x = round(x0 + (x1 - x0) * t)
            y = round(y0 + (y1 - y0) * t)
            for dx in range(width):
                self.set(x + dx, y, c)

    def poly(self, points, c, width=2):
        for (x0, y0), (x1, y1) in zip(points, points[1:]):
            self.line(x0, y0, x1, y1, c, width)

    def circle(self, cx, cy, r, c):
        self.ellipse(cx, cy, r, r, c)

    def outlined(self):
        out = dict(self.px)
        for (x, y) in self.px:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (x + dx, y + dy)
                if n not in self.px and 0 <= n[0] < FRAME and 0 <= n[1] < FRAME:
                    out[n] = OUTLINE
        return out


def draw_cat(
    body_y=0,
    legs=((0, 0), (0, 0), (0, 0), (0, 0)),
    tail=((7, 20), (4, 17), (3, 13), (4, 10)),
    blink=False,
    head_dy=0,
):
    """legs: (dx, lift) para [trasera lejana, delantera lejana, trasera cercana, delantera cercana]."""
    c = Canvas()
    by = 21 + body_y
    hy = 14 + body_y + head_dy

    # Patas lejanas (más oscuras, detrás del cuerpo)
    for (hip_x, (dx, lift)) in ((10, legs[0]), (21, legs[1])):
        c.line(hip_x, by + 2, hip_x + dx, 29 - lift, FUR_DARK)

    # Cola
    c.poly(list(tail), FUR, width=2)

    # Cuerpo y panza
    c.ellipse(15, by, 9, 4.5, FUR)
    c.ellipse(16, by + 2, 6, 2, BELLY)

    # Cabeza, orejas y hocico
    c.ellipse(23.5, hy, 5.5, 5, FUR)
    for ex in (20, 25):
        c.line(ex, hy - 5, ex + 1, hy - 7, FUR, width=2)
        c.set(ex + 1, hy - 8, FUR)
        c.set(ex + 1, hy - 5, EAR_IN)
    c.ellipse(27, hy + 2, 2.5, 1.8, BELLY)

    # Patas cercanas
    for (hip_x, (dx, lift)) in ((8, legs[2]), (19, legs[3])):
        c.line(hip_x, by + 2, hip_x + dx, 29 - lift, FUR)

    # Rayas del lomo
    for sx in (11, 14, 17):
        c.set(sx, by - 4, FUR_DARK)
        c.set(sx, by - 3, FUR_DARK)
    c.set(22, hy - 4, FUR_DARK)
    c.set(24, hy - 4, FUR_DARK)

    px = c.outlined()

    # Detalles sobre el contorno
    if blink:
        px[(25, hy)] = OUTLINE
        px[(26, hy)] = OUTLINE
    else:
        px[(25, hy - 1)] = EYE
        px[(25, hy)] = EYE
        px[(26, hy - 1)] = PUPIL
        px[(26, hy)] = PUPIL
    px[(29, hy + 1)] = NOSE
    return px


def tail_wave(phase, amp=1.5):
    s = math.sin(phase)
    return (
        (7, 20),
        (4, 17),
        (round(3 + s * amp * 0.5), 13),
        (round(4 + s * amp), 10),
    )


def idle_frames():
    frames = []
    for i in range(4):
        phase = i / 4 * 2 * math.pi
        frames.append(draw_cat(
            body_y=1 if i in (1, 2) else 0,
            head_dy=-1 if i in (1, 2) else 0,
            tail=tail_wave(phase),
            blink=(i == 3),
        ))
    return frames


def run_frames():
    frames = []
    n = 6
    for i in range(n):
        phase = i / n * 2 * math.pi

        def leg(p):
            dx = round(3 * math.sin(p))
            lift = max(0, round(2 * math.cos(p)))
            return (dx, lift)

        frames.append(draw_cat(
            body_y=-1 if i % 3 == 1 else 0,
            legs=(
                leg(phase + math.pi + 0.6),   # trasera lejana
                leg(phase + 0.6),             # delantera lejana
                leg(phase + math.pi),         # trasera cercana
                leg(phase),                   # delantera cercana
            ),
            tail=((7, 19), (4, 17), (2, 16), (0, 15)),
        ))
    return frames


def jump_frames():
    return [
        draw_cat(
            body_y=-2,
            legs=((-4, 2), (4, 4), (-5, 1), (5, 5)),
            tail=((7, 19), (4, 16), (2, 12), (2, 9)),
        ),
        draw_cat(
            body_y=-2,
            legs=((-5, 3), (5, 5), (-6, 2), (6, 6)),
            tail=((7, 19), (4, 15), (3, 11), (4, 8)),
        ),
    ]


def fall_frames():
    return [
        draw_cat(
            body_y=-1,
            legs=((-3, 0), (4, 1), (-2, 1), (5, 0)),
            tail=((7, 19), (4, 14), (5, 10), (7, 7)),
            head_dy=1,
        ),
        draw_cat(
            body_y=-1,
            legs=((-4, 1), (5, 0), (-3, 0), (6, 1)),
            tail=((7, 19), (3, 14), (4, 9), (6, 6)),
            head_dy=1,
        ),
    ]


# --- poses nuevas: vueltas, acostarse, dormir y enojo -----------------------

def overlay(px, canvas):
    """Pinta encima una parte con su propio contorno (p. ej. la cola de espaldas)."""
    px.update(canvas.outlined())
    return px


def mirror(px):
    return {(FRAME - 1 - x, y): c for (x, y), c in px.items()}


def ears(c, left_x, right_x, top_y, inner=True):
    for ex, direction in ((left_x, 1), (right_x, -1)):
        for i in range(4):
            for w in range(4 - i):
                c.set(ex + (w if direction == 1 else -w), top_y + 3 - i + 0, FUR)
        if inner:
            c.set(ex + direction, top_y + 2, EAR_IN)


def front_view():
    c = Canvas()
    c.ellipse(16, 22.5, 6, 5, FUR)
    c.ellipse(16, 23.5, 3, 3.5, BELLY)
    for lx in (13, 18):
        c.line(lx, 24, lx, 29, FUR)
    c.poly([(21, 27), (24, 25), (25, 21)], FUR)
    c.ellipse(16, 14, 6, 5, FUR)
    ears(c, 11, 21, 7)
    c.ellipse(16, 16.5, 2.5, 1.6, BELLY)
    c.set(15, 10, FUR_DARK)
    c.set(17, 10, FUR_DARK)
    px = c.outlined()
    for ex in (13, 19):
        px[(ex, 13)] = EYE
        px[(ex, 14)] = PUPIL
    px[(16, 16)] = NOSE
    return px


def back_view():
    c = Canvas()
    c.ellipse(16, 21.5, 6.5, 5.5, FUR)
    for lx in (12, 19):
        c.line(lx, 25, lx, 29, FUR)
    c.ellipse(16, 13, 5.5, 4.5, FUR)
    ears(c, 11, 21, 7, inner=False)
    for y in (18, 21, 24):
        c.set(11, y, FUR_DARK)
        c.set(21, y, FUR_DARK)
    px = c.outlined()
    tail = Canvas()
    tail.poly([(17, 26), (21, 25), (24, 21), (24, 16), (23, 13)], FUR)
    tail.set(22, 24, FUR_DARK)
    tail.set(24, 18, FUR_DARK)
    return overlay(px, tail)


def draw_lying(head_down=False, eyes_closed=False, breathe=0, zs=()):
    """Gato echado de lado mirando a la derecha. zs: posiciones (x, y) de las "z"."""
    c = Canvas()
    c.poly([(8, 27), (4, 28), (5, 30), (12, 30)], FUR)   # cola enroscada
    c.ellipse(14, 26 - breathe * 0.5, 10, 3.5 + breathe * 0.5, FUR)
    c.ellipse(15, 28, 6, 1.5, BELLY)
    c.line(20, 28, 25, 29, FUR)                              # patas delanteras
    hy = 24 if head_down else 21
    c.ellipse(23.5, hy, 5, 4.5, FUR)
    ex = 20
    for i in range(3):
        c.set(ex + i, hy - 5 + i // 2, FUR)
        c.set(ex + 4 + i, hy - 5 + i // 2, FUR)
    c.set(ex + 1, hy - 6, FUR)
    c.set(ex + 5, hy - 6, FUR)
    c.ellipse(27, hy + 1.5, 2.5, 1.6, BELLY)
    for sx in (10, 13, 16):
        c.set(sx, 23 - breathe, FUR_DARK)
    px = c.outlined()
    if eyes_closed:
        px[(25, hy)] = OUTLINE
        px[(26, hy)] = OUTLINE
    else:
        px[(25, hy - 1)] = EYE
        px[(25, hy)] = EYE
        px[(26, hy - 1)] = PUPIL
        px[(26, hy)] = PUPIL
    px[(29, hy + 1)] = NOSE
    for zx, zy in zs:
        z = Canvas()
        pattern = ["####", "..#.", ".#..", "####"]
        for dy, row in enumerate(pattern):
            for dx, ch in enumerate(row):
                if ch == "#":
                    z.set(zx + dx, zy + dy, ZZZ)
        overlay(px, z)
    return px


def draw_angry(peak_y=10, tail_top=4, hiss=False, hop=0):
    """Lomo arqueado estilo gato de Halloween: patas rectas, pelo y cola erizados."""
    c = Canvas()
    foot = 29 - hop
    # Arco del lomo: círculos a lo largo de una curva
    pts = []
    for i in range(15):
        t = i / 14
        x = 7 + 14 * t
        y = 20 - hop - (20 - hop - peak_y) * math.sin(math.pi * t)
        pts.append((x, y))
        c.circle(x, y + 1, 3.6, FUR)
    # Pelo erizado sobre el arco
    for i, (x, y) in enumerate(pts[1:-1]):
        if i % 2 == 0:
            c.set(round(x), round(y - 4), FUR)
    # Patas rectas y largas
    for lx in (7, 10, 18, 21):
        c.line(lx, 20 - hop, lx, foot, FUR if lx in (7, 18) else FUR_DARK)
    c.ellipse(14, peak_y + 5, 4, 2, BELLY)
    # Cabeza baja y adelantada, orejas hacia atrás
    hx, hy = 25, 20 - hop
    c.ellipse(hx, hy, 5, 4.5, FUR)
    c.line(21, hy - 3, 19, hy - 5, FUR)
    c.line(24, hy - 4, 23, hy - 6, FUR)
    c.ellipse(28.5, hy + 1.5, 2.2, 1.6, BELLY)
    for sx in (12, 15):
        c.set(sx, peak_y - 1, FUR_DARK)
    px = c.outlined()
    # Cola vertical y esponjada
    tail = Canvas()
    tail.line(6, 19 - hop, 5, tail_top, FUR, width=3)
    for y in range(tail_top + 1, 18 - hop, 3):
        tail.set(4, y, FUR)
        tail.set(8, y + 1, FUR)
    tail.set(5, tail_top + 3, FUR_DARK)
    tail.set(6, tail_top + 7, FUR_DARK)
    overlay(px, tail)
    # Ojos muy abiertos
    px[(26, hy - 2)] = EYE
    px[(27, hy - 2)] = EYE
    px[(26, hy - 1)] = EYE
    px[(27, hy - 1)] = PUPIL
    px[(30, hy)] = NOSE
    if hiss:
        for mx in (27, 28, 29):
            px[(mx, hy + 2)] = MOUTH
        px[(28, hy + 3)] = MOUTH
        px[(29, hy + 1)] = FANG
    return px


def settle_frames():
    idle = idle_frames()[0]
    return [
        front_view(),
        mirror(idle),
        back_view(),
        draw_cat(body_y=3, head_dy=1, tail=((7, 23), (4, 25), (2, 27), (0, 28))),
        draw_lying(),
        draw_lying(head_down=True, eyes_closed=True),
    ]


def sleep_angry_frames():
    return [
        draw_lying(head_down=True, eyes_closed=True, breathe=0, zs=[(25, 14)]),
        draw_lying(head_down=True, eyes_closed=True, breathe=1, zs=[(26, 10)]),
        draw_lying(head_down=True, eyes_closed=True, breathe=0, zs=[(27, 6)]),
        draw_angry(peak_y=13, tail_top=8, hop=2),
        draw_angry(peak_y=9, tail_top=3),
        draw_angry(peak_y=9, tail_top=3, hiss=True),
    ]


def write_icon(px):
    """Escribe icon.svg (128x128) con el primer cuadro de idle en pixel art."""
    xs = [x for x, _ in px]
    ys = [y for _, y in px]
    # Centrar el gato dentro del lienzo de 32x32
    ox = (FRAME - (max(xs) - min(xs) + 1)) // 2 - min(xs)
    oy = (FRAME - (max(ys) - min(ys) + 1)) // 2 - min(ys)
    rects = []
    for y in range(FRAME):
        x = 0
        while x < FRAME:
            color = px.get((x, y))
            if color is None:
                x += 1
                continue
            start = x
            while px.get((x, y)) == color:
                x += 1
            hexc = "#%02x%02x%02x" % color[:3]
            rects.append(f'<rect x="{(start + ox) * 4}" y="{(y + oy) * 4}" '
                         f'width="{(x - start) * 4}" height="4" fill="{hexc}"/>')
    svg = (
        '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" '
        'viewBox="0 0 128 128" shape-rendering="crispEdges">\n'
        f'<rect width="128" height="128" rx="16" fill="{ICON_BG}"/>\n'
        + "\n".join(rects) + "\n</svg>\n"
    )
    out = ROOT / "icon.svg"
    out.write_text(svg)
    print(f"Guardado {out}")


def main():
    sheet = Image.new("RGBA", (FRAME * COLS, FRAME * ROWS), (0, 0, 0, 0))
    rows = [idle_frames(), run_frames(), jump_frames(), fall_frames(),
            settle_frames(), sleep_angry_frames()]
    for r, frames in enumerate(rows):
        for col, px in enumerate(frames):
            for (x, y), color in px.items():
                sheet.putpixel((col * FRAME + x, r * FRAME + y), color)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out = OUT_DIR / "cat_sheet.png"
    sheet.save(out)
    print(f"Guardado {out}")
    write_icon(rows[0][0])


if __name__ == "__main__":
    main()
