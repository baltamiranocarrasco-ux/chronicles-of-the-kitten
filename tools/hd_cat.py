"""Gato en alta resolución (ilustración digital, 96x96 por cuadro = 3x el
pixel art del juego), mirando a la derecha.

Mismas poses y animaciones que el gato en pixel art (tools/cyber_cat.py):
las coordenadas de las poses están en "píxeles del juego" (cuadro de 32) y
se dibujan con el triple de detalle, con antialias y sombreado:
  - pelaje negro con luz de borde fría del cielo arriba, reflejo del neón a
    los lados y sombra abajo; contorno oscuro fino
  - pelo despeinado (mechones en el lomo) y manchas de suciedad
  - lente cibernética roja (el único ojo de perfil) con aro de metal; los
    dos ojos se ven de frente
  - tira de fibra óptica en el lomo (la barra de energía)

Colores clave que el juego reconoce en la hoja (no cambiarlos sin actualizar
effects/spine_meter.gd): SPINE_KEY / SPINE_NECK y LENS_KEY. Se pintan como
píxeles exactos, sin antialias.
"""

import math

import numpy as np
from PIL import Image, ImageDraw

S = 3
N = 32 * S

FUR = np.array((30, 28, 36), np.float32)
FUR_FAR = np.array((18, 17, 23), np.float32)
FUR_HI = np.array((48, 46, 58), np.float32)
BELLY = np.array((22, 21, 27), np.float32)
EAR_IN = np.array((98, 58, 74), np.float32)
OUTLINE = np.array((8, 6, 12), np.float32)
RIM_TOP = np.array((150, 140, 230), np.float32)     # cielo
RIM_LEFT = np.array((90, 210, 240), np.float32)     # neón cian
RIM_RIGHT = np.array((240, 80, 200), np.float32)    # neón magenta
DIRT = np.array((72, 58, 44), np.float32)
NOSE = (130, 80, 92)
METAL = (170, 178, 196)
EYE = (70, 236, 128)
PUPIL = (8, 30, 16)
MOUTH = (90, 20, 28)
FANG = (230, 228, 220)
ZZZ = (150, 230, 255)
SPINE_KEY = (64, 224, 224)
SPINE_NECK = (66, 226, 226)
LENS_KEY = (178, 24, 36)

_YY, _XX = np.mgrid[0:N, 0:N].astype(np.float32) + 0.5


# --- coberturas con antialias (coordenadas en píxeles del juego) --------------

def ellipse(cx, cy, rx, ry):
    d = np.hypot((_XX / S - cx) / rx, (_YY / S - cy) / ry)
    return np.clip((1 - d) * min(rx, ry) * S + 0.5, 0, 1)


def capsule(ax, ay, bx, by, r0, r1=None):
    r1 = r0 if r1 is None else r1
    px, py = _XX / S, _YY / S
    dx, dy = bx - ax, by - ay
    L = dx * dx + dy * dy
    t = np.clip(((px - ax) * dx + (py - ay) * dy) / L, 0, 1) if L > 0 else np.zeros_like(px)
    d = np.hypot(px - (ax + t * dx), py - (ay + t * dy))
    r = r0 + (r1 - r0) * t
    return np.clip((r - d) * S + 0.5, 0, 1)


def chain(pts, r0, r1):
    cov = np.zeros((N, N), np.float32)
    n = len(pts) - 1
    for i, (a, b) in enumerate(zip(pts, pts[1:])):
        ra = r0 + (r1 - r0) * i / n
        rb = r0 + (r1 - r0) * (i + 1) / n
        cov = np.maximum(cov, capsule(a[0], a[1], b[0], b[1], ra, rb))
    return cov


def polygon(pts):
    k = 4
    img = Image.new("L", (N * k, N * k), 0)
    ImageDraw.Draw(img).polygon([(x * S * k, y * S * k) for x, y in pts], fill=255)
    return np.asarray(img.resize((N, N), Image.BOX), np.float32) / 255.0


