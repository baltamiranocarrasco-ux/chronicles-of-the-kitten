"""Genera el fondo parallax de la megaciudad en alta resolución.

Uso:  python3 tools/generate_city.py
Requiere Pillow y numpy (pip install pillow numpy).

El gato y el suelo son pixel art a la resolución del juego (384x216); el
fondo, en cambio, es una ilustración digital con el triple de detalle
(S = 3): cada capa se dibuja a 1152 px por pantalla y el nivel la muestra a
escala 1/3, así que en la ventana de 1152x648 se ve píxel a píxel.

  bg_0_sky.png      cielo azul medianoche -> púrpura neón, nubes con sombras
                    suaves y luna gigante                    1152x648  (0 %)
  bg_1_far.png      horizonte de rascacielos entre la bruma  2304x648  (10 %)
  bg_2_midfar.png   torres corporativas de cristal oscuro con reflejos,
                    lluvia que resbala y pantallas           2304x648  (22 %)
  bg_3_mid.png      edificios de concreto, escaleras de incendio, neón,
                    conductos con humo y los 4 proyectores   2304x648  (40 %)
  bg_4_near.png     azoteas cercanas mojadas, tanques y cables 2304x648 (65 %)
  city_meta.gd      posiciones (en píxeles del juego) de los proyectores de
                    hologramas, las ventanas que parpadean y los conductos
                    que echan humo, para effects/hologram_ads.gd y
                    effects/city_life.gd

El suelo del nivel (tiles.png) lo genera tools/generate_tiles.py.
"""

import math
import random
from pathlib import Path

import numpy as np
from PIL import Image

S = 3                       # detalle del fondo respecto a los píxeles del juego
H = 216 * S
SKY_W = 384 * S
CITY_W = 768 * S
HZ = 152 * S                # fila donde empieza el suelo del nivel
ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "city"


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def scale(c, k):
    return tuple(min(255, c[i] * k) for i in range(3))


WARM = [rgb("#ffcf7a"), rgb("#f2b45a"), rgb("#ffe2a8"), rgb("#e89a4a")]
COOL = [rgb("#e4ecf8"), rgb("#bcd4f0"), rgb("#a4c8ec")]
LED = [rgb("#6ae4ff"), rgb("#96ecff"), rgb("#c89aff")]
NEON = [rgb("#ff3cc8"), rgb("#3ce6ff"), rgb("#ff6a3c"), rgb("#b45aff"), rgb("#ffcc3c")]
AVIATION = rgb("#ff2a2a")
HAZE = rgb("#4a3a78")
FOG = rgb("#7a4a96")
FOG_LOW = rgb("#5a3a7a")


# --- lienzo en punto flotante, con antialias y repetición en X --------------

