"""Arte del gato cíborg (pixel art 32x32, mirando a la derecha).

La cabeza, el torso y las vistas de frente/espalda están dibujados a mano
como mapas de caracteres; las patas mecánicas y la cola-cable se arman como
piezas articuladas para poder animarlas.

Colores clave que el juego reconoce en la hoja (no cambiarlos sin actualizar
effects/spine_meter.gd):
  SPINE_KEY / SPINE_NECK  tira de fibra óptica del lomo (NECK marca el extremo
                          del cuello, desde donde se apagan los segmentos)
  LENS_KEY                lente del ojo cibernético (se ilumina en cian)
"""

import math

FRAME = 32
GROUND = 29  # fila de las almohadillas

# --- paleta ------------------------------------------------------------------
T = None
OUT = (10, 10, 16, 255)
FUR = (36, 36, 44, 255)
FUR_HI = (58, 58, 70, 255)
FUR_DK = (24, 24, 31, 255)
CARB = (66, 70, 82, 255)
CARB_HI = (104, 110, 124, 255)
BRASS = (205, 158, 76, 255)
BRASS_DK = (140, 102, 44, 255)
CHROME = (178, 188, 204, 255)
METAL = (92, 98, 114, 255)
METAL_HI = (150, 158, 176, 255)
METAL_DK = (52, 56, 68, 255)
PAD = (28, 22, 26, 255)
COPPER = (196, 112, 62, 255)
EYE = (70, 236, 128, 255)
PUPIL = (8, 30, 16, 255)
NOSE = (120, 70, 80, 255)
WHISKER = (150, 162, 180, 255)
CABLE = (26, 26, 32, 255)
CABLE_HI = (74, 76, 90, 255)
TIP = (120, 236, 255, 255)
MOUTH = (90, 20, 28, 255)
FANG = (235, 235, 240, 255)
ZZZ = (140, 230, 255, 255)
SPINE_KEY = (64, 224, 224, 255)
SPINE_NECK = (66, 226, 226, 255)
LENS_KEY = (178, 24, 36, 255)

PALETTE = {
    ".": T, "o": OUT, "F": FUR, "H": FUR_HI, "D": FUR_DK, "K": CARB, "k": CARB_HI,
    "B": BRASS, "b": BRASS_DK, "C": CHROME, "M": METAL, "m": METAL_HI, "n": METAL_DK,
    "c": COPPER, "E": EYE, "p": PUPIL, "N": NOSE, "L": LENS_KEY, "S": SPINE_KEY,
    "s": SPINE_NECK, "A": METAL_DK, "x": MOUTH, "f": FANG, "P": PAD, "T": TIP,
}


class Canvas:
    def __init__(self):
        self.px = {}

    def set(self, x, y, c):
        x, y = round(x), round(y)
        if c is not None and 0 <= x < FRAME and 0 <= y < FRAME:
            self.px[(x, y)] = c

    def stamp(self, rows, ox, oy, flip=False, only=None):
        """Pinta un mapa de caracteres con su esquina superior izquierda en (ox, oy)."""
        w = max(len(r) for r in rows)
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                color = PALETTE.get(ch)
                if color is None or (only and ch not in only):
                    continue
                self.set(ox + ((w - 1 - x) if flip else x), oy + y, color)

    def line(self, x0, y0, x1, y1, c, width=1):
        steps = max(abs(x1 - x0), abs(y1 - y0), 1) * 2
        for i in range(int(steps) + 1):
            t = i / steps
            x = x0 + (x1 - x0) * t
            y = y0 + (y1 - y0) * t
            for dx in range(width):
                self.set(x + dx, y, c)

    def outlined(self, keep=()):
        """Contorno automático de 1 px alrededor de la silueta."""
        out = dict(self.px)
        for (x, y) in self.px:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (x + dx, y + dy)
                if n not in self.px and 0 <= n[0] < FRAME and 0 <= n[1] < FRAME:
                    out[n] = OUT
        return out


def merge(base, top):
    base.update(top)
    return base


