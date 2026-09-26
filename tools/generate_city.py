"""Genera el fondo parallax de la megaciudad cyberpunk y el tileset del suelo.

Uso:  python3 tools/generate_city.py
Requiere Pillow (pip install pillow).

Salida en assets/city/ (capas de 384x216 que se repiten en horizontal; el
suelo empieza en la fila 152 de la vista):
  bg_0_sky.png        cielo nocturno, luna/estación orbital y estrellas  (0 %)
  bg_1_far.png        siluetas de rascacielos con ventanas de 1 px       (15 %)
  bg_2_mid.png        edificios industriales, tuberías, pasarelas, neón  (40 %)
  bg_3_near.png       cables de alta tensión y carcasas de ventiladores  (70 %)
  tiles.png           atlas 4x4 de 16x16:
                        fila 0: tejado de chapa (izq, centro, der, centro con charco)
                        fila 1: muro del edificio (izq, centro, der)
                        fila 2: viga de acero, plataforma de un sentido (izq, centro, der)
                        fila 3: púas electrificadas para los fosos (solo la primera)

Las ventanas de bg_1_far usan dos colores clave exactos (WINDOW_YELLOW y
WINDOW_CYAN) que effects/city_lights.gd busca para hacerlas parpadear, y las
aspas de los ventiladores, los drones y el tráfico se dibujan por código
(effects/city_*.gd) para que respondan a las habilidades de tiempo.
"""

import math
import random
from pathlib import Path

from PIL import Image

W, H = 384, 216
HORIZON = 152
TILE = 16
OUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "city"


def rgb(h, a=255):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


SKY = [rgb("#120a28"), rgb("#22103c"), rgb("#351650"), rgb("#521c5a"), rgb("#6e2358")]
STAR = rgb("#d8d4f0")
STAR_DIM = rgb("#8a86b8")
SATELLITE = rgb("#9fdcff")
MOON = rgb("#4f8c96")
MOON_DK = rgb("#3a6a76")
MOON_HI = rgb("#78b0b4")
RING = rgb("#6a9aa4")

FAR_BACK = rgb("#2c2450")
FAR_FRONT = rgb("#1a1638")
FAR_EDGE = rgb("#3a3064")
WINDOW_YELLOW = rgb("#f0c85a")
WINDOW_CYAN = rgb("#5ad8f0")

MID = rgb("#1c1830")
MID_HI = rgb("#342c52")
MID_DK = rgb("#120f22")
PIPE = rgb("#463c64")
PIPE_HI = rgb("#6a5c8c")
PIPE_DK = rgb("#2a2440")
RAIL = rgb("#5a5078")
NEONS = [(rgb("#ff3cc8"), rgb("#7a1c62")), (rgb("#96ff3c"), rgb("#3e6a18")), (rgb("#3ce6ff"), rgb("#1a5e6e"))]

CABLE = rgb("#0e0b1a")
VENT = rgb("#2a2440")
VENT_HI = rgb("#4a4068")
VENT_DK = rgb("#161226")

ROOF = rgb("#4a4e68")
ROOF_HI = rgb("#8a92b4")
ROOF_DK = rgb("#30324a")
WALL = rgb("#1e1c30")
WALL_HI = rgb("#2e2a46")
WALL_DK = rgb("#141222")
EDGE = rgb("#0a0812")
BEAM = rgb("#6c7490")
BEAM_HI = rgb("#a8b0cc")
BEAM_DK = rgb("#3c4058")
PUDDLE = rgb("#161a34")
SPIKE = rgb("#5a6078")
SPIKE_TIP = rgb("#6af0ff")


class Layer:
    """Imagen que envuelve en X para que la capa se repita sin costuras."""

    def __init__(self, w=W, h=H):
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w, h), (0, 0, 0, 0))

    def set(self, x, y, c):
        x, y = int(round(x)), int(round(y))
        if 0 <= y < self.h:
            self.img.putpixel((x % self.w, y), c)

    def get(self, x, y):
        return self.img.getpixel((int(x) % self.w, int(y)))

    def rect(self, x0, y0, w, h, c):
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                self.set(x, y, c)

    def circle(self, cx, cy, r, c):
        for y in range(int(cy - r), int(cy + r) + 1):
            for x in range(int(cx - r), int(cx + r) + 1):
                if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
                    self.set(x, y, c)

    def line(self, x0, y0, x1, y1, c):
        steps = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(steps + 1):
            t = i / steps
            self.set(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, c)

    def save(self, name):
        self.img.save(OUT_DIR / name)
        print(f"Guardado {OUT_DIR / name}")


# --- capa 1: cielo -----------------------------------------------------------