def smooth_curve(pts, steps=6):
    """Curva suave (Catmull-Rom) por los puntos de control de la cola."""
    if len(pts) < 3:
        return pts
    p = [pts[0]] + list(pts) + [pts[-1]]
    out = []
    for i in range(1, len(p) - 2):
        p0, p1, p2, p3 = p[i - 1], p[i], p[i + 1], p[i + 2]
        for s in range(steps):
            t = s / steps
            out.append(tuple(0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t
                                    + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t * t
                                    + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t ** 3) for j in range(2)))
    out.append(pts[-1])
    return out


def _shift(a, dx, dy):
    out = np.zeros_like(a)
    ys = slice(max(0, dy), N + min(0, dy))
    yd = slice(max(0, -dy), N + min(0, -dy))
    xs = slice(max(0, dx), N + min(0, dx))
    xd = slice(max(0, -dx), N + min(0, -dx))
    out[ys, xs] = a[yd, xd]
    return out


def _hash(x, y, salt=0):
    h = (int(x) * 73856093) ^ (int(y) * 19349663) ^ (salt * 83492791)
    h ^= h >> 13
    return (h * 1274126177) & 0xFFFF


# --- cuadro ------------------------------------------------------------------

class Frame:
    """Acumula piezas de pelaje (sombreadas juntas) y detalles encima."""

    def __init__(self, anchor=(0.0, 0.0)):
        self.col = np.zeros((N, N, 3), np.float32)
        self.a = np.zeros((N, N), np.float32)
        self.fur = np.zeros((N, N), np.float32)
        self.anchor = anchor           # para que suciedad y mechones sigan al cuerpo
        self.top = []                  # detalles sin sombreado: (cov, color)
        self.keys = []                 # píxeles de color clave exacto: (mask, color)

    def part(self, cov, color):
        c = np.asarray(color, np.float32)
        a = cov[..., None]
        self.col = c * a + self.col * (1 - a)
        self.a = cov + self.a * (1 - cov)
        self.fur = np.maximum(self.fur, cov)

    def detail(self, cov, color, alpha=1.0):
        self.top.append((cov * alpha, np.asarray(color, np.float32)))

    def key(self, cov, color):
        self.keys.append((cov > 0.5, color))

    def render(self):
        M = self.fur
        col = self.col.copy()
        # Luz: borde superior frío (cielo), neón a los lados, sombra abajo
        up = M * (1 - _shift(M, 0, 4))
        left = M * (1 - _shift(M, 4, 0))
        right = M * (1 - _shift(M, -4, 0))
        down = M * (1 - _shift(M, 0, -4))
        for mask, c, k in ((up, RIM_TOP, 0.3), (left, RIM_LEFT, 0.16), (right, RIM_RIGHT, 0.14)):
            col = col * (1 - (mask * k)[..., None]) + c * (mask * k)[..., None]
        col *= (1 - down * 0.35)[..., None]
        # Textura de pelo: vetas finas y manchas de suciedad fijas al cuerpo
        ax, ay = self.anchor
        rng = np.random.default_rng(7)
        streak = rng.random((N, N)).astype(np.float32)
        streak = (streak + _shift(streak, 0, 1) + _shift(streak, 0, 2)) / 3 - 0.5
        col *= (1 + streak * 0.18 * M)[..., None]
        for i in range(7):
            h = _hash(i, 3, 11)
            bx = ax + (h % 17) - 8
            by = ay + ((h >> 5) % 7) - 1
            blob = ellipse(bx, by, 1.2 + (h % 3) * 0.5, 0.9 + (h % 2) * 0.4) * M * 0.35
            col = col * (1 - blob[..., None]) + DIRT * blob[..., None]
        # Mechones despeinados en los bordes superiores del pelaje
        tufts = np.zeros((N, N), np.float32)
        ys, xs = np.nonzero(up > 0.6)
        for y, x in zip(ys[::3], xs[::3]):
            if _hash(x - ax * S, y - ay * S, 5) % 9 == 0:
                lean = ((_hash(x, y, 9) % 5) - 2) * 0.25
                tufts = np.maximum(tufts, capsule(x / S, y / S, x / S + lean, y / S - 1.3, 0.28, 0.08))
        tuft_col = FUR * 0.6 + RIM_TOP * 0.4
        col = col * (1 - tufts[..., None]) + tuft_col * tufts[..., None]
        A = np.maximum(self.a, tufts)
        # Contorno oscuro fino por fuera de la silueta
        dil = A.copy()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
            dil = np.maximum(dil, _shift(A, dx, dy))
        outline = dil * (1 - A)
        out_col = col * A[..., None] + OUTLINE * (outline * 0.95)[..., None]
        out_a = A + outline * 0.95 * (1 - A)
        out_col = np.where(out_a[..., None] > 0, out_col / np.maximum(out_a, 1e-4)[..., None], 0)
        for cov, c in self.top:
            out_col = out_col * (1 - cov[..., None]) + c * cov[..., None]
            out_a = cov + out_a * (1 - cov)
        img = np.concatenate([np.clip(out_col, 0, 255), (np.clip(out_a, 0, 1) * 255)[..., None]], axis=2)
        img = np.round(img).astype(np.uint8)
        for mask, c in self.keys:
            img[mask] = (*c, 255)
        return Image.fromarray(img, "RGBA")