class Canvas:
    def __init__(self, w, h=H):
        self.w, self.h = w, h
        self.P = np.zeros((h, w, 3), np.float32)   # color premultiplicado
        self.A = np.zeros((h, w), np.float32)

    def blend(self, y0, x0, a, color):
        """Compone 'a' (alfa, matriz ny x nx) con un color o una matriz de colores."""
        ny, nx = a.shape
        ya, yb = max(0, y0), min(self.h, y0 + ny)
        if yb <= ya or nx == 0:
            return
        a = a[ya - y0:yb - y0]
        c = np.asarray(color, np.float32)
        if c.ndim == 1:
            c = c / 255.0
        else:
            c = c[ya - y0:yb - y0] / 255.0
        cols = np.arange(x0, x0 + nx) % self.w
        P = self.P[ya:yb][:, cols]
        A = self.A[ya:yb][:, cols]
        a3 = a[..., None]
        self.P[ya:yb, cols] = c * a3 + P * (1 - a3)
        self.A[ya:yb, cols] = a + A * (1 - a)

    def rect(self, x, y, w, h, color, alpha=1.0):
        x, y, w, h = int(round(x)), int(round(y)), int(round(w)), int(round(h))
        if w > 0 and h > 0:
            self.blend(y, x, np.full((h, w), alpha, np.float32), color)

    def vgrad(self, x, y, w, h, top, bottom, alpha=1.0):
        x, y, w, h = int(round(x)), int(round(y)), int(round(w)), int(round(h))
        if w <= 0 or h <= 0:
            return
        t = np.linspace(0, 1, h, dtype=np.float32)[:, None, None]
        c = np.array(top, np.float32) * (1 - t) + np.array(bottom, np.float32) * t
        self.blend(y, x, np.full((h, w), alpha, np.float32), np.broadcast_to(c, (h, w, 3)))

    def _field(self, x0, y0, x1, y1):
        xs = np.arange(int(math.floor(x0)), int(math.ceil(x1)) + 1)
        ys = np.arange(int(math.floor(y0)), int(math.ceil(y1)) + 1)
        return xs, ys

    def seg(self, x0, y0, x1, y1, width, color, alpha=1.0):
        """Línea con antialias (distancia al segmento)."""
        pad = width + 2
        xs, ys = self._field(min(x0, x1) - pad, min(y0, y1) - pad, max(x0, x1) + pad, max(y0, y1) + pad)
        px = xs[None, :] + 0.5
        py = ys[:, None] + 0.5
        dx, dy = x1 - x0, y1 - y0
        L = dx * dx + dy * dy
        t = np.clip(((px - x0) * dx + (py - y0) * dy) / L, 0, 1) if L > 0 else 0
        d = np.hypot(px - (x0 + t * dx), py - (y0 + t * dy))
        a = np.clip(width / 2 + 0.5 - d, 0, 1) * alpha
        self.blend(int(ys[0]), int(xs[0]), a.astype(np.float32), color)

    def poly(self, pts, width, color, alpha=1.0):
        for (a, b) in zip(pts, pts[1:]):
            self.seg(a[0], a[1], b[0], b[1], width, color, alpha)

    def disc(self, cx, cy, r, color, alpha=1.0):
        xs, ys = self._field(cx - r - 1, cy - r - 1, cx + r + 1, cy + r + 1)
        d = np.hypot(xs[None, :] + 0.5 - cx, ys[:, None] + 0.5 - cy)
        a = np.clip(r + 0.5 - d, 0, 1) * alpha
        self.blend(int(ys[0]), int(xs[0]), a.astype(np.float32), color)

    def glow(self, cx, cy, r, color, strength):
        """Halo de luz difusa (también sobre el aire y la niebla)."""
        xs, ys = self._field(cx - r, cy - r, cx + r, cy + r)
        d = np.hypot(xs[None, :] + 0.5 - cx, ys[:, None] + 0.5 - cy)
        a = strength * np.clip(1 - d / r, 0, 1) ** 2
        self.blend(int(ys[0]), int(xs[0]), a.astype(np.float32), color)

    def light(self, cx, cy, r, color, amount):
        """Luz aditiva con caída radial, solo sobre lo ya pintado."""
        xs, ys = self._field(cx - r, cy - r, cx + r, cy + r)
        ya, yb = max(0, int(ys[0])), min(self.h, int(ys[-1]) + 1)
        if yb <= ya:
            return
        ys = np.arange(ya, yb)
        d = np.hypot(xs[None, :] + 0.5 - cx, ys[:, None] + 0.5 - cy)
        k = (amount * np.clip(1 - d / r, 0, 1) ** 2).astype(np.float32)
        cols = xs % self.w
        A = self.A[ya:yb][:, cols]
        c = np.array(color, np.float32) / 255.0
        P = self.P[ya:yb][:, cols] + c * (k * A)[..., None]
        self.P[ya:yb, cols] = np.minimum(P, A[..., None])

    def texture(self, x, y, w, h, amount, rnd, cell=6):
        """Variación de tono tipo concreto / metal sobre lo ya pintado."""
        x, y, w, h = int(x), int(y), int(w), int(h)
        ya, yb = max(0, y), min(self.h, y + h)
        if yb <= ya or w <= 0:
            return
        n = noise(w, yb - ya, cell, rnd, 3) - 0.5
        cols = np.arange(x, x + w) % self.w
        self.P[ya:yb, cols] *= (1 + n * amount)[..., None]

    def haze(self, color, k):
        c = np.array(color, np.float32) / 255.0
        self.P = self.P * (1 - k) + c * k * self.A[..., None]

    def vfog(self, y0, y1, color, amax, power=1.5):
        ys = np.arange(max(0, int(y0)), self.h)
        if len(ys) == 0:
            return
        t = np.clip((ys - y0) / max(1, y1 - y0), 0, 1) ** power * amax
        self.blend(int(ys[0]), 0, np.repeat(t[:, None], self.w, axis=1).astype(np.float32), color)

    def image(self, rnd):
        A = self.A[..., None]
        col = np.where(A > 1e-4, self.P / np.maximum(A, 1e-4), 0)
        # Tramado muy leve para que los degradados no formen bandas
        col = col + (np.random.default_rng(rnd.randrange(1 << 30)).random(col.shape) - 0.5) / 255.0
        out = np.concatenate([col, A], axis=2)
        return Image.fromarray(np.clip(out * 255 + 0.5, 0, 255).astype(np.uint8), "RGBA")


def noise(w, h, cell, rnd, octaves=4):
    """Ruido de valor fractal que envuelve en X."""
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


# --- capa 0: cielo ----------------------------------------------------------------