# --- piezas dibujadas a mano ---------------------------------------------------
# Cabeza de perfil 3/4 (mira a la derecha). Ancla: (0, 0) arriba a la izquierda.
# Oreja orgánica adelante (F), antena angulosa atrás (A/m). Ojo biológico (E/p)
# cercano y lente cibernética (L) del lado lejano, junto al puente de la nariz.
HEAD = [
    ".m......F..",
    ".Am....FF..",
    "..AAHHHHF..",
    "..FFFFFFHH.",
    ".FFEpFFLFFH",
    ".cFFFFFFFFN",
    "..DFFFFFFD.",
    "...DDDD....",
]
HEAD_BLINK = [
    ".m......F..",
    ".Am....FF..",
    "..AAHHHHF..",
    "..FFFFFFHH.",
    ".FFooFFLFFH",
    ".cFFFFFFFFN",
    "..DFFFFFFD.",
    "...DDDD....",
]
# Corriendo: antena y oreja plegadas hacia atrás
HEAD_RUN = [
    "...........",
    "mA....FF...",
    ".AAHHHHHF..",
    "..FFFFFFHH.",
    ".FFEpFFLFFH",
    ".cFFFFFFFFN",
    "..DFFFFFFD.",
    "...DDDD....",
]
# Bufando: orejas atrás, ojo muy abierto, boca abierta con colmillo
HEAD_HISS = [
    "...........",
    "mA...FF....",
    ".AAHHHHHF..",
    "..FFFFFFHH.",
    ".FFEEFFLFFH",
    ".cFFFFFFxxN",
    "..DFFFFFxf.",
    "...DDDD....",
]
HEAD_SLEEP = [
    "...........",
    ".mA....FF..",
    "..AAHHHHF..",
    "..FFFFFFHH.",
    ".FFooFFnFFH",
    ".cFFFFFFFFN",
    "..DFFFFFFD.",
    "...DDDD....",
]

# Torso esbelto (cadera a la izquierda, hombros a la derecha). Lomo con la tira
# de fibra óptica (S, y s en el extremo del cuello), placas de carbono (K/k)
# con remaches de latón (B) y el vientre recogido.
TORSO = [
    "..SSSSSSSSSs...",
    ".KkKBKKkKKBKkK.",
    "FKKKFFKKKFFKKKF",
    "FFFFFFFFFFFFFFF",
    ".FFFFDDDDDFFFF.",
    "..DD.......DD..",
]

# Vista de frente (para girar). El ojo cibernético y la antena son del lado
# izquierdo del gato, que de frente queda a la derecha de la imagen.
FRONT = [
    "...F.......m...",
    "...FF.....mA...",
    "...FHHHHHHAA...",
    "..FFFFFFFFFFF..",
    "..FEpFFFFFLFF..",
    "..FFFFFNFFFFF..",
    "...FFFFFFFFF...",
    "...cDDDDDDDc...",
    "....KkFFFkK....",
    "...KKKFFFKKK...",
    "....FFFFFFF....",
    "....FFFFFFF....",
    "....DFFFFFD....",
    "....mM...Mm....",
    "....Mn...nM....",
    "....Cn...nC....",
    "....Mn...nM....",
    "....Mn...nM....",
    "...PPP...PPP...",
]
# Vista de espalda: la tira de fibra óptica baja por la columna.
BACK = [
    "...m.......F...",
    "...Am.....FF...",
    "...AAHHHHHHF...",
    "..FFFFFFFFFFF..",
    "..FFFFFFFFFFF..",
    "...FFFFFFFFF...",
    "...cFFFsFFFc...",
    "....KkFSFkK....",
    "...KKKFSFKKK...",
    "....FFFSFFF....",
    "....FFFSFFF....",
    "....DFFSFFD....",
    "....mM.S.Mm....",
    "....Mn...nM....",
    "....Cn...nC....",
    "....Mn...nM....",
    "....Mn...nM....",
    "...PPP...PPP...",
]


# --- piezas articuladas -------------------------------------------------------

def ik_knee(root, target, a, b, bend):
    """Rodilla de una pata de 2 segmentos (a, b) de root a target. bend: +1/-1."""
    dx, dy = target[0] - root[0], target[1] - root[1]
    d = max(0.01, min(math.hypot(dx, dy), a + b - 0.01))
    ang = math.atan2(dy, dx)
    cos_k = (a * a + d * d - b * b) / (2 * a * d)
    k = math.acos(max(-1.0, min(1.0, cos_k)))
    ka = ang + bend * k
    return (root[0] + math.cos(ka) * a, root[1] + math.sin(ka) * a)


def draw_leg_pts(c, pts, near, piston=False):
    """Pata cibernética por articulaciones [cadera, rodilla, (corvejón), almohadilla]."""
    body = METAL if near else METAL_DK
    hi = METAL_HI if near else METAL
    for i, (a, b) in enumerate(zip(pts, pts[1:])):
        c.line(a[0], a[1], b[0], b[1], body if i == 0 else hi, 1)
    if near:
        c.line(pts[0][0] + 1, pts[0][1], pts[1][0] + 1, pts[1][1], body, 1)  # muslo más grueso
    if piston and near:
        c.line(pts[0][0] - 1, pts[0][1] + 1, pts[1][0] - 1, pts[1][1], BRASS)
    for j in pts[1:-1]:
        c.set(j[0], j[1], CHROME if near else METAL)
    foot = pts[-1]
    c.set(foot[0], foot[1], PAD)
    c.set(foot[0] + 1, foot[1], PAD)