# --- piezas --------------------------------------------------------------------

def leg(f, hip, foot, far=False, r=1.05):
    color = FUR_FAR if far else FUR
    f.part(capsule(hip[0], hip[1], foot[0], foot[1] - 0.3, r * 1.25, r * 0.8), color)
    f.part(ellipse(foot[0] + 0.5, foot[1] - 0.2, 1.2, 0.7), color)


def ear(f, base_l, base_r, tip, torn=False):
    f.part(polygon([base_l, tip, base_r]), FUR)
    inner = [(base_l[0] + (tip[0] - base_l[0]) * 0.3 + 0.4, base_l[1] - 0.3),
             (tip[0] + (base_l[0] + base_r[0] - 2 * tip[0]) * 0.18, tip[1] + 1.2),
             (base_r[0] - (base_r[0] - tip[0]) * 0.3 - 0.4, base_r[1] - 0.3)]
    f.part(polygon(inner), EAR_IN)
    if torn:
        # Punta mordida: muesca triangular en el borde
        notch = polygon([(tip[0] - 0.9, tip[1] + 0.2), (tip[0] + 0.4, tip[1] + 1.4), (tip[0] + 1.2, tip[1] - 0.5)])
        f.a *= 1 - notch
        f.fur *= 1 - notch


def side_head(f, hx, hy):
    f.part(ellipse(hx, hy, 5.5, 5.0), FUR)
    ear(f, (hx - 4.6, hy - 3.2), (hx - 1.2, hy - 4.6), (hx - 3.0, hy - 8.3), torn=True)
    ear(f, (hx + 0.2, hy - 4.8), (hx + 3.6, hy - 3.6), (hx + 1.9, hy - 8.6))
    f.part(ellipse(hx + 3.7, hy + 2.1, 2.6, 1.8), FUR_HI)


def lens(f, x, y, state="open"):
    """Lente cibernética de perfil (color clave) con aro metálico."""
    cx, cy = x + 1.0, y
    if state == "closed":
        f.detail(capsule(cx - 1.2, cy + 0.2, cx + 1.2, cy + 0.2, 0.25), OUTLINE)
        return
    f.detail(ellipse(cx, cy, 1.25, 1.15), METAL)
    f.detail(ellipse(cx, cy, 1.0, 0.92), (20, 10, 14))
    core = ellipse(cx, cy, 0.82, 0.78)
    if state == "half":
        core = core * (_YY / S > cy - 0.1)
        f.detail(capsule(cx - 1.3, cy - 0.2, cx + 1.3, cy - 0.2, 0.3), OUTLINE)
    f.key(core, LENS_KEY)


def spine(f, body_cov, head_cov, cols):
    """Tira de fibra óptica dos píxeles por debajo del borde del lomo.
    cols: columnas (en píxeles del juego) de la cola al cuello."""
    band = np.zeros((N, N), bool)
    neck = np.zeros((N, N), bool)
    xs = [c for c in np.arange(cols[0] * S, cols[1] * S, 1 if cols[1] > cols[0] else -1)]
    last = None
    for x in xs:
        col = body_cov[:, x]
        ys = np.nonzero(col > 0.5)[0]
        if len(ys) == 0:
            continue
        y0 = ys[0] + 2
        for y in (y0, y0 + 1):
            if head_cov[y, x] < 0.1:
                band[y, x] = True
                last = x
    if last is not None:
        neck[:, last] = band[:, last]
        band[:, last] = False
    f.keys.append((band, SPINE_KEY))
    f.keys.append((neck, SPINE_NECK))