def sky(rnd):
    cv = Canvas(SKY_W)
    stops = [(0, rgb("#05081c")), (180, rgb("#0c1238")), (330, rgb("#1e1a58")),
             (420, rgb("#4a2280")), (470, rgb("#8a2ea0")), (H, rgb("#a8409c"))]
    col = np.zeros((H, 3), np.float32)
    for y in range(H):
        for (ya, ca), (yb, cb) in zip(stops, stops[1:]):
            if ya <= y <= yb:
                t = (y - ya) / (yb - ya)
                t = t * t * (3 - 2 * t)
                col[y] = mix(ca, cb, t)
                break
    cv.blend(0, 0, np.ones((H, SKY_W), np.float32), np.repeat(col[:, None, :], SKY_W, axis=1))
    # Estrellas escasas (la contaminación lumínica tapa casi todas)
    for _ in range(70):
        x, y = rnd.uniform(0, SKY_W), rnd.uniform(0, 260)
        cv.disc(x, y, rnd.uniform(0.4, 0.9), rgb("#e8e8ff"), rnd.uniform(0.3, 0.9) * (1 - y / 300))

    # Luna gigante y nítida
    mx, my, mr = 850, 175, 118
    cv.glow(mx, my, mr * 2.6, rgb("#6a70c0"), 0.28)
    cv.glow(mx, my, mr * 1.5, rgb("#b8bce8"), 0.22)
    xs, ys = cv._field(mx - mr - 2, my - mr - 2, mx + mr + 2, my + mr + 2)
    dx = xs[None, :] + 0.5 - mx
    dy = ys[:, None] + 0.5 - my
    d = np.hypot(dx, dy)
    cover = np.clip(mr + 0.5 - d, 0, 1)
    nz = np.sqrt(np.clip(1 - (d / mr) ** 2, 0, 1))
    # Luz desde abajo a la izquierda (la ciudad) y sombreado esférico suave
    lit = np.clip(0.55 + 0.45 * (nz * 0.8 + (-dx / mr) * 0.25 + (dy / mr) * 0.15), 0.35, 1.0)
    maria = noise(len(xs), len(ys), 40, rnd, 5)
    craters = noise(len(xs), len(ys), 10, rnd, 3)
    tone = lit * (1 - 0.28 * np.clip((maria - 0.48) * 4, 0, 1)) * (1 - 0.12 * np.clip((craters - 0.6) * 5, 0, 1))
    base = np.array(rgb("#e6e4f2"), np.float32)
    colors = base * tone[..., None]
    colors = colors * (1 - 0.15 * (1 - nz))[..., None] + np.array(rgb("#b8a8e0"), np.float32) * (0.15 * (1 - nz))[..., None]
    cv.blend(int(ys[0]), int(xs[0]), cover.astype(np.float32), colors)

    # Nubes con sombras suaves: iluminadas desde abajo por la ciudad (rosa)
    # y con el borde superior frío; algunas jirones pasan delante de la luna
    for band_y, band_h, cell, thr, dens, lit_col, dark_col in (
            (40, 200, 160, 0.46, 0.7, rgb("#5a4a98"), rgb("#10142e")),
            (230, 190, 180, 0.44, 0.85, rgb("#c0609c"), rgb("#1c1846"))):
        n = noise(SKY_W, H, cell, rnd, 6)
        ys_ = np.arange(H)[:, None]
        band = np.clip(1 - np.abs(ys_ - band_y - band_h / 2) / (band_h / 2), 0, 1)
        a = np.clip((n - thr) / 0.16, 0, 1) * band * dens
        # Sombra: comparar con el ruido un poco más arriba (la luz viene de abajo)
        up = np.roll(n, 6, axis=0)
        shade = np.clip((n - up) * 7 + 0.5, 0, 1)
        vert = np.clip((ys_ - band_y) / band_h, 0, 1)
        t = np.clip(shade * 0.6 + vert * 0.6, 0, 1)
        colors = np.array(dark_col, np.float32) * (1 - t[..., None]) + np.array(lit_col, np.float32) * t[..., None]
        cv.blend(0, 0, a.astype(np.float32), colors)
    return cv


# --- edificios --------------------------------------------------------------------