def sky():
    layer = Layer()
    stops = [0, 50, 95, 130, 160]
    for y in range(H):
        idx = sum(1 for s in stops if y >= s) - 1
        for x in range(W):
            color = SKY[idx]
            # Tramado de 2 filas en cada cambio de color
            nxt = idx + 1
            if nxt < len(stops) and stops[nxt] - y <= 2 and (x + y) % 2 == 0:
                color = SKY[nxt]
            layer.set(x, y, color)
    rnd = random.Random(21)
    for _ in range(90):
        x, y = rnd.randrange(W), rnd.randrange(0, 110)
        layer.set(x, y, STAR if rnd.random() < 0.35 else STAR_DIM)
        if rnd.random() < 0.12:  # racimos
            layer.set(x + 1, y, STAR_DIM)
            layer.set(x, y + 1, STAR_DIM)
    for _ in range(4):
        layer.set(rnd.randrange(W), rnd.randrange(10, 80), SATELLITE)
    # Luna gigante con anillo de estación orbital
    cx, cy, r = 312, 42, 24
    layer.circle(cx, cy, r, MOON)
    layer.circle(cx + 5, cy + 4, r - 4, MOON_DK)
    layer.circle(cx - 3, cy - 3, r - 6, MOON)
    for kx, ky, kr in ((cx - 8, cy - 6, 4), (cx + 6, cy - 12, 3), (cx - 2, cy + 9, 5), (cx + 11, cy + 3, 2)):
        layer.circle(kx, ky, kr, MOON_DK)
        layer.circle(kx - 1, ky - 1, max(1, kr - 2), MOON_HI)
    for i in range(160):
        a = i / 160 * math.tau
        x = cx + math.cos(a) * 36
        y = cy + math.sin(a) * 7 - 2
        # El anillo pasa por delante abajo y por detrás arriba
        if math.sin(a) > 0 or (x - cx) ** 2 + (y - cy) ** 2 > r * r:
            layer.set(x, y, RING)
    return layer


# --- capa 2: rascacielos lejanos ------------------------------------------------

def far_city():
    layer = Layer()
    rnd = random.Random(33)
    for color, lo, hi, seed_w in ((FAR_BACK, 50, 110, (14, 30)), (FAR_FRONT, 70, 135, (16, 34))):
        x = 0
        while x < W:
            w = rnd.randint(*seed_w)
            top = H - rnd.randint(lo, hi)
            layer.rect(x, top, w, H - top, color)
            layer.rect(x, top, 1, H - top, FAR_EDGE if color == FAR_FRONT else color)
            # Antenas
            if rnd.random() < 0.4:
                ax = x + rnd.randint(2, w - 3)
                layer.rect(ax, top - rnd.randint(4, 12), 1, 12, color)
                layer.set(ax, top - 12, WINDOW_CYAN if rnd.random() < 0.5 else WINDOW_YELLOW)
            # Ventanas: rejilla dispersa de 1 px
            if color == FAR_FRONT:
                for wy in range(top + 3, HORIZON, 4):
                    for wx in range(x + 2, x + w - 1, 3):
                        if rnd.random() < 0.13:
                            layer.set(wx, wy, WINDOW_YELLOW if rnd.random() < 0.7 else WINDOW_CYAN)
            x += w + rnd.randint(0, 3)
    return layer


# --- capa 3: edificios medios, tuberías, pasarelas y neón ------------------------