def draw_leg(c, hip, foot, upper, lower, bend, near, piston=False):
    """Pata cibernética: muslo y canilla de metal, articulación de cromo,
    almohadilla de polímero. Las patas lejanas van más oscuras."""
    knee = ik_knee(hip, foot, upper, lower, bend)
    body = METAL if near else METAL_DK
    hi = METAL_HI if near else METAL
    c.line(hip[0], hip[1], knee[0], knee[1], body, 2 if near else 1)
    c.line(knee[0], knee[1], foot[0], foot[1] - 1, hi if near else body, 1)
    if piston and near:
        c.line(hip[0] + 1, hip[1] + 1, (hip[0] + knee[0]) / 2 + 1, (hip[1] + knee[1]) / 2 + 1, BRASS)
    c.set(knee[0], knee[1], CHROME if near else METAL)
    c.set(foot[0], foot[1], PAD)
    c.set(foot[0] + 1, foot[1], PAD)


def draw_tail(c, base, ctrl, tip):
    """Cola-cable segmentada (curva cuadrática) con conector magnético en la punta."""
    n = 10
    for i in range(n + 1):
        t = i / n
        x = (1 - t) ** 2 * base[0] + 2 * (1 - t) * t * ctrl[0] + t * t * tip[0]
        y = (1 - t) ** 2 * base[1] + 2 * (1 - t) * t * ctrl[1] + t * t * tip[1]
        c.set(x, y, CABLE if i % 2 == 0 else CABLE_HI)
        if i < n * 0.6:
            c.set(x, y + 1, CABLE)
    c.set(tip[0], tip[1], CHROME)
    c.set(tip[0] + (1 if tip[0] >= ctrl[0] else -1), tip[1], TIP)


def whiskers(px, x, y):
    for i in range(3):
        px[(x + i, y)] = WHISKER
    px[(x + 1, y + 1)] = WHISKER
    px[(x + 2, y + 2)] = WHISKER


# --- pose de perfil -----------------------------------------------------------

def rear_leg(hip, foot):
    """Trasera: rodilla adelante, corvejón atrás (patas de gato)."""
    hx, hy = hip
    fx, fy = foot
    knee = (hx + 2, hy + max(1, (fy - hy) * 0.35))
    hock = (fx - 1, fy - max(1, (fy - hy) * 0.3))
    return [hip, knee, hock, foot]


def front_leg(shoulder, foot):
    sx, sy = shoulder
    fx, fy = foot
    elbow = ((sx + fx) / 2 - 1, (sy + fy) / 2)
    return [shoulder, elbow, foot]


def side_pose(body_x=7, body_y=19, head=HEAD, head_dx=0, head_dy=0,
              feet=None, tail=None, arch=None, zs=()):
    """Gato de perfil. feet: almohadillas de [trasera lejana, delantera lejana,
    trasera cercana, delantera cercana] (None = de pie). tail: (control, punta)
    relativos a la base de la cola. arch: función t->desplazamiento del lomo."""
    c = Canvas()
    lift = (lambda t: round(arch(t))) if arch else (lambda t: 0)
    hip = (body_x + 2, body_y + 4 - lift(0.13))
    shoulder = (body_x + 12, body_y + 4 - lift(0.8))
    if feet is None:
        feet = [(hip[0] + 2, GROUND), (shoulder[0] - 2, GROUND),
                (hip[0], GROUND), (shoulder[0] + 1, GROUND)]
    # Patas lejanas detrás del cuerpo
    draw_leg_pts(c, rear_leg((hip[0] + 2, hip[1]), feet[0]), near=False)
    draw_leg_pts(c, front_leg((shoulder[0] - 2, shoulder[1]), feet[1]), near=False)
    # Cola-cable
    base = (body_x, body_y + 1 - lift(0.0))
    ctrl, tip = tail or ((-4, -2), (-6, -9))
    draw_tail(c, base, (base[0] + ctrl[0], base[1] + ctrl[1]), (base[0] + tip[0], base[1] + tip[1]))
    # Torso, con arco opcional (desplaza cada columna hacia arriba)
    w = len(TORSO[0])
    for y, row in enumerate(TORSO):
        for x, ch in enumerate(row):
            color = PALETTE.get(ch)
            if color is not None:
                c.set(body_x + x, body_y + y - lift(x / (w - 1)), color)
    # Cabeza y cables de cobre del cuello
    hx, hy = body_x + 11 + head_dx, body_y - 6 + head_dy - lift(0.95)
    c.stamp(head, hx, hy)
    c.set(hx + 1, hy + 6, COPPER)
    c.set(hx + 2, hy + 7, COPPER)
    # Patas cercanas delante
    draw_leg_pts(c, rear_leg(hip, feet[2]), near=True, piston=True)
    draw_leg_pts(c, front_leg(shoulder, feet[3]), near=True)
    px = c.outlined()
    if head is not HEAD_SLEEP:
        whiskers(px, hx + 11, hy + 5)
    for zx, zy in zs:
        z = Canvas()
        for dy, row in enumerate(["###", "..#", ".#.", "###"]):
            for dx, ch in enumerate(row):
                if ch == "#":
                    z.set(zx + dx, zy + dy, ZZZ)
        merge(px, z.outlined())
    return px


