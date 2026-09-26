"""Genera el fondo parallax de la megaciudad y el tileset del suelo.

Uso:  python3 tools/generate_city.py
Requiere Pillow y numpy (pip install pillow numpy).

El fondo busca verse realista dentro de la resolución del juego: bruma que
aclara y desatura lo lejano, smog iluminado desde abajo por la ciudad,
fachadas con cara iluminada y cara en sombra, ventanas por pisos (oficinas
con pisos enteros encendidos, otros apagados), carteles y letreros que
derraman su luz en las paredes y la niebla, y siluetas de azoteas cercanas.
Las capas de ciudad miden 768 px de ancho (dos pantallas) para que la
repetición no se note.

Salida en assets/city/ (el suelo del nivel empieza en la fila 152 de la vista):
  bg_0_sky.png        cielo con smog, nubes iluminadas y luna      384x216   (0 %)
  bg_1_far.png        horizonte de rascacielos entre la bruma       768x216  (10 %)
  bg_2_midfar.png     torres con ventanas por pisos y pantallas     768x216  (22 %)
  bg_3_mid.png        edificios con escaleras de incendio y neón    768x216  (40 %)
  bg_4_near.png       azoteas cercanas, tanques de agua y cables    768x216  (65 %)
  tiles.png           atlas 4x4 de 16x16:
                        fila 0: tejado de chapa (izq, centro, der, centro con charco)
                        fila 1: muro del edificio (izq, centro, der)
                        fila 2: viga de acero, plataforma de un sentido (izq, centro, der)
                        fila 3: púas electrificadas para los fosos (solo la primera)

Algunas ventanas de bg_2_midfar usan dos colores clave exactos
(WINDOW_YELLOW y WINDOW_CYAN) que effects/city_life.gd busca para
apagarlas y encenderlas, y bg_3_mid lleva proyectores en algunas azoteas
marcados con HOLO_KEY, donde effects/hologram_ads.gd dibuja hologramas
publicitarios. Los drones, el tráfico y los hologramas se dibujan por código
para que respondan a las habilidades de tiempo.
"""

import math
import random
from pathlib import Path

import numpy as np
from PIL import Image

H = 216
SKY_W = 384
CITY_W = 768
HORIZON = 152
TILE = 16
OUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "city"


def rgb(h, a=255):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


WINDOW_YELLOW = rgb("#f0c85a")
WINDOW_CYAN = rgb("#5ad8f0")

# Luz de las ventanas: cálida (sodio/incandescente), fría (fluorescente), LED
WARM = [rgb("#f0c85a"), rgb("#e8b050"), rgb("#f4d890"), rgb("#d89848")]
COOL = [rgb("#dce8f4"), rgb("#b8d0ec"), rgb("#9cc4e8")]
LED = [rgb("#5ad8f0"), rgb("#8ae0ff"), rgb("#c890ff")]
NEON = [rgb("#ff3cc8"), rgb("#3ce6ff"), rgb("#ff5a3c"), rgb("#96ff3c"), rgb("#b45aff"), rgb("#ffd23c")]
AVIATION = rgb("#ff3030")
# Proyector de hologramas publicitarios: effects/hologram_ads.gd busca este
# píxel exacto en bg_3_mid y dibuja encima el holograma que gira
HOLO_KEY = rgb("#01fe7f")

# Bruma de la ciudad: el smog refleja las luces en tonos magenta-anaranjados
HAZE = rgb("#5a3a64")
FOG = rgb("#8a4a6e")
FOG_LOW = rgb("#6a3c62")


# --- lienzo con composición en punto flotante ------------------------------

