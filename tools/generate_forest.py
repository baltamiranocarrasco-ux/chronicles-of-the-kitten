"""Genera las capas parallax del bosque y el tileset del suelo (pixel art).

Uso:  python3 tools/generate_forest.py
Requiere Pillow (pip install pillow).

Salida en assets/forest/:
  bg_0_sky.png ... bg_4_near.png  capas de 384x216 que se repiten en horizontal
  tiles.png                       atlas 3x4 de tiles de 16x16:
                                    fila 0: pasto (borde izq, centro, borde der)
                                    fila 1: tierra (borde izq, centro, borde der)
                                    fila 2: plataforma de madera (izq, centro, der)
                                    fila 3: púas para fosos (solo la primera columna)

Las capas están pensadas para una vista de 384x216 donde el suelo empieza
en la fila 152 (la parte de abajo queda tapada por los tiles).
"""

import math
import random
from pathlib import Path

from PIL import Image

W, H = 384, 216
HORIZON = 152  # fila donde empieza el suelo en pantalla
TILE = 16

OUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "forest"


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


# Paleta: lo lejano es más claro y azulado (perspectiva atmosférica)
SKY_TOP = rgb("#6fb3d9")
SKY_MID = rgb("#a4d3e6")
SKY_LOW = rgb("#e3f1d5")
CLOUD = rgb("#f7fbf4")
CLOUD_SHADE = rgb("#d6e8ef")
MOUNTAIN = rgb("#9db7c7")
MOUNTAIN_LIGHT = rgb("#b9ccd6")
FAR_TREE = rgb("#6e9a8c")
FAR_TREE_LIGHT = rgb("#80ab9a")
MID_TREE = rgb("#3f7352")
MID_TREE_LIGHT = rgb("#55905f")
MID_TREE_DARK = rgb("#2f5a41")
MID_TRUNK = rgb("#4a3a33")
NEAR_LEAF = rgb("#24402f")
NEAR_LEAF_LIGHT = rgb("#2f5239")
NEAR_TRUNK = rgb("#2a211d")
NEAR_TRUNK_LIGHT = rgb("#3a2e27")

GRASS = rgb("#5fae4a")
GRASS_LIGHT = rgb("#86cc5a")
GRASS_DARK = rgb("#3f8438")
DIRT = rgb("#7a5234")
DIRT_DARK = rgb("#5e3d27")
DIRT_LIGHT = rgb("#936443")
STONE = rgb("#8d8479")
EDGE = rgb("#2b1d14")
WOOD = rgb("#9a6a3f")
WOOD_LIGHT = rgb("#b98352")
WOOD_DARK = rgb("#6b4529")
SPIKE = rgb("#8a8f99")
SPIKE_LIGHT = rgb("#c3c8cf")


class Layer:
    """Imagen que envuelve en X para que la capa se repita sin costuras."""

    def __init__(self, w=W, h=H):
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w, h), (0, 0, 0, 0))

    def set(self, x, y, c):
        if 0 <= y < self.h:
            self.img.putpixel((x % self.w, y), c)

    def get(self, x, y):
        return self.img.getpixel((x % self.w, y))

    def vline(self, x, y0, y1, c):
        for y in range(max(0, y0), min(self.h, y1)):
            self.set(x, y, c)

    def circle(self, cx, cy, r, c):
        for y in range(int(cy - r), int(cy + r) + 1):
            for x in range(int(cx - r), int(cx + r) + 1):
                if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
                    self.set(x, y, c)

    def save(self, name):
        self.img.save(OUT_DIR / name)
        print(f"Guardado {OUT_DIR / name}")


def wave(x, terms):
    """Suma de senos con periodos que dividen el ancho -> siempre repetible."""
    return sum(a * math.sin(2 * math.pi * (k * x / W) + p) for a, k, p in terms)