def lying_pose(breathe=0, head=HEAD, head_dy=0, zs=()):
    """Echado: torso en el suelo, patas recogidas, cola-cable enroscada."""
    c = Canvas()
    body_x, body_y = 7, 24 - breathe
    draw_tail(c, (body_x, body_y + 3), (body_x - 5, body_y + 5), (body_x + 1, body_y + 5))
    c.stamp(TORSO, body_x, body_y)
    # Patas delanteras estiradas y trasera plegada
    c.line(body_x + 12, body_y + 4, body_x + 17, GROUND, METAL_HI)
    c.line(body_x + 12, body_y + 5, body_x + 16, GROUND, METAL)
    c.set(body_x + 17, GROUND, PAD)
    c.set(body_x + 18, GROUND, PAD)
    c.line(body_x + 2, body_y + 4, body_x + 5, GROUND, METAL)
    c.set(body_x + 3, body_y + 4, CHROME)
    hx, hy = body_x + 11, body_y - 5 + head_dy + breathe
    c.stamp(head, hx, hy)
    c.set(hx + 1, hy + 6, COPPER)
    px = c.outlined()
    if head is not HEAD_SLEEP:
        whiskers(px, hx + 11, hy + 5)
    for zx, zy in zs:
        z = Canvas()
        for dy, row in enumerate(["###", "..#", ".#.", "###"]):
            for dx, ch in enumerate(row):
                if ch == "#":
                    z.set(zx + dx, zy + dy, ZZZ)
        merge(px, z.outlined())
    return px


def view(rows):
    c = Canvas()
    c.stamp(rows, 8, GROUND - len(rows) + 1)
    return c.outlined()


def mirror(px):
    return {(FRAME - 1 - x, y): col for (x, y), col in px.items()}


def squash(px, scale):
    """Vista intermedia al girar: comprime en horizontal y vuelve a contornear."""
    c = Canvas()
    for y in range(FRAME):
        for x in range(FRAME):
            a = 16 + (x - 16) / scale
            b = 16 + (x + 1 - 16) / scale
            cols = [px.get((sx, y)) for sx in range(math.floor(a), math.ceil(b))]
            fill = [col for col in cols if col is not None and col != OUT]
            if fill:
                c.set(x, y, max(set(fill), key=fill.count))
    return c.outlined()


# --- animaciones ---------------------------------------------------------------

def idle_frames():
    """Agazapado y tenso: respira, la cola-cable oscila y parpadea al final."""
    frames = []
    breath = [0, 0, 1, 1, 1, 1, 0, 0]
    for i in range(8):
        ph = i / 8 * math.tau
        tail = ((-4, -2 + round(math.sin(ph))), (-6 + round(math.sin(ph) * 1.5), -9))
        frames.append(side_pose(body_y=19 + breath[i], head_dy=-breath[i],
                                head=HEAD_BLINK if i == 7 else HEAD, tail=tail))
    return frames


def run_frames():
    """Galope: patas en fase, el cuerpo se estira y encoge, orejas plegadas."""
    frames = []
    for i in range(8):
        ph = i / 8 * math.tau

        def foot(base_x, p, reach=4.0, lift=3.0):
            return (base_x + reach * math.sin(p), GROUND - max(0.0, lift * math.cos(p)))

        stretch = round(math.sin(ph * 2) * 1)
        body_y = 18 + (1 if i % 4 in (0, 3) else 0)
        feet = [foot(11, ph + math.pi + 0.5), foot(17, ph + 0.5),
                foot(9, ph + math.pi), foot(20, ph)]
        wave = round(math.sin(ph * 2))
        frames.append(side_pose(body_y=body_y, head=HEAD_RUN, head_dx=stretch, feet=feet,
                                tail=((-5, -1 + wave), (-10, -2 - wave))))
    return frames