def zzz(f, x, y):
    for (a, b) in (((0, 0), (3, 0)), ((3, 0), (0, 3)), ((0, 3), (3, 3))):
        f.detail(capsule(x + a[0], y + a[1], x + b[0], y + b[1], 0.35), ZZZ)


# --- poses ---------------------------------------------------------------------

def draw_cat(body_y=0.0, legs=((0, 0), (0, 0), (0, 0), (0, 0)),
             tail=((7, 20), (4, 17), (3, 13), (4, 10)), head_dy=0.0, eyes="open"):
    """De perfil. legs: (dx, lift) de [trasera lejana, delantera lejana,
    trasera cercana, delantera cercana]."""
    by = 21 + body_y
    hy = 14 + body_y + head_dy
    f = Frame((15, by))
    for hip_x, (dx, lift) in ((11, legs[0]), (22, legs[1])):
        leg(f, (hip_x, by + 2), (hip_x + dx, 29.5 - lift), far=True)
    f.part(chain(smooth_curve([(p[0] + 0.5, p[1] + 0.5) for p in tail]), 1.15, 0.75), FUR)
    body = ellipse(15, by, 9, 4.6)
    f.part(body, FUR)
    f.part(ellipse(16, by + 2.6, 6, 1.6), BELLY)
    head = ellipse(23.5, hy, 5.5, 5.0)
    side_head(f, 23.5, hy)
    for hip_x, (dx, lift) in ((9, legs[2]), (20, legs[3])):
        leg(f, (hip_x, by + 2), (hip_x + dx, 29.5 - lift))
    spine(f, body, head, (8, 21))
    lens(f, 25, hy, eyes)
    f.detail(ellipse(29.4, hy + 1.3, 0.7, 0.5), NOSE)
    return f.render()


def draw_lying(head_drop=0, eyes="open", breathe=0.0, zs=()):
    f = Frame((14, 26))
    f.part(chain(smooth_curve([(8, 27), (4, 28), (5, 30), (12, 30.3)]), 1.1, 0.8), FUR)
    body = ellipse(14, 26 - breathe * 0.5, 10, 3.6 + breathe * 0.5)
    f.part(body, FUR)
    f.part(ellipse(15, 28.3, 6, 1.4), BELLY)
    f.part(capsule(20, 28, 25.5, 29.3, 1.0, 0.8), FUR)
    hy = 21 + head_drop
    head = ellipse(23.5, hy, 5.0, 4.5)
    f.part(head, FUR)
    ear(f, (19.6, hy - 2.8), (22.6, hy - 4.2), (20.8, hy - 7.2), torn=True)
    ear(f, (23.8, hy - 4.3), (27.0, hy - 3.0), (25.4, hy - 7.6))
    f.part(ellipse(27, hy + 1.6, 2.6, 1.6), FUR_HI)
    spine(f, body, head, (7, 20))
    lens(f, 25, hy, eyes)
    f.detail(ellipse(29.2, hy + 1.2, 0.7, 0.5), NOSE)
    for x, y in zs:
        zzz(f, x, y)
    return f.render()