class Canvas:
    """Imagen RGBA premultiplicada que envuelve en X (la capa se repite)."""

    def __init__(self, w, h=H):
        self.w, self.h = w, h
        self.P = np.zeros((h, w, 3), np.float32)
        self.A = np.zeros((h, w), np.float32)

    def _cols(self, x0, x1):
        return np.arange(int(x0), int(x1)) % self.w

    def over(self, y0, y1, x0, x1, color, alpha=1.0):
        y0, y1 = max(0, int(y0)), min(self.h, int(y1))
        if y1 <= y0 or x1 <= x0:
            return
        cols = self._cols(x0, x1)
        c = np.array(color[:3], np.float32) / 255.0
        a = np.broadcast_to(np.asarray(alpha, np.float32), (y1 - y0, len(cols)))
        P = self.P[y0:y1][:, cols]
        A = self.A[y0:y1][:, cols]
        self.P[y0:y1, cols] = c * a[..., None] + P * (1 - a[..., None])
        self.A[y0:y1, cols] = a + A * (1 - a)

    def rect(self, x, y, w, h, color, alpha=1.0):
        self.over(y, y + h, x, x + w, color, alpha)

    def px(self, x, y, color, alpha=1.0):
        self.over(y, y + 1, x, x + 1, color, alpha)

    def line(self, x0, y0, x1, y1, color, alpha=1.0):
        steps = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        seen = set()
        for i in range(steps + 1):
            t = i / steps
            p = (round(x0 + (x1 - x0) * t), round(y0 + (y1 - y0) * t))
            if p not in seen:
                seen.add(p)
                self.px(p[0], p[1], color, alpha)

    def glow(self, cx, cy, r, color, strength):
        """Halo de luz que cae sobre paredes y niebla (también en el aire)."""
        y0, y1 = int(cy - r), int(cy + r) + 1
        x0, x1 = int(cx - r), int(cx + r) + 1
        ys = np.arange(max(0, y0), min(self.h, y1))
        if len(ys) == 0:
            return
        xs = np.arange(x0, x1)
        d = np.sqrt((xs[None, :] + 0.5 - cx) ** 2 + (ys[:, None] + 0.5 - cy) ** 2)
        a = strength * np.clip(1 - d / r, 0, 1) ** 2
        self.over(ys[0], ys[-1] + 1, x0, x1, color, a)

    def light(self, cx, cy, r, color, amount):
        """Luz aditiva con caída radial, solo sobre lo ya pintado (reflejo del
        neón en las fachadas)."""
        y0, y1 = max(0, int(cy - r)), min(self.h, int(cy + r) + 1)
        if y1 <= y0:
            return
        x0 = int(cx - r)
        cols = self._cols(x0, int(cx + r) + 1)
        xs = np.arange(x0, x0 + len(cols))
        ys = np.arange(y0, y1)
        d = np.sqrt((xs[None, :] + 0.5 - cx) ** 2 + (ys[:, None] + 0.5 - cy) ** 2)
        k = amount * np.clip(1 - d / r, 0, 1) ** 2
        c = np.array(color[:3], np.float32) / 255.0
        A = self.A[y0:y1][:, cols]
        P = self.P[y0:y1][:, cols] + c * (k * A)[..., None]
        self.P[y0:y1, cols] = np.minimum(P, A[..., None])

    def haze(self, color, k):
        """Perspectiva atmosférica: acerca lo pintado al color de la bruma."""
        c = np.array(color[:3], np.float32) / 255.0
        self.P = self.P * (1 - k) + c * k * self.A[..., None]

    def vfog(self, y0, y1, color, amax, power=1.5):
        """Banco de niebla que se espesa hacia abajo, en toda la capa."""
        for y in range(max(0, int(y0)), self.h):
            t = min(1.0, (y - y0) / max(1, (y1 - y0)))
            self.over(y, y + 1, 0, self.w, color, amax * t ** power)

    def image(self):
        A = self.A[..., None]
        rgb_ = np.where(A > 1e-4, self.P / np.maximum(A, 1e-4), 0)
        out = np.concatenate([rgb_, A], axis=2)
        return Image.fromarray(np.clip(out * 255 + 0.5, 0, 255).astype(np.uint8), "RGBA")


def noise(w, h, cell, rnd, octaves=4):
    """Ruido de valor fractal que envuelve en X (nubes, suciedad)."""
    total = np.zeros((h, w), np.float32)
    amp, norm = 1.0, 0.0
    for o in range(octaves):
        c = max(2, cell >> o)
        gx, gy = max(1, w // c), h // c + 2
        grid = np.array([[rnd.random() for _ in range(gx)] for _ in range(gy)], np.float32)
        xs = np.arange(w) / w * gx
        ys = np.arange(h) / c
        x0 = np.floor(xs).astype(int)
        y0 = np.floor(ys).astype(int)
        fx = xs - x0
        fy = ys - y0
        fx = fx * fx * (3 - 2 * fx)
        fy = fy * fy * (3 - 2 * fy)
        a = grid[y0][:, x0 % gx]
        b = grid[y0][:, (x0 + 1) % gx]
        cc = grid[y0 + 1][:, x0 % gx]
        d = grid[y0 + 1][:, (x0 + 1) % gx]
        top = a + (b - a) * fx[None, :]
        bot = cc + (d - cc) * fx[None, :]
        total += (top + (bot - top) * fy[:, None]) * amp
        norm += amp
        amp *= 0.5
    return total / norm


def mix(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3)) + (255,)