def mid_city():
    layer = Layer()
    rnd = random.Random(47)
    tops = []
    x = 0
    while x < W:
        w = rnd.randint(26, 48)
        top = rnd.randint(70, 118)
        layer.rect(x, top, w, H - top, MID)
        layer.rect(x, top, w, 1, MID_HI)
        layer.rect(x, top, 1, H - top, MID_HI)
        layer.rect(x + w - 1, top, 1, H - top, MID_DK)
        # Paneles y ductos verticales
        for px in range(x + 4, x + w - 3, 7):
            layer.rect(px, top + 3, 1, H - top, MID_DK)
        for py in range(top + 8, H, 11):
            layer.rect(x + 1, py, w - 2, 1, MID_DK)
        # Carteles de neón de 4x4 o 6x6
        for _ in range(rnd.randint(1, 2)):
            s = rnd.choice((4, 6))
            nx = x + rnd.randint(3, max(3, w - s - 3))
            ny = top + rnd.randint(6, 40)
            bright, glow = rnd.choice(NEONS)
            layer.rect(nx - 1, ny - 1, s + 2, s + 2, glow)
            layer.rect(nx, ny, s, s, bright)
            layer.rect(nx + 1, ny + 1, s - 2, s - 2, glow)  # símbolo hueco
            layer.set(nx + s // 2, ny + s // 2, bright)
        tops.append((x, w, top))
        x += w + rnd.randint(6, 18)  # huecos para ver los drones detrás
    # Tuberías gigantes entre edificios
    for i, (bx, bw, btop) in enumerate(tops):
        nx, nw, ntop = tops[(i + 1) % len(tops)]
        if nx < bx:
            nx += W
        y = max(btop, ntop) + rnd.randint(10, 30)
        for yy, c in ((y, PIPE_HI), (y + 1, PIPE), (y + 2, PIPE), (y + 3, PIPE_DK)):
            layer.rect(bx + bw - 2, yy, nx - (bx + bw) + 4, 1, c)
        for rx in range(bx + bw, nx, 6):
            layer.set(rx, y + 1, PIPE_DK)
        # Pasarela metálica con baranda
        if rnd.random() < 0.6:
            wy = y + rnd.randint(12, 22)
            layer.rect(bx + bw - 1, wy, nx - (bx + bw) + 2, 1, RAIL)
            layer.rect(bx + bw - 1, wy - 4, nx - (bx + bw) + 2, 1, RAIL)
            for rx in range(bx + bw, nx, 4):
                layer.rect(rx, wy - 4, 1, 4, RAIL)
    return layer


# --- capa 4: cables de alta tensión y ventiladores ---------------------------------

FAN_CENTERS = [(70, 104, 9), (262, 96, 11)]  # (x, y, radio) también usados por city_fans.gd


def near_city():
    layer = Layer()
    # Cables en diagonal con comba
    for x0, y0, x1, y1, sag in ((0, 18, 190, 64, 10), (150, 8, 384, 58, 14),
                                (220, 30, 420, 74, 8), (-40, 40, 120, 86, 6)):
        steps = int(abs(x1 - x0)) * 2
        for i in range(steps + 1):
            t = i / steps
            layer.set(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t + sag * math.sin(math.pi * t), CABLE)
    # Estructuras de ventilación con carcasa circular (las aspas giran por código)
    for cx, cy, r in FAN_CENTERS:
        layer.rect(cx - r - 3, cy - r - 3, 2 * r + 7, H - (cy - r - 3), VENT)
        layer.rect(cx - r - 3, cy - r - 3, 2 * r + 7, 1, VENT_HI)
        layer.circle(cx, cy, r + 1, VENT_DK)
        for i in range(64):
            a = i / 64 * math.tau
            layer.set(cx + math.cos(a) * (r + 1), cy + math.sin(a) * (r + 1), VENT_HI)
        layer.circle(cx, cy, 1.5, VENT_HI)
        for gy in range(cy + r + 4, H, 5):
            layer.rect(cx - r - 1, gy, 2 * r + 3, 1, VENT_DK)
    return layer


# --- capa 5: tileset del suelo ------------------------------------------------------

def tiles():
    atlas = Layer(TILE * 4, TILE * 4)
    img = atlas.img

    def put(tx, ty, x, y, c):
        img.putpixel((tx * TILE + x, ty * TILE + y), c)

    for col in range(3):
        for row in range(2):
            for y in range(TILE):
                for x in range(TILE):
                    if row == 0 and y < 5:
                        # Chapa corrugada del tejado
                        if y == 0:
                            c = ROOF_HI
                        elif y == 4:
                            c = ROOF_DK
                        else:
                            c = ROOF if x % 3 else ROOF_DK
                        if y == 2 and x in (3, 11):
                            c = ROOF_HI  # remaches
                    else:
                        c = WALL
                        if x in (0, 8):
                            c = WALL_DK
                        if y % 8 == 7:
                            c = WALL_DK
                        if x in (1, 9) and y % 8 < 7:
                            c = WALL_HI
                    if (col == 0 and x == 0) or (col == 2 and x == TILE - 1):
                        c = EDGE
                    put(col, row, x, y, c)
    # Tejado central con charco que refleja el neón (1-2 px borrosos)
    for y in range(TILE):
        for x in range(TILE):
            put(3, 0, x, y, img.getpixel((TILE + x, y)))
    for x in range(3, 13):
        put(3, 0, x, 0, PUDDLE)
        put(3, 0, x, 1, PUDDLE if x not in (3, 12) else ROOF)
    for x, c in ((5, NEONS[0][0]), (6, NEONS[0][1]), (9, NEONS[2][0]), (10, NEONS[2][1])):
        put(3, 0, x, 0, c)
    put(3, 0, 7, 1, NEONS[1][1])
    # Viga de acero (plataforma de un sentido)
    for col in range(3):
        for y in range(7):
            for x in range(TILE):
                if y in (0, 6):
                    c = EDGE
                elif y == 1:
                    c = BEAM_HI
                elif y == 5:
                    c = BEAM_DK
                else:
                    c = BEAM if x % 4 else BEAM_DK
                if (col == 0 and x == 0) or (col == 2 and x == TILE - 1):
                    c = EDGE
                put(col, 2, x, y, c)
        for x in range(2, TILE - 2, 5):
            put(col, 2, x, 3, BEAM_HI)
    # Púas electrificadas
    for x in range(TILE):
        peak = x % 8
        h = int(10 - abs(peak - 3.5) * 2)
        for y in range(TILE - 4, TILE):
            put(0, 3, x, y, WALL_DK)
        for y in range(TILE - 4 - h, TILE - 4):
            put(0, 3, x, y, SPIKE)
        if TILE - 5 - h >= 0:
            put(0, 3, x, TILE - 5 - h, SPIKE_TIP if peak in (3, 4) else EDGE)
    return atlas


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    sky().save("bg_0_sky.png")
    far_city().save("bg_1_far.png")
    mid_city().save("bg_2_mid.png")
    near_city().save("bg_3_near.png")
    tiles().save("tiles.png")


if __name__ == "__main__":
    main()