def jump_frames():
    return [
        side_pose(body_y=18, head=HEAD_RUN, feet=[(6, 29), (22, 26), (5, 29), (23, 25)],
                  tail=((-5, -1), (-9, -3))),
        side_pose(body_y=16, head=HEAD_RUN, feet=[(4, 27), (24, 21), (3, 26), (25, 20)],
                  tail=((-5, 0), (-10, 0))),
        side_pose(body_y=15, head=HEAD_RUN, feet=[(6, 24), (22, 21), (5, 23), (23, 20)],
                  tail=((-5, -1), (-9, -4))),
        side_pose(body_y=15, head=HEAD, feet=[(8, 24), (20, 23), (7, 23), (21, 22)],
                  tail=((-4, -3), (-7, -8))),
    ]


def fall_frames():
    frames = []
    for i in range(4):
        w = [0, 1, 0, -1][i]
        frames.append(side_pose(body_y=15, head=HEAD, head_dy=1,
                                feet=[(10, 27), (20, 27 + (i % 2)), (8, 27 + ((i + 1) % 2)), (22, 27)],
                                tail=((-3, -5 + w), (-4 + w, -12))))
    return frames


def turn_frames():
    side = idle_frames()[0]
    other = mirror(side)
    return [side, squash(side, 0.7), squash(side, 0.45), view(FRONT),
            squash(other, 0.45), squash(other, 0.7), other, view(BACK)]


def lie_frames():
    return [
        side_pose(body_y=20, head_dy=1, feet=[(12, 29), (17, 29), (9, 29), (21, 29)]),
        side_pose(body_y=21, head_dy=1, feet=[(12, 29), (18, 29), (10, 29), (22, 29)],
                  tail=((-4, 1), (-7, 3))),
        side_pose(body_y=22, head_dy=1, feet=[(12, 29), (19, 29), (11, 29), (23, 29)],
                  tail=((-4, 2), (-6, 5))),
        lying_pose(head=HEAD),
        lying_pose(head=HEAD, head_dy=1),
        lying_pose(head=HEAD_BLINK, head_dy=2),
        lying_pose(head=HEAD_SLEEP, head_dy=2),
    ]


def sleep_frames():
    breath = [0, 0, 1, 1, 1, 1, 0, 0]
    z_path = [(23, 16), (24, 14), (24, 12), (25, 10), (25, 8), (26, 6), (26, 4), (27, 2)]
    return [lying_pose(breathe=breath[i], head=HEAD_SLEEP, head_dy=2, zs=[z_path[i]])
            for i in range(8)]


def angry_frames():
    def arch(a):
        return lambda t: a * math.sin(math.pi * t)

    def straight_feet(hop=0):
        return [(12, GROUND - hop), (18, GROUND - hop), (10, GROUND - hop), (20, GROUND - hop)]

    up = ((-1, -6), (-1, -12))
    return [
        side_pose(body_y=18, head=HEAD_HISS, feet=straight_feet(2), arch=arch(2), tail=((-2, -5), (-3, -10))),
        side_pose(body_y=17, head=HEAD_HISS, feet=straight_feet(3), arch=arch(3), tail=up),
        side_pose(body_y=18, head=HEAD_HISS, head_dy=1, feet=straight_feet(1), arch=arch(4), tail=up),
        side_pose(body_y=19, head=HEAD_HISS, head_dy=2, feet=straight_feet(), arch=arch(5), tail=up),
        side_pose(body_y=19, head=HEAD_HISS, head_dy=2, feet=straight_feet(), arch=arch(6), tail=up),
        side_pose(body_y=19, head=HEAD_HISS, head_dy=3, feet=straight_feet(), arch=arch(6), tail=up),
        side_pose(body_y=19, head=HEAD, head_dy=1, feet=straight_feet(), arch=arch(3), tail=((-3, -4), (-4, -9))),
        side_pose(body_y=19, head=HEAD, feet=straight_feet(), arch=arch(1), tail=((-4, -2), (-6, -9))),
    ]


def sheet_rows():
    return [
        idle_frames(),
        run_frames(),
        jump_frames() + fall_frames(),
        turn_frames(),
        lie_frames(),
        sleep_frames(),
        angry_frames(),
    ]