def draw_angry(peak_y=10.0, tail_top=4.0, hiss=False, hop=0.0, puff=1):
    """Lomo arqueado, patas rectas, cola y pelo erizados."""
    f = Frame((14, peak_y + 4))
    foot = 29.5 - hop
    for lx in (10.5, 21.5):
        leg(f, (lx, 20 - hop), (lx, foot), far=True)
    # Cola esponjada
    f.part(capsule(6.5, 19 - hop, 5.5, tail_top, 1.7, 1.5), FUR)
    for y in np.arange(tail_top + 1, 18 - hop, 2.2):
        f.part(capsule(5.5, y, 3.6, y - 0.8, 0.45, 0.1), FUR)
        f.part(capsule(7.0, y + 0.8, 8.9, y, 0.45, 0.1), FUR)
    body = np.zeros((N, N), np.float32)
    pts = []
    for i in range(15):
        t = i / 14
        x = 7.5 + 14 * t
        y = 20 - hop - (20 - hop - peak_y) * math.sin(math.pi * t)
        pts.append((x, y))
        body = np.maximum(body, ellipse(x, y + 1, 3.6, 3.6))
    f.part(body, FUR)
    # Pelo erizado sobre el arco
    for i, (x, y) in enumerate(pts[1:-1]):
        if puff and i % 2 == 0:
            f.part(capsule(x, y - 2.3, x - 0.3, y - 3.6 - puff * 0.7, 0.5, 0.1), FUR)
    for lx in (7.5, 18.5):
        leg(f, (lx, 20 - hop), (lx, foot))
    hx, hy = 25.5, 20 - hop
    head = ellipse(hx, hy, 5.0, 4.5)
    f.part(head, FUR)
    # Orejas aplastadas hacia atrás
    f.part(polygon([(hx - 4.2, hy - 2.0), (hx - 7.2, hy - 5.0), (hx - 2.2, hy - 3.8)]), FUR)
    f.part(polygon([(hx - 1.6, hy - 4.2), (hx - 3.6, hy - 7.0), (hx + 0.6, hy - 4.6)]), FUR)
    f.part(ellipse(hx + 3.5, hy + 1.6, 2.3, 1.6), FUR_HI)
    spine(f, body, head, (6, 21))
    # Lente muy abierta
    f.detail(ellipse(hx + 1.5, hy - 1.4, 1.45, 1.35), METAL)
    f.key(ellipse(hx + 1.5, hy - 1.4, 1.0, 0.95), LENS_KEY)
    f.detail(ellipse(hx + 5.0, hy + 0.3, 0.7, 0.5), NOSE)
    if hiss:
        f.detail(ellipse(hx + 3.6, hy + 2.3, 1.4, 1.0), MOUTH)
        f.detail(polygon([(hx + 4.2, hy + 1.6), (hx + 4.8, hy + 1.6), (hx + 4.5, hy + 3.0)]), FANG)
    return f.render()


def front_head(f, cx, cy, back=False):
    head = ellipse(cx, cy, 6.0, 5.0)
    f.part(head, FUR)
    for side in (-1, 1):
        base_out = (cx + side * 5.6, cy - 2.0)
        base_in = (cx + side * 1.8, cy - 4.4)
        tip = (cx + side * 5.2, cy - 8.4)
        if back:
            f.part(polygon([base_out, tip, base_in]), FUR)
        else:
            ear(f, base_out if side < 0 else base_in, base_in if side < 0 else base_out, tip, torn=side > 0)
    if not back:
        f.part(ellipse(cx, cy + 2.5, 2.6, 1.7), FUR_HI)
    return head


def front_eyes(f, cx, cy):
    """De frente: ojo orgánico verde (izquierda de la imagen) y lente."""
    f.detail(ellipse(cx - 2.6, cy - 0.3, 1.25, 1.35), EYE)
    f.detail(ellipse(cx - 2.6, cy - 0.3, 0.3, 1.1), PUPIL)
    f.detail(ellipse(cx - 2.9, cy - 0.8, 0.3, 0.3), (240, 255, 240))
    f.detail(ellipse(cx + 2.6, cy - 0.3, 1.3, 1.25), METAL)
    f.key(ellipse(cx + 2.6, cy - 0.3, 0.9, 0.88), LENS_KEY)
    f.detail(ellipse(cx, cy + 1.9, 0.75, 0.5), NOSE)


def front_view():
    f = Frame((16, 22))
    f.part(chain(smooth_curve([(21, 27), (24, 25), (25, 21)]), 1.0, 0.8), FUR)
    f.part(ellipse(16, 22.5, 6, 5), FUR)
    f.part(ellipse(16, 24, 3, 3), BELLY)
    for lx in (13.5, 18.5):
        leg(f, (lx, 24), (lx, 29.5))
    front_head(f, 16, 14)
    front_eyes(f, 16, 14)
    return f.render()