def scale(c, k):
    return tuple(min(255, int(v * k)) for v in c[:3]) + (255,)


# --- capa 0: cielo -------------------------------------------------------------

def sky():
    cv = Canvas(SKY_W)
    stops = [(0, rgb("#06050e")), (55, rgb("#120c26")), (100, rgb("#2a1640")),
             (135, rgb("#5a2650")), (165, rgb("#8e3c5c")), (216, rgb("#a8506a"))]
    for y in range(H):
        for (ya, ca), (yb, cb) in zip(stops, stops[1:]):
            if ya <= y <= yb:
                cv.rect(0, y, SKY_W, 1, mix(ca, cb, (y - ya) / (yb - ya)))
                break
    rnd = random.Random(21)
    # Pocas estrellas: la contaminación lumínica tapa casi todas
    for _ in range(45):
        x, y = rnd.randrange(SKY_W), rnd.randrange(0, 70)
        cv.px(x, y, rgb("#d8d8f0"), rnd.uniform(0.25, 0.9) * (1 - y / 85))
    # Luna velada por el smog
    mx, my, mr = 292, 36, 10
    cv.glow(mx, my, 46, rgb("#7a70a8"), 0.18)
    cv.glow(mx, my, 18, rgb("#b0b0d0"), 0.18)
    maria = noise(32, 32, 6, rnd, 3)
    for y in range(-mr, mr + 1):
        for x in range(-mr, mr + 1):
            d = math.hypot(x + 0.5, y + 0.5)
            if d <= mr:
                limb = 1 - 0.35 * (d / mr) ** 3
                m = maria[y + 16, x + 16]
                shade = limb * (1.0 - 0.35 * max(0.0, min(1.0, (m - 0.45) / 0.2)))
                cv.px(mx + x, my + y, scale(rgb("#c8c6d4"), shade))
    # Nubes altas y finas
    hi = noise(SKY_W, H, 64, rnd, 5)
    # Smog bajo, iluminado desde abajo por la ciudad
    lo = noise(SKY_W, H, 48, rnd, 5)
    for y in range(H):
        band_hi = max(0.0, 1 - abs(y - 45) / 30)
        band_lo = min(1.0, max(0.0, (y - 70) / 50))
        for layer, band, dark, lit, thr in ((hi, band_hi, rgb("#1c1430"), rgb("#4a2a58"), 0.5),
                                            (lo, band_lo, rgb("#2a1838"), rgb("#c0607a"), 0.42)):
            if band <= 0:
                continue
            row = layer[y]
            a = np.clip((row - thr) / 0.18, 0, 1) * band * 0.85
            # Iluminada por debajo: la parte baja de cada nube es más clara
            under = np.clip((layer[min(H - 1, y + 3)] - row) * 6 + (y / H), 0, 1)
            for x in np.nonzero(a > 0.02)[0]:
                cv.px(x, y, mix(dark, lit, float(under[x])), float(a[x]))
    return cv


# --- edificios -----------------------------------------------------------------

class Style:
    def __init__(self, **kw):
        self.__dict__.update(kw)


def windows(cv, x, w, top, st, rnd, keys=None, bottom=H):
    """Rejilla de ventanas por pisos. Devuelve nada; si keys es una lista,
    agrega ahí las ventanas encendidas que pueden parpadear."""
    ww, wh, sx, sy = st.win
    palette = rnd.choice(st.palettes)
    lit_p = rnd.uniform(*st.lit)
    unlit = scale(mix(st.face, rgb("#3a4a6a"), 0.35), 1.15)
    for fy in range(top + st.margin_top, bottom - wh, sy):
        state = rnd.random()
        p = lit_p * (0.15 if state < 0.2 else 3.5 if state > 0.9 else 1.0)
        for fx in range(x + st.margin, x + w - st.margin - ww + 1, sx):
            if rnd.random() < p:
                col = rnd.choice(palette)
                if keys is not None and fy < 118 and rnd.random() < 0.35:
                    col = WINDOW_YELLOW if palette is WARM else WINDOW_CYAN
                    keys.append((fx, fy, col))
                    cv.rect(fx, fy, ww, wh, col)
                else:
                    cv.rect(fx, fy, ww, wh, scale(col, rnd.uniform(0.75, 1.05)))
            elif st.show_unlit:
                cv.rect(fx, fy, ww, wh, unlit, 0.6)