def sky():
    layer = Layer()
    bands = [(0, SKY_TOP), (70, SKY_MID), (125, SKY_LOW)]
    for y in range(H):
        for x in range(W):
            color = SKY_TOP
            for start, c in bands:
                # Tramado en tablero de 2 filas antes de cada cambio de color
                if y >= start or (start - y <= 2 and (x + y) % 2 == 0):
                    color = c
            layer.set(x, y, color)
    # Nubes
    rnd = random.Random(3)
    for _ in range(5):
        cx, cy = rnd.randrange(W), rnd.randrange(18, 70)
        for i in range(rnd.randint(3, 5)):
            r = rnd.randint(5, 9)
            ox = i * rnd.randint(6, 9)
            layer.circle(cx + ox, cy - (r if i % 2 else r // 2), r, CLOUD)
        for x in range(cx - 4, cx + 40):
            for y in range(cy, cy + 3):
                if layer.get(x, y) == CLOUD:
                    layer.set(x, y, CLOUD_SHADE)
    return layer


def mountains():
    layer = Layer()
    for x in range(W):
        top = int(92 + wave(x, [(16, 2, 0.4), (9, 5, 1.3), (3, 11, 2.0)]))
        for y in range(top, H):
            layer.set(x, y, MOUNTAIN)
        # Luz en las laderas que miran a la izquierda
        slope = wave(x + 1, [(16, 2, 0.4), (9, 5, 1.3)]) - wave(x, [(16, 2, 0.4), (9, 5, 1.3)])
        if slope < 0:
            for y in range(top, min(top + 4, H)):
                layer.set(x, y, MOUNTAIN_LIGHT)
    return layer


def pine(layer, cx, base, height, color, light=None):
    top = base - height
    for y in range(top, base):
        t = (y - top) / height
        # Pino escalonado: el ancho crece por tramos
        half = int((t * 0.9 + 0.1) * height * 0.28 * (0.75 + 0.25 * ((y - top) % 6) / 5))
        for x in range(cx - half, cx + half + 1):
            layer.set(x, y, color)
        if light and half > 1:
            layer.set(cx - half, y, light)
    layer.vline(cx, base, H, color)


def far_trees():
    layer = Layer()
    rnd = random.Random(7)
    base = 130
    for y in range(base, H):
        for x in range(W):
            layer.set(x, y, FAR_TREE)
    x = 0
    while x < W:
        pine(layer, x, base + 2, rnd.randint(26, 44), FAR_TREE, FAR_TREE_LIGHT)
        x += rnd.randint(9, 15)
    return layer


def round_tree(layer, cx, base, rnd):
    trunk_h = rnd.randint(16, 26)
    for x in range(cx - 1, cx + 2):
        layer.vline(x, base - trunk_h, H, MID_TRUNK)
    top = base - trunk_h
    blobs = [(cx + rnd.randint(-9, 9), top + rnd.randint(-14, 0), rnd.randint(7, 11))
             for _ in range(5)]
    for bx, by, r in blobs:
        layer.circle(bx, by + 2, r, MID_TREE_DARK)
    for bx, by, r in blobs:
        layer.circle(bx, by, r, MID_TREE)
    for bx, by, r in blobs:
        layer.circle(bx - r // 3, by - r // 3, r // 2, MID_TREE_LIGHT)


def mid_trees():
    layer = Layer()
    rnd = random.Random(11)
    base = 150
    for y in range(base, H):
        for x in range(W):
            layer.set(x, y, MID_TREE_DARK)
    x = 10
    while x < W + 10:
        if rnd.random() < 0.35:
            pine(layer, x, base, rnd.randint(40, 60), MID_TREE_DARK, MID_TREE)
        else:
            round_tree(layer, x, base, rnd)
        x += rnd.randint(22, 34)
    return layer


def near_foliage():
    layer = Layer()
    rnd = random.Random(19)
    # Troncos gruesos que salen por arriba de la pantalla
    for cx in (40, 170, 300):
        cx += rnd.randint(-10, 10)
        width = rnd.randint(7, 10)
        for x in range(cx, cx + width):
            layer.vline(x, 0, H, NEAR_TRUNK)
        layer.vline(cx + 1, 0, H, NEAR_TRUNK_LIGHT)
        for y in range(10, H, 17):
            layer.set(cx + width // 2, y, NEAR_TRUNK_LIGHT)
            layer.set(cx + width // 2, y + 1, NEAR_TRUNK_LIGHT)
    # Copa superior con borde irregular
    for x in range(W):
        bottom = int(14 + wave(x, [(6, 4, 0.0), (4, 9, 1.0), (2, 23, 2.0)]))
        for y in range(0, bottom):
            layer.set(x, y, NEAR_LEAF)
        if (x // 3) % 3 == 0:
            layer.vline(x, bottom, bottom + rnd.randint(0, 6), NEAR_LEAF)
    for _ in range(40):
        layer.circle(rnd.randrange(W), rnd.randint(2, 12), rnd.randint(1, 2), NEAR_LEAF_LIGHT)
    # Arbustos al ras del suelo
    for _ in range(9):
        bx = rnd.randrange(W)
        for i in range(3):
            layer.circle(bx + i * 7, HORIZON - rnd.randint(0, 4), rnd.randint(6, 9), NEAR_LEAF)
        layer.circle(bx + 3, HORIZON - 6, 3, NEAR_LEAF_LIGHT)
    for y in range(HORIZON, H):
        for x in range(W):
            layer.set(x, y, NEAR_LEAF)
    return layer


def tiles():
    atlas = Layer(TILE * 3, TILE * 4)
    img = atlas.img
    rnd = random.Random(5)

    def put(tx, ty, x, y, c):
        img.putpixel((tx * TILE + x, ty * TILE + y), c)

    # Patrón de tierra compartido para que los tiles encajen entre sí
    dirt = [[DIRT] * TILE for _ in range(TILE)]
    for _ in range(14):
        x, y = rnd.randrange(TILE), rnd.randrange(TILE)
        dirt[y][x] = DIRT_DARK
        dirt[y][(x + 1) % TILE] = DIRT_DARK
    for _ in range(6):
        dirt[rnd.randrange(TILE)][rnd.randrange(TILE)] = DIRT_LIGHT
    for sx, sy in ((3, 10), (11, 4)):
        dirt[sy][sx] = STONE
        dirt[sy][sx + 1] = STONE
        dirt[sy + 1][sx] = DIRT_DARK

    blade = [rnd.choice((0, 1, 1, 2)) for _ in range(TILE)]
    for col in range(3):
        for row in range(2):
            for y in range(TILE):
                for x in range(TILE):
                    c = dirt[y][x]
                    if row == 0:
                        # Pasto arriba: hojitas, capa verde y borde que cae en la tierra
                        if y < 2 - blade[x] + 1 and y < 2:
                            if y < 2 - blade[x]:
                                continue
                            c = GRASS_LIGHT
                        elif y < 5:
                            c = GRASS if y > 2 else GRASS_LIGHT
                        elif y == 5 or (y == 6 and x % 5 in (1, 2)):
                            c = GRASS_DARK
                    if (col == 0 and x == 0) or (col == 2 and x == TILE - 1):
                        if not (row == 0 and y < 2 - blade[x]):
                            c = EDGE
                    put(col, row, x, y, c)

    # Plataforma de madera (una fila de 6 px de alto, arriba del tile)
    for col in range(3):
        for y in range(7):
            for x in range(TILE):
                if y in (0, 6):
                    c = EDGE
                elif y == 1:
                    c = WOOD_LIGHT
                elif y == 5:
                    c = WOOD_DARK
                else:
                    c = WOOD if (x + y * 3) % 7 else WOOD_DARK
                if (col == 0 and x == 0) or (col == 2 and x == TILE - 1):
                    c = EDGE
                if col == 1 and x in (0, 8) and 1 < y < 5:
                    c = WOOD_DARK
                put(col, 2, x, y, c)
        # Soportes bajo los extremos
        if col != 1:
            sx = 3 if col == 0 else TILE - 5
            for y in range(7, 11):
                for x in range(sx, sx + 2):
                    put(col, 2, x, y, WOOD_DARK)
                put(col, 2, sx - 1, y, EDGE)
                put(col, 2, sx + 2, y, EDGE)
            for x in range(sx - 1, sx + 3):
                put(col, 2, x, 11, EDGE)

    # Púas para el fondo de los fosos (solo decorativo, sin colisión)
    for x in range(TILE):
        peak = x % 8
        h = 7 - abs(peak - 3.5) * 2 + 3
        for y in range(TILE):
            if y >= TILE - 4:
                c = DIRT_DARK
            elif y >= TILE - 4 - h:
                c = SPIKE_LIGHT if peak < 4 else SPIKE
            else:
                continue
            put(0, 3, x, y, c)
        top = int(TILE - 4 - h)
        if 0 <= top - 1:
            put(0, 3, x, top - 1, EDGE)
    return atlas


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    sky().save("bg_0_sky.png")
    mountains().save("bg_1_mountains.png")
    far_trees().save("bg_2_far_trees.png")
    mid_trees().save("bg_3_mid_trees.png")
    near_foliage().save("bg_4_near.png")
    tiles().save("tiles.png")


if __name__ == "__main__":
    main()