def back_view():
    f = Frame((16, 21))
    body = ellipse(16, 21.5, 6.5, 5.5)
    f.part(body, FUR)
    for lx in (12.5, 19.5):
        leg(f, (lx, 25), (lx, 29.5))
    head = front_head(f, 16, 13, back=True)
    band = np.zeros((N, N), bool)
    band[18 * S:26 * S, 16 * S - 1:16 * S + 1] = True
    band &= (body > 0.9) & (head < 0.1)
    neck = np.zeros((N, N), bool)
    ys = np.nonzero(band.any(axis=1))[0]
    if len(ys):
        neck[ys[0]] = band[ys[0]]
        band[ys[0]] = False
    f.keys += [(band, SPINE_KEY), (neck, SPINE_NECK)]
    f.part(chain(smooth_curve([(17, 26), (21, 25), (24, 21), (24, 16), (23, 13)]), 1.1, 0.8), FUR)
    return f.render()


def three_quarter_front():
    f = Frame((13, 22))
    leg(f, (9.5, 24), (9.5, 29.5), far=True)
    f.part(chain(smooth_curve([(8, 21), (5, 18), (4, 14), (5, 11)]), 1.1, 0.75), FUR)
    body = ellipse(13, 22, 6.5, 4.6)
    f.part(body, FUR)
    f.part(ellipse(19, 23, 4, 4.5), FUR)
    leg(f, (11.5, 25), (11.5, 29.5))
    leg(f, (17.5, 26), (17.5, 29.5), far=True)
    leg(f, (20.5, 26), (20.5, 29.5))
    head = front_head(f, 20, 14)
    spine(f, body, head, (8, 17))
    front_eyes(f, 20, 14)
    return f.render()


def three_quarter_back():
    f = Frame((17, 22))
    leg(f, (12.5, 25), (12.5, 29.5), far=True)
    leg(f, (21.5, 26), (21.5, 29.5), far=True)
    body = ellipse(17, 22, 6.5, 5)
    f.part(body, FUR)
    leg(f, (15.5, 26), (15.5, 29.5))
    leg(f, (19.5, 27), (19.5, 29.5))
    head = front_head(f, 11, 14, back=True)
    spine(f, body, head, (23, 12))
    f.part(chain(smooth_curve([(22, 24), (25, 21), (26, 16), (25, 12)]), 1.1, 0.8), FUR)
    return f.render()


def mirror(img):
    return img.transpose(Image.FLIP_LEFT_RIGHT)


# --- animaciones (mismos parámetros que el pixel art, sin redondear) -----------

def tail_wave(phase, amp=1.5):
    s = math.sin(phase)
    return ((7, 20), (4, 17), (3 + s * amp * 0.5, 13), (4 + s * amp, 10))


def idle_frames():
    frames = []
    breath = [0, 0.4, 0.8, 1, 1, 0.8, 0.4, 0]
    eyes = ["open"] * 6 + ["half", "closed"]
    for i in range(8):
        phase = i / 8 * 2 * math.pi
        frames.append(draw_cat(body_y=breath[i], head_dy=-breath[i], tail=tail_wave(phase, 2.0), eyes=eyes[i]))
    return frames


def run_frames():
    frames = []
    for i in range(8):
        phase = i / 8 * 2 * math.pi

        def lg(p):
            return (3.2 * math.sin(p), max(0.0, 2.2 * math.cos(p)))

        bob = -0.8 * max(0.0, math.sin(phase * 2 + 0.6))
        tail_end = 15 + math.sin(phase * 2) * 1.2
        frames.append(draw_cat(body_y=bob, head_dy=0.5 * max(0.0, math.cos(phase * 2)),
                               legs=(lg(phase + math.pi + 0.6), lg(phase + 0.6), lg(phase + math.pi), lg(phase)),
                               tail=((7, 19), (4, 17), (2, 16), (0, tail_end))))
    return frames