def building(cv, x, w, top, st, rnd, keys=None):
    """Torre con cara iluminada, cara lateral en sombra, remates y ventanas."""
    side = max(1, int(w * st.side_ratio))
    tiers = [(x, w, top)]
    if w > 14 and rnd.random() < st.setback_p:
        inset = rnd.randint(2, max(2, w // 5))
        tiers.append((x + inset, w - 2 * inset, top - rnd.randint(8, 28)))
        if w > 24 and rnd.random() < 0.4:
            inset2 = inset + rnd.randint(2, max(2, w // 6))
            tiers.append((x + inset2, w - 2 * inset2, tiers[-1][2] - rnd.randint(6, 16)))
    for tx, tw, tt in tiers:
        cv.rect(tx, tt, tw, H - tt, st.face)
        cv.rect(tx + tw - side, tt, side, H - tt, st.shade)
        cv.rect(tx, tt, 1, H - tt, st.rim, 0.8)
        cv.rect(tx, tt, tw, 1, st.rim, 0.9)
        if st.floor_lines:
            for fy in range(tt + 4, H, st.win[3] * 2):
                cv.rect(tx + 1, fy, tw - side - 1, 1, st.shade, 0.35)
    ctx, ctw, ctop = tiers[-1]
    crown = rnd.random()
    if crown < st.spire_p:
        h = rnd.randint(6, 18)
        for i in range(h):
            half = max(0, (ctw // 2 - 1) * (h - i) // h)
            cv.rect(ctx + ctw // 2 - half, ctop - i - 1, half * 2 + 1, 1, st.face)
        cv.px(ctx + ctw // 2, ctop - h - 1, AVIATION)
        cv.glow(ctx + ctw // 2, ctop - h - 1, 4, AVIATION, 0.35)
    elif crown < st.spire_p + st.antenna_p:
        ax = ctx + rnd.randint(1, max(1, ctw - 2))
        ah = rnd.randint(6, 20)
        cv.rect(ax, ctop - ah, 1, ah, st.shade)
        cv.px(ax, ctop - ah, AVIATION)
        cv.glow(ax, ctop - ah, 4, AVIATION, 0.3)
    return tiers


def facade_windows(cv, tiers, st, rnd, keys=None):
    for tx, tw, tt in tiers:
        side = max(1, int(tw * st.side_ratio))
        windows(cv, tx, tw - side, tt, st, rnd, keys)


def billboard(cv, x, y, w, h, rnd):
    """Pantalla publicitaria: degradado de dos neones, "texto" y halo de luz."""
    c1, c2 = rnd.sample(NEON, 2)
    cv.rect(x - 1, y - 1, w + 2, h + 2, rgb("#0c0a14"))
    for yy in range(h):
        cv.rect(x, y + yy, w, 1, mix(c1, c2, yy / max(1, h - 1)))
    for row in range(y + 2, y + h - 2, 3):
        length = rnd.randint(w // 3, w - 2)
        cv.rect(x + 1, row, length, 1, rgb("#1a1020"), 0.55)
    avg = mix(c1, c2, 0.5)
    cv.glow(x + w / 2, y + h / 2, max(w, h) * 1.4, avg, 0.28)
    cv.light(x + w / 2, y + h / 2, max(w, h) * 2, avg, 0.35)


def neon_sign(cv, x, y, h, rnd):
    """Letrero vertical con glifos, sobresale de la fachada."""
    col = rnd.choice(NEON)
    cv.rect(x - 1, y - 1, 5, h + 2, rgb("#120c18"))
    cv.rect(x, y, 3, h, scale(col, 0.35))
    for gy in range(y + 1, y + h - 3, 5):
        glyph = rnd.getrandbits(9)
        for i in range(9):
            if glyph >> i & 1:
                cv.px(x + i % 3, gy + i // 3, col)
    cv.glow(x + 1.5, y + h / 2, h * 0.8, col, 0.22)
    cv.light(x + 1.5, y + h / 2, h, col, 0.4)


def fire_escape(cv, x, top, w, color, rnd):
    for fy in range(top + 6, HORIZON + 10, 9):
        cv.rect(x, fy, w, 1, color)
        cv.rect(x, fy - 3, 1, 3, color, 0.7)
        cv.rect(x + w - 1, fy - 3, 1, 3, color, 0.7)
        cv.line(x + 1, fy + 8, x + w - 2, fy + 1, color, 0.8)


def water_tank(cv, x, base, color, rim):
    cv.rect(x, base - 12, 9, 8, color)
    cv.rect(x + 1, base - 14, 7, 2, color)
    cv.rect(x + 3, base - 15, 3, 1, color)
    for i in (1, 7):
        cv.rect(x + i, base - 4, 1, 4, color)
    cv.line(x + 1, base - 1, x + 7, base - 4, color)
    cv.rect(x, base - 12, 9, 1, rim, 0.6)
    for yy in (base - 10, base - 7):
        cv.rect(x, yy, 9, 1, scale(color, 1.4), 0.5)


def skyline(cv, st, rnd, keys=None, extra=None):
    x = rnd.randint(0, 10)
    tiers_all = []
    while x < cv.w:
        w = rnd.randint(*st.width)
        top = H - rnd.randint(*st.height)
        tiers = building(cv, x, w, top, st, rnd)
        tiers_all.append((x, w, top, tiers))
        x += w + rnd.randint(*st.gap)
    return tiers_all


# --- capa 1: horizonte lejano ------------------------------------------------------

def far_city():
    cv = Canvas(CITY_W)
    rnd = random.Random(33)
    # Dos filas de siluetas para dar profundidad dentro de la misma capa
    back = Style(face=rgb("#2c2446"), shade=rgb("#221c3a"), rim=rgb("#3e3260"),
                 side_ratio=0.2, setback_p=0.5, spire_p=0.15, antenna_p=0.45,
                 width=(10, 26), height=(95, 185), gap=(0, 2),
                 win=(1, 1, 2, 3), margin=1, margin_top=3, lit=(0.08, 0.2),
                 palettes=[WARM, COOL], show_unlit=False, floor_lines=False)
    front = Style(**{**back.__dict__, "face": rgb("#221c3a"), "shade": rgb("#18142c"),
                     "rim": rgb("#352c56"), "height": (80, 150), "width": (12, 30),
                     "lit": (0.12, 0.3)})
    for st in (back, front):
        for _x, _w, _t, tiers in skyline(cv, st, rnd):
            facade_windows(cv, tiers, st, rnd)
        if st is back:
            cv.haze(HAZE, 0.35)
            cv.vfog(60, 216, FOG, 0.55)
    cv.haze(HAZE, 0.3)
    cv.vfog(80, 200, FOG, 0.75, power=1.3)
    return cv


# --- capa 2: torres medianas con pantallas ------------------------------------------

def midfar_city(keys):
    cv = Canvas(CITY_W)
    rnd = random.Random(52)
    st = Style(face=rgb("#1e1a34"), shade=rgb("#141126"), rim=rgb("#3a3060"),
               side_ratio=0.22, setback_p=0.45, spire_p=0.12, antenna_p=0.5,
               width=(18, 40), height=(95, 165), gap=(6, 24),
               win=(1, 1, 2, 2), margin=2, margin_top=4, lit=(0.1, 0.32),
               palettes=[WARM, COOL, LED], show_unlit=True, floor_lines=True)
    towers = skyline(cv, st, rnd)
    cv.haze(HAZE, 0.25)
    for _x, _w, _t, tiers in towers:
        facade_windows(cv, tiers, st, rnd, keys)
    # Franjas LED en las aristas de algunas torres
    for x, w, top, tiers in towers:
        if rnd.random() < 0.18:
            col = rnd.choice(LED)
            tx, tw, tt = tiers[-1]
            cv.rect(tx, tt, 1, H - tt, col, 0.8)
            cv.glow(tx, (tt + HORIZON) / 2, 10, col, 0.15)
    # Pantallas gigantes
    for x, w, top, tiers in towers:
        if w >= 24 and rnd.random() < 0.35 and top < 110:
            bw, bh = rnd.randint(10, w - 8), rnd.randint(12, 22)
            billboard(cv, x + 3, top + rnd.randint(6, 20), bw, bh, rnd)
    cv.vfog(110, 216, FOG, 0.6)
    return cv


# --- capa 3: edificios cercanos con escaleras de incendio y neón ---------------------

def projector(cv, cx, top):
    """Proyector de hologramas sobre una azotea (la lente es el color clave)."""
    base = rgb("#0c0a14")
    cv.rect(cx - 4, top - 3, 9, 3, base)
    cv.rect(cx - 2, top - 5, 5, 2, base)
    cv.rect(cx - 4, top - 3, 9, 1, rgb("#4a3a66"), 0.8)
    cv.px(cx - 3, top - 2, AVIATION)


def mid_city(holo_keys):
    cv = Canvas(CITY_W)
    rnd = random.Random(47)
    st = Style(face=rgb("#1a1628"), shade=rgb("#0f0c1a"), rim=rgb("#4a3a66"),
               side_ratio=0.18, setback_p=0.25, spire_p=0.0, antenna_p=0.35,
               width=(34, 64), height=(100, 150), gap=(14, 40),
               win=(2, 3, 5, 6), margin=3, margin_top=5, lit=(0.12, 0.35),
               palettes=[WARM, WARM, COOL, LED], show_unlit=True, floor_lines=True)
    blocks = skyline(cv, st, rnd)
    cv.haze(HAZE, 0.12)
    for x, w, top, tiers in blocks:
        facade_windows(cv, tiers, st, rnd)
        # Aires acondicionados colgando de algunas ventanas
        for _ in range(rnd.randint(2, 6)):
            ax = x + rnd.randint(3, w - 8)
            ay = top + rnd.randint(8, 60)
            cv.rect(ax, ay, 3, 2, rgb("#3a3648"))
            cv.px(ax, ay + 2, rgb("#141220"))
        if rnd.random() < 0.55:
            fx = x + rnd.randint(4, max(4, w - 18))
            fire_escape(cv, fx, top, 12, rgb("#08060e"), rnd)
        if rnd.random() < 0.3:
            water_tank(cv, x + rnd.randint(2, max(2, w - 12)), top, rgb("#0e0b18"), st.rim)
    # Letreros verticales de neón y alguna pantalla
    for x, w, top, tiers in blocks:
        if rnd.random() < 0.6:
            neon_sign(cv, x + w - 2, top + rnd.randint(10, 30), rnd.randint(14, 30), rnd)
        if rnd.random() < 0.2:
            billboard(cv, x + 4, top + rnd.randint(8, 24), min(w - 10, 26), rnd.randint(10, 16), rnd)
    # Proyectores de hologramas en azoteas anchas, separados entre sí: el
    # holograma flota ~55 px sobre el proyector, así que la azotea no puede
    # estar demasiado alta
    last = -999
    for x, w, top, tiers in blocks:
        tx, tw, tt = tiers[-1]
        if tw >= 16 and 72 <= tt <= 112 and tx - last >= 200:
            cx = tx + tw // 2
            projector(cv, cx, tt)
            holo_keys.append((cx, tt - 5))
            last = tx
    cv.vfog(125, 216, FOG_LOW, 0.5)
    return cv


# --- capa 4: azoteas cercanas ---------------------------------------------------------

def near_city():
    cv = Canvas(CITY_W)
    rnd = random.Random(61)
    dark = rgb("#0c0a14")
    rim_cols = [rgb("#7a3a7a"), rgb("#3a6a8a"), rgb("#8a4a5a")]
    x = 0
    roofs = []
    while x < CITY_W:
        w = rnd.randint(36, 90)
        top = rnd.randint(126, 148)
        rim = rnd.choice(rim_cols)
        cv.rect(x, top, w, H - top, dark)
        cv.rect(x, top, w, 1, rim)
        cv.rect(x, top, 1, H - top, rim, 0.5)
        # Pretil y algunas ventanas grandes cálidas
        cv.rect(x, top + 2, w, 1, rgb("#16121e"))
        for _ in range(rnd.randint(0, 3)):
            wx = x + rnd.randint(4, w - 8)
            wy = top + rnd.randint(8, 30)
            col = rnd.choice(WARM)
            cv.rect(wx, wy, 3, 4, scale(col, 0.8))
            cv.glow(wx + 1.5, wy + 2, 8, col, 0.12)
        # Estructuras de azotea
        item = rnd.random()
        if item < 0.35:
            water_tank(cv, x + rnd.randint(4, w - 14), top, dark, rim)
        elif item < 0.6:
            # Armazón de un cartel visto desde atrás
            bx = x + rnd.randint(4, max(4, w - 34))
            bh = rnd.randint(14, 22)
            for i in range(0, 30, 6):
                cv.rect(bx + i, top - bh, 1, bh, dark)
            cv.rect(bx, top - bh, 30, 2, dark)
            cv.line(bx, top, bx + 12, top - bh, dark)
            cv.line(bx + 18, top - bh, bx + 29, top, dark)
            cv.glow(bx + 15, top - bh - 2, 22, rnd.choice(NEON), 0.18)
        elif item < 0.8:
            # Caseta de escalera y antena parabólica
            cx = x + rnd.randint(4, w - 16)
            cv.rect(cx, top - 9, 12, 9, dark)
            cv.rect(cx, top - 9, 12, 1, rim, 0.7)
            cv.rect(cx + 4, top - 6, 3, 5, rgb("#e8b050"), 0.7)
            for i in range(5):
                cv.rect(cx + 13 + i, top - 4 - i + abs(i - 2), 1, 2, dark)
        roofs.append((x, w, top))
        x += w + rnd.randint(30, 80)
    # Tendido eléctrico entre postes
    poles = [(px, t) for px, w, t in roofs[::2]]
    for (x0, t0), (x1, t1) in zip(poles, poles[1:] + [(poles[0][0] + CITY_W, poles[0][1])]):
        cv.rect(x0 + 2, t0 - 26, 1, 26, dark)
        cv.rect(x0 - 1, t0 - 24, 7, 1, dark)
        for k, dy in ((0, -24), (5, -24)):
            steps = int(x1 - x0)
            for i in range(steps):
                t = i / steps
                y = (t0 + dy) + (t1 - t0) * t + 10 * math.sin(math.pi * t)
                cv.px(x0 - 1 + k + i, y, rgb("#07050c"))
    cv.vfog(150, 216, FOG_LOW, 0.3)
    return cv


# --- capa 5: tileset del suelo ----------------------------------------------------------

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
PUDDLE_NEONS = [(rgb("#ff3cc8"), rgb("#7a1c62")), (rgb("#96ff3c"), rgb("#3e6a18")),
                (rgb("#3ce6ff"), rgb("#1a5e6e"))]


def tiles():
    img = Image.new("RGBA", (TILE * 4, TILE * 4), (0, 0, 0, 0))

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
    for x, c in ((5, PUDDLE_NEONS[0][0]), (6, PUDDLE_NEONS[0][1]), (9, PUDDLE_NEONS[2][0]),
                 (10, PUDDLE_NEONS[2][1])):
        put(3, 0, x, 0, c)
    put(3, 0, 7, 1, PUDDLE_NEONS[1][1])
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
    return img


def save(img, name):
    img.save(OUT_DIR / name)
    print(f"Guardado {OUT_DIR / name}")


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for old in ("bg_2_mid.png", "bg_3_near.png"):  # nombres de la versión anterior
        for f in (OUT_DIR / old, OUT_DIR / (old + ".import")):
            if f.exists():
                f.unlink()
    save(sky().image(), "bg_0_sky.png")
    save(far_city().image(), "bg_1_far.png")
    keys = []
    img = midfar_city(keys).image()
    # Las ventanas que parpadean llevan el color clave exacto (la niebla y
    # los halos pueden haberlas teñido)
    for x, y, col in keys:
        if img.getpixel((x % CITY_W, y))[3] == 255:
            img.putpixel((x % CITY_W, y), col)
    save(img, "bg_2_midfar.png")
    holo_keys = []
    img = mid_city(holo_keys).image()
    for x, y in holo_keys:
        img.putpixel((x % CITY_W, y), HOLO_KEY)
    print(f"Proyectores de hologramas: {holo_keys}")
    save(img, "bg_3_mid.png")
    save(near_city().image(), "bg_4_near.png")
    save(tiles(), "tiles.png")


if __name__ == "__main__":
    main()