def tiers_for(x, w, top, rnd, setback_p):
    tiers = [(x, w, top)]
    if w > 45 and rnd.random() < setback_p:
        inset = rnd.randint(6, max(6, w // 5))
        tiers.append((x + inset, w - 2 * inset, top - rnd.randint(24, 80)))
        if w > 80 and rnd.random() < 0.45:
            inset2 = inset + rnd.randint(6, max(6, w // 6))
            tiers.append((x + inset2, w - 2 * inset2, tiers[-1][2] - rnd.randint(18, 50)))
    return tiers


def crown(cv, tx, tw, tt, rnd, metal):
    """Remate de metal cepillado: aguja o antena con luz de aviación."""
    r = rnd.random()
    cx = tx + tw / 2
    if r < 0.15:
        h = rnd.randint(20, 50)
        for i in range(h):
            half = min(tw / 2 - 2, 9) * (1 - i / h) ** 1.4
            if half < 0.6:
                break
            shade = scale(metal, 0.8 + 0.4 * rnd.random())
            cv.rect(cx - half, tt - i - 1, half * 2, 1, shade)
        cv.seg(cx, tt - h, cx, tt - h - 18, 1.2, metal)
        top = tt - h - 18
    elif r < 0.65:
        ax = tx + rnd.uniform(4, max(5, tw - 4))
        h = rnd.randint(20, 60)
        cv.seg(ax, tt, ax, tt - h, 1.4, scale(metal, 0.8))
        cv.seg(ax - 4, tt - h * 0.6, ax + 4, tt - h * 0.6, 1, scale(metal, 0.8))
        cx, top = ax, tt - h
    else:
        return
    cv.glow(cx, top, 12, AVIATION, 0.45)
    cv.disc(cx, top, 1.5, AVIATION)


def glass_tower(cv, x, w, top, rnd, meta_windows=None):
    """Torre corporativa de cristal oscuro: cara con reflejo del cielo y
    montantes, cara lateral en sombra, pisos encendidos y lluvia resbalando."""
    tiers = tiers_for(x, w, top, rnd, 0.55)
    palette = rnd.choice([WARM, COOL, COOL, LED])
    lit_p = rnd.uniform(0.08, 0.3)
    mw = rnd.choice([6, 7, 9])         # separación de montantes
    fh = rnd.choice([9, 10, 12])       # altura de piso
    glass_top, glass_bot = rgb("#0e1330"), rgb("#1c1a46")
    refl = rgb("#7a6ad0")
    metal = rgb("#565c7a")
    for tx, tw, tt in tiers:
        side = max(4, int(tw * 0.2))
        face = tw - side
        hgt = H - tt
        cv.vgrad(tx, tt, face, hgt, glass_top, glass_bot)
        cv.vgrad(tx + face, tt, side, hgt, scale(glass_top, 0.6), scale(glass_bot, 0.55))
        # Reflejo diagonal del cielo en el cristal
        xs = np.arange(face)[None, :]
        ys = np.arange(hgt)[:, None]
        off = rnd.uniform(-face, face)
        band = np.exp(-(((xs - ys * 0.45 - off) / max(8, face * 0.35)) ** 2)) * 0.22
        cv.blend(tt, tx, band.astype(np.float32), refl)
        # Pisos y montantes
        for fy in range(tt + fh, H, fh):
            cv.rect(tx, fy, face, 1, rgb("#070914"), 0.55)
            cv.rect(tx, fy + 1, face, 1, rgb("#3a3a70"), 0.25)
        for mx in range(tx + mw, tx + face, mw):
            cv.rect(mx, tt, 1, hgt, rgb("#4a5690"), 0.22)
        # Oficinas encendidas por pisos
        for fy in range(tt + fh + 2, HZ + fh * 4, fh):
            state = rnd.random()
            p = lit_p * (0.1 if state < 0.25 else 3.2 if state > 0.9 else 1.0)
            for cx in range(tx + 1, tx + face - mw + 1, mw):
                if rnd.random() < p:
                    c = rnd.choice(palette)
                    cv.vgrad(cx + 1, fy, mw - 2, fh - 3, scale(c, 1.0), scale(c, 0.72))
                    if meta_windows is not None and fy < HZ - 60 and rnd.random() < 0.25:
                        meta_windows.append((cx + 1, fy, mw - 2, fh - 3))
        # Lluvia resbalando en finos hilos por el cristal
        for _ in range(int(face * hgt / 900)):
            rx = tx + rnd.uniform(2, face - 2)
            ry = tt + rnd.uniform(0, hgt * 0.8)
            length = rnd.uniform(20, 90)
            pts = [(rx + math.sin(i * 0.35 + rx) * 0.8, ry + i * 3) for i in range(int(length / 3))]
            cv.poly(pts, 0.7, rgb("#c8d0ff"), rnd.uniform(0.12, 0.28))
            if pts:
                cv.disc(pts[-1][0], pts[-1][1] + 1, 1.1, rgb("#e0e6ff"), 0.4)
        # Aristas iluminadas
        cv.rect(tx, tt, 1, hgt, rgb("#8a7ad8"), 0.55)
        cv.rect(tx, tt, tw, 2, scale(metal, 1.3))
        # Metal cepillado en la corona del tramo
        cv.rect(tx, tt - 4, tw, 4, metal)
        cv.texture(tx, tt - 4, tw, 4, 0.5, rnd, cell=2)
    tx, tw, tt = tiers[-1]
    crown(cv, tx, tw, tt - 4, rnd, metal)
    return tiers


def far_silhouette(cv, x, w, top, rnd, face, lit_p):
    tiers = tiers_for(x, w, top, rnd, 0.5)
    for tx, tw, tt in tiers:
        side = max(2, int(tw * 0.22))
        cv.vgrad(tx, tt, tw - side, H - tt, face, scale(face, 1.25))
        cv.vgrad(tx + tw - side, tt, side, H - tt, scale(face, 0.75), scale(face, 0.9))
        pal = rnd.choice([WARM, COOL])
        for fy in range(tt + 4, HZ + 20, 4):
            for fx in range(tx + 2, tx + tw - side - 1, 3):
                if rnd.random() < lit_p:
                    cv.rect(fx, fy, 1, 1, rnd.choice(pal), rnd.uniform(0.5, 1.0))
    tx, tw, tt = tiers[-1]
    crown(cv, tx, tw, tt, rnd, scale(face, 1.4))


def far_city(rnd):
    cv = Canvas(CITY_W)
    for face, heights, widths, lit_p, fog, gap in (
            (rgb("#221f4c"), (260, 470), (30, 80), 0.1, 0.45, (0, 24)),
            (rgb("#1a1840"), (220, 380), (36, 90), 0.16, 0.0, (6, 40))):
        x = 0
        while x < CITY_W:
            w = rnd.randint(*widths)
            far_silhouette(cv, x, w, H - rnd.randint(*heights), rnd, face, lit_p)
            x += w + rnd.randint(*gap)
        if fog:
            cv.haze(HAZE, 0.3)
            cv.vfog(200, H, FOG, fog)
    cv.haze(HAZE, 0.28)
    cv.vfog(260, 620, FOG, 0.7, power=1.3)
    return cv


def billboard(cv, x, y, w, h, rnd):
    """Pantalla publicitaria con degradado, formas y halo que ilumina el entorno."""
    c1, c2 = rnd.sample(NEON, 2)
    cv.rect(x - 3, y - 3, w + 6, h + 6, rgb("#0a0a14"))
    cv.vgrad(x, y, w, h, c1, c2)
    # Silueta de una prótesis (brazo) y barras de texto
    cx = x + w * 0.3
    cv.seg(cx, y + h * 0.2, cx + w * 0.12, y + h * 0.55, 3, rgb("#120a1a"), 0.7)
    cv.seg(cx + w * 0.12, y + h * 0.55, cx + w * 0.02, y + h * 0.85, 2.5, rgb("#120a1a"), 0.7)
    cv.disc(cx + w * 0.12, y + h * 0.55, 3, rgb("#120a1a"), 0.7)
    for i, row in enumerate(range(int(y + h * 0.25), int(y + h * 0.8), 6)):
        cv.rect(x + w * 0.55, row, w * (0.38 - 0.08 * (i % 2)), 2, rgb("#fff4ff"), 0.8)
    for sy in range(int(y), int(y + h), 2):      # líneas de barrido de la pantalla
        cv.rect(x, sy, w, 1, rgb("#000000"), 0.12)
    avg = mix(c1, c2, 0.5)
    cv.glow(x + w / 2, y + h / 2, max(w, h) * 1.3, avg, 0.3)
    cv.light(x + w / 2, y + h / 2, max(w, h) * 2.2, avg, 0.35)


def midfar_city(rnd, meta):
    cv = Canvas(CITY_W)
    x = rnd.randint(0, 20)
    towers = []
    while x < CITY_W:
        w = rnd.randint(54, 120)
        top = H - rnd.randint(260, 460)
        towers.append((x, w, top, glass_tower(cv, x, w, top, rnd, meta["windows"])))
        x += w + rnd.randint(30, 110)
    cv.haze(HAZE, 0.18)
    for x, w, top, tiers in towers:
        if rnd.random() < 0.2:
            col = rnd.choice(LED)
            tx, tw, tt = tiers[-1]
            cv.rect(tx, tt, 2, H - tt, col, 0.9)
            cv.glow(tx, (tt + HZ) / 2, 40, col, 0.12)
        if w >= 80 and rnd.random() < 0.35 and top < 330:
            billboard(cv, x + 10, top + rnd.randint(30, 70), rnd.randint(40, w - 36), rnd.randint(36, 60), rnd)
    cv.vfog(330, H, FOG, 0.6)
    return cv


def window_grid(cv, x, w, tt, rnd, palette):
    """Ventanas empotradas en concreto: marco, vidrio encendido o reflejando,
    alféizar claro y manchas de lluvia debajo."""
    ww, wh, sx, sy = 7, 10, 14, 19
    lit_p = rnd.uniform(0.15, 0.4)
    for fy in range(tt + 12, HZ + 40, sy):
        for fx in range(x + 7, x + w - ww - 5, sx):
            cv.rect(fx - 1, fy - 1, ww + 2, wh + 2, rgb("#0a0810"))
            if rnd.random() < lit_p:
                c = rnd.choice(palette)
                cv.vgrad(fx, fy, ww, wh, c, scale(c, 0.7))
                if rnd.random() < 0.3:          # persiana
                    for by in range(fy + 1, fy + wh, 2):
                        cv.rect(fx, by, ww, 1, rgb("#2a1a10"), 0.35)
            else:
                cv.vgrad(fx, fy, ww, wh, rgb("#262a50"), rgb("#12142a"))
                cv.seg(fx + 1, fy + wh - 2, fx + ww - 2, fy + 1, 1, rgb("#6a6aa8"), 0.35)
            cv.rect(fx - 1, fy + wh + 1, ww + 2, 1, rgb("#4a4658"))
            if rnd.random() < 0.3:
                cv.rect(fx + rnd.randint(0, ww - 1), fy + wh + 2, 1, rnd.randint(8, 22), rgb("#08060c"), 0.3)


def fire_escape(cv, x, tt, w, rnd):
    dark = rgb("#07050c")
    for fy in range(tt + 20, HZ + 20, 38):
        cv.rect(x, fy, w, 2, dark)
        cv.seg(x, fy - 9, x + w, fy - 9, 0.8, dark)
        for rx in range(x, x + w + 1, 6):
            cv.seg(rx, fy - 9, rx, fy, 0.7, dark)
        cv.seg(x + 3, fy + 36, x + w - 4, fy + 2, 1.2, dark)


def vent(cv, x, tt, rnd, meta_vents):
    """Conducto de ventilación en la azotea con humo denso que sube."""
    metal = rgb("#3a3a4e")
    cv.rect(x, tt - 16, 7, 16, metal)
    cv.rect(x - 2, tt - 19, 11, 3, scale(metal, 1.3))
    cv.rect(x, tt - 16, 2, 16, scale(metal, 1.5), 0.6)
    # Penacho de humo estático (el animado lo agrega city_life.gd)
    for i in range(10):
        t = i / 9
        cv.glow(x + 3.5 + math.sin(t * 3 + x) * 6 + t * 10, tt - 22 - t * 70, 8 + t * 16,
                rgb("#8a7a9a"), 0.22 * (1 - t))
    meta_vents.append((x + 3.5, tt - 20))


def neon_sign(cv, x, y, h, rnd):
    """Letrero vertical: caja oscura con glifos de neón en trazos finos."""
    col = rnd.choice(NEON)
    cv.rect(x - 2, y - 2, 14, h + 4, rgb("#0c0810"))
    cv.rect(x, y, 10, h, scale(col, 0.18))
    gy = y + 4
    while gy + 12 < y + h:
        for _ in range(rnd.randint(2, 4)):
            ax, ay = x + 2 + rnd.randint(0, 6), gy + rnd.randint(0, 9)
            bx, by = x + 2 + rnd.randint(0, 6), gy + rnd.randint(0, 9)
            cv.seg(ax, ay, bx, by, 1.2, col)
        gy += 14
    cv.glow(x + 5, y + h / 2, h * 0.7, col, 0.25)
    cv.light(x + 5, y + h / 2, h * 0.9, col, 0.5)


def projector(cv, cx, tt):
    """Proyector industrial de diseño angular y metálico (el anillo LED y el
    haz los dibuja effects/hologram_ads.gd)."""
    dark = rgb("#16141f")
    metal = rgb("#5a6078")
    hi = rgb("#9aa2bc")
    # Base trapezoidal
    for i in range(10):
        half = 22 - i * 0.8
        cv.rect(cx - half, tt - 1 - i, half * 2, 1, dark if i % 3 else scale(metal, 0.7))
    # Carcasa angular y cabezal
    cv.seg(cx - 14, tt - 10, cx - 8, tt - 22, 3, metal)
    cv.seg(cx + 14, tt - 10, cx + 8, tt - 22, 3, metal)
    cv.rect(cx - 9, tt - 26, 18, 6, dark)
    cv.rect(cx - 9, tt - 26, 18, 1, hi)
    cv.rect(cx - 6, tt - 29, 12, 3, metal)
    cv.rect(cx - 6, tt - 29, 12, 1, hi)
    cv.disc(cx - 16, tt - 5, 1.2, AVIATION)


def mid_city(rnd, meta):
    cv = Canvas(CITY_W)
    blocks = []
    x = rnd.randint(0, 30)
    while x < CITY_W:
        w = rnd.randint(100, 190)
        top = H - rnd.randint(300, 450)
        tiers = tiers_for(x, w, top, rnd, 0.25)
        blocks.append((x, w, top, tiers))
        x += w + rnd.randint(40, 120)
    concrete = rgb("#1e1a2a")
    for x, w, top, tiers in blocks:
        pal = rnd.choice([WARM, WARM, COOL, LED])
        for tx, tw, tt in tiers:
            side = max(8, int(tw * 0.16))
            cv.vgrad(tx, tt, tw - side, H - tt, concrete, scale(concrete, 1.25))
            cv.vgrad(tx + tw - side, tt, side, H - tt, scale(concrete, 0.6), scale(concrete, 0.75))
            cv.texture(tx, tt, tw, H - tt, 0.35, rnd, cell=8)
            window_grid(cv, tx, tw - side, tt, rnd, pal)
            cv.rect(tx, tt, tw, 3, rgb("#3a3450"))          # pretil
            cv.rect(tx, tt, 1, H - tt, rgb("#6a5a90"), 0.5)
    cv.haze(HAZE, 0.1)
    for x, w, top, tiers in blocks:
        tx, tw, tt = tiers[-1]
        for _ in range(rnd.randint(2, 6)):                    # aires acondicionados
            ax, ay = x + rnd.randint(8, w - 20), top + rnd.randint(20, 160)
            cv.rect(ax, ay, 9, 6, rgb("#3e3a4c"))
            for gx in range(ax + 1, ax + 9, 2):
                cv.rect(gx, ay + 1, 1, 4, rgb("#1a1824"))
            cv.rect(ax + 4, ay + 6, 1, rnd.randint(6, 18), rgb("#0a0810"), 0.35)
        if rnd.random() < 0.55:
            fire_escape(cv, x + rnd.randint(10, max(10, w - 50)), top, 36, rnd)
        if rnd.random() < 0.6:
            vent(cv, tx + rnd.randint(6, max(6, tw - 20)), tt, rnd, meta["vents"])
        if rnd.random() < 0.6:
            neon_sign(cv, x + w - 6, top + rnd.randint(30, 90), rnd.randint(50, 100), rnd)
        if rnd.random() < 0.2:
            billboard(cv, x + 12, top + rnd.randint(25, 70), min(w - 30, 80), rnd.randint(30, 46), rnd)
    # Cuatro proyectores repartidos a lo largo de la capa (uno por cuarto),
    # en la azotea apta más cercana a cada punto; el holograma flota ~55 px
    # del juego sobre el proyector, así que la azotea no puede estar muy alta
    fits = [b for b in blocks if b[3][-1][1] >= 50 and 210 <= b[3][-1][2] <= 350]
    for target in (CITY_W * (k + 0.5) / 4 for k in range(4)):
        free = [b[3][-1] for b in fits
                if all(abs(b[3][-1][0] + b[3][-1][1] // 2 - p[0]) >= 330 for p in meta["projectors"])]
        if not free:
            continue
        tx, tw, tt = min(free, key=lambda t: abs(t[0] + t[1] / 2 - target))
        cx = tx + tw // 2
        projector(cv, cx, tt)
        meta["projectors"].append((cx, tt - 29))
    cv.vfog(375, H, FOG_LOW, 0.5)
    return cv


def water_tank(cv, x, base, dark, rim):
    cv.rect(x, base - 36, 27, 24, dark)
    for sx in range(x + 3, x + 27, 4):                        # duelas
        cv.rect(sx, base - 36, 1, 24, scale(dark, 1.6), 0.5)
    for hy in (base - 30, base - 21):                          # aros
        cv.rect(x, hy, 27, 1, scale(dark, 2.2), 0.6)
    for i in range(10):                                        # techo cónico
        half = 14 - i * 1.3
        cv.rect(x + 13.5 - half, base - 37 - i, half * 2, 1, dark)
    cv.rect(x, base - 36, 27, 1, rim, 0.8)
    for lx in (x + 3, x + 23):                                 # patas
        cv.seg(lx, base - 12, lx, base, 1.5, dark)
    cv.seg(x + 3, base, x + 23, base - 12, 1, dark)
    cv.seg(x + 3, base - 12, x + 23, base, 1, dark)


def near_city(rnd):
    cv = Canvas(CITY_W)
    dark = rgb("#0b0912")
    rims = [rgb("#b050b0"), rgb("#50a0d0"), rgb("#d06080")]
    roofs = []
    x = 0
    while x < CITY_W:
        w = rnd.randint(110, 270)
        top = rnd.randint(378, 444)
        rim = rnd.choice(rims)
        cv.vgrad(x, top, w, H - top, rgb("#120f1c"), dark)
        cv.rect(x, top, w, 2, rim, 0.9)
        cv.rect(x, top + 2, w, 3, scale(rim, 0.35), 0.5)          # brillo mojado
        cv.rect(x, top, 1, H - top, rim, 0.45)
        for _ in range(rnd.randint(1, 5)):                        # charcos que reflejan
            px_ = x + rnd.randint(5, w - 30)
            cv.rect(px_, top + 1, rnd.randint(10, 26), 1, rnd.choice(NEON), 0.5)
        for _ in range(rnd.randint(0, 3)):
            wx, wy = x + rnd.randint(10, w - 20), top + rnd.randint(20, 80)
            c = rnd.choice(WARM)
            cv.vgrad(wx, wy, 8, 11, c, scale(c, 0.7), 0.85)
            cv.glow(wx + 4, wy + 5, 22, c, 0.12)
        item = rnd.random()
        if item < 0.35:
            water_tank(cv, x + rnd.randint(10, w - 40), top, dark, rim)
        elif item < 0.6:
            bx, bh = x + rnd.randint(10, max(10, w - 100)), rnd.randint(40, 66)
            for i in range(0, 91, 15):                             # armazón de cartel
                cv.seg(bx + i, top, bx + i, top - bh, 1.5, dark)
            cv.rect(bx, top - bh, 91, 4, dark)
            cv.seg(bx, top, bx + 40, top - bh, 1, dark)
            cv.seg(bx + 50, top - bh, bx + 90, top, 1, dark)
            cv.glow(bx + 45, top - bh - 6, 70, rnd.choice(NEON), 0.2)
        elif item < 0.85:
            cx = x + rnd.randint(10, w - 60)
            cv.rect(cx, top - 27, 36, 27, dark)                      # caseta de escalera
            cv.rect(cx, top - 27, 36, 2, rim, 0.8)
            cv.vgrad(cx + 12, top - 19, 9, 17, rgb("#ffcf7a"), rgb("#b87a3a"), 0.8)
            cv.glow(cx + 16, top - 10, 30, rgb("#ffcf7a"), 0.1)
            cv.seg(cx + 42, top - 30, cx + 42, top, 1.5, dark)       # antena parabólica
            cv.disc(cx + 46, top - 32, 6, dark)
            cv.seg(cx + 46, top - 32, cx + 52, top - 38, 1, dark)
        roofs.append((x, w, top))
        x += w + rnd.randint(80, 220)
    # Tendido eléctrico con comba entre postes
    poles = [(rx + 6, rt) for rx, rw, rt in roofs[::2]]
    poles.append((poles[0][0] + CITY_W, poles[0][1]))
    for (x0, t0), (x1, t1) in zip(poles, poles[1:]):
        cv.rect(x0, t0 - 78, 3, 78, dark)
        cv.rect(x0 - 8, t0 - 72, 19, 2, dark)
        for k in (-7, 9):
            pts = []
            for i in range(0, 41):
                t = i / 40
                pts.append((x0 + k + (x1 - x0) * t, (t0 - 72) + (t1 - t0) * t + 30 * math.sin(math.pi * t)))
            cv.poly(pts, 1.1, rgb("#05040a"))
    cv.vfog(450, H, FOG_LOW, 0.3)
    return cv


# --- salida -----------------------------------------------------------------------

def save(img, name):
    img.save(OUT_DIR / name, optimize=True)
    print(f"Guardado {OUT_DIR / name} {img.size}")


def write_meta(meta):
    def fmt(items):
        return ",\n\t".join("[" + ", ".join(f"{v / S:.2f}" for v in it) + "]" for it in items)
    text = (
        "## Generado por tools/generate_city.py: no editar a mano.\n"
        "## Posiciones en píxeles del juego, relativas a la capa.\n\n"
        "## Proyectores de hologramas en bg_3_mid: [x, y del cabezal]\n"
        f"const PROJECTORS := [\n\t{fmt(meta['projectors'])},\n]\n\n"
        "## Ventanas que se apagan y encienden en bg_2_midfar: [x, y, ancho, alto]\n"
        f"const WINDOWS := [\n\t{fmt(meta['windows'])},\n]\n\n"
        "## Conductos de ventilación que echan humo en bg_3_mid: [x, y]\n"
        f"const VENTS := [\n\t{fmt(meta['vents'])},\n]\n"
    )
    path = OUT_DIR / "city_meta.gd"
    path.write_text(text)
    print(f"Guardado {path} ({len(meta['projectors'])} proyectores, "
          f"{len(meta['windows'])} ventanas, {len(meta['vents'])} conductos)")


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    meta = {"projectors": [], "windows": [], "vents": []}
    save(sky(random.Random(21)).image(random.Random(1)), "bg_0_sky.png")
    save(far_city(random.Random(33)).image(random.Random(2)), "bg_1_far.png")
    save(midfar_city(random.Random(52), meta).image(random.Random(3)), "bg_2_midfar.png")
    save(mid_city(random.Random(47), meta).image(random.Random(4)), "bg_3_mid.png")
    save(near_city(random.Random(61)).image(random.Random(5)), "bg_4_near.png")
    write_meta(meta)


if __name__ == "__main__":
    main()