def jump_frames():
    return [
        draw_cat(body_y=-1, legs=((-3, 0), (3, 2), (-4, 0), (4, 3)), tail=((7, 19), (4, 17), (2, 14), (1, 12))),
        draw_cat(body_y=-2, legs=((-5, 2), (5, 4), (-6, 1), (6, 5)), tail=((7, 19), (4, 16), (2, 12), (2, 9))),
        draw_cat(body_y=-2, legs=((-5, 3), (5, 5), (-6, 2), (6, 6)), tail=((7, 19), (4, 15), (3, 11), (4, 8))),
        draw_cat(body_y=-2, legs=((-3, 4), (3, 5), (-4, 3), (4, 5)), tail=((7, 19), (4, 15), (4, 11), (5, 8))),
    ]


def fall_frames():
    tails = [((7, 19), (4, 14), (5, 10), (7, 7)), ((7, 19), (3, 14), (4, 10), (6, 6)),
             ((7, 19), (3, 14), (3, 9), (5, 6)), ((7, 19), (4, 14), (4, 9), (6, 7))]
    legs = [((-3, 0), (4, 1), (-2, 1), (5, 0)), ((-4, 1), (5, 0), (-3, 0), (6, 1)),
            ((-4, 0), (5, 1), (-3, 1), (6, 0)), ((-3, 1), (4, 0), (-2, 0), (5, 1))]
    return [draw_cat(body_y=-1, head_dy=1, legs=legs[i], tail=tails[i]) for i in range(4)]


def turn_frames():
    side = idle_frames()[0]
    q_front = three_quarter_front()
    q_back = three_quarter_back()
    return [side, q_front, front_view(), mirror(q_front), q_back, back_view(), mirror(q_back), mirror(side)]


def lie_frames():
    return [
        draw_cat(body_y=2, head_dy=1, tail=((7, 22), (4, 24), (2, 26), (0, 27))),
        draw_cat(body_y=3, head_dy=1, tail=((7, 23), (4, 25), (2, 27), (0, 28))),
        draw_cat(body_y=4, head_dy=1, tail=((7, 24), (4, 26), (3, 28), (1, 29))),
        draw_lying(head_drop=0),
        draw_lying(head_drop=1, eyes="half"),
        draw_lying(head_drop=2, eyes="half"),
        draw_lying(head_drop=3, eyes="closed"),
    ]


def sleep_frames():
    breath = [0, 0.3, 0.7, 1, 1, 0.7, 0.3, 0]
    z_path = [(24, 16), (25, 14), (25, 12), (26, 10), (26, 8), (27, 6), (27, 4), (28, 2)]
    return [draw_lying(head_drop=3, eyes="closed", breathe=breath[i], zs=[z_path[i]]) for i in range(8)]


def angry_frames():
    return [
        draw_angry(peak_y=14, tail_top=9, hop=2, puff=0),
        draw_angry(peak_y=12, tail_top=7, hop=3, puff=1),
        draw_angry(peak_y=11, tail_top=5, hop=1, puff=1),
        draw_angry(peak_y=9, tail_top=3, puff=1),
        draw_angry(peak_y=9, tail_top=3, puff=2),
        draw_angry(peak_y=9, tail_top=3, puff=2, hiss=True),
        draw_angry(peak_y=11, tail_top=6, puff=1),
        draw_angry(peak_y=13, tail_top=9, puff=0),
    ]


def walk_frames():
    def lg(p):
        return (2 * math.sin(p), max(0.0, 1.5 * math.cos(p)))

    right = []
    for i in range(4):
        ph = i / 4 * 2 * math.pi
        right.append(draw_cat(body_y=0.5 * abs(math.sin(ph)), head_dy=-0.5 * abs(math.sin(ph)),
                              legs=(lg(ph + math.pi), lg(ph + 1.5 * math.pi), lg(ph), lg(ph + 0.5 * math.pi)),
                              tail=tail_wave(ph, 1.0)))
    return right + [mirror(f) for f in right]


def sheet_rows():
    return [
        idle_frames(),
        run_frames(),
        jump_frames() + fall_frames(),
        turn_frames(),
        lie_frames(),
        sleep_frames(),
        angry_frames(),
        walk_frames(),
    ]
