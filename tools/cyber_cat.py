"""Arte del gato (pixel art 32x32, mirando a la derecha).

Gato callejero negro, sucio y despeinado, con dos implantes: una lente
cibernética en el ojo (el único que se ve de perfil; los dos ojos solo se
ven de frente, al girar) y una tira de fibra óptica en el lomo, que es la
barra de energía del juego. Sin bigotes.

Las formas se arman con elipses y trazos; la suciedad y los mechones se
colocan con un hash de la posición relativa al cuerpo, así se mueven con él
y no parpadean entre cuadros.

Colores clave que el juego reconoce en la hoja (no cambiarlos sin actualizar
effects/spine_meter.gd):
  SPINE_KEY / SPINE_NECK  tira de fibra óptica del lomo (NECK marca el extremo
                          del cuello, desde donde se apagan los segmentos)
  LENS_KEY                lente del ojo cibernético (se ilumina en cian)
"""

import math

FRAME = 32

# --- paleta ------------------------------------------------------------------
OUTLINE = (9, 8, 11, 255)
FUR = (38, 36, 44, 255)
FUR_DARK = (25, 24, 30, 255)    # patas lejanas, panza
FUR_HI = (56, 54, 64, 255)      # hocico y pelo que agarra luz
DIRT = (66, 56, 46, 255)        # manchas de tierra
DUST = (82, 78, 84, 255)        # polvo / pelo apelmazado
EYE = (70, 236, 128, 255)       # ojo orgánico (solo de frente)
PUPIL = (8, 30, 16, 255)
NOSE = (122, 78, 88, 255)
EAR_IN = (96, 60, 72, 255)
METAL = (150, 158, 176, 255)    # borde del implante
MOUTH = (90, 20, 28, 255)
FANG = (225, 222, 214, 255)
ZZZ = (140, 230, 255, 255)
SPINE_KEY = (64, 224, 224, 255)
SPINE_NECK = (66, 226, 226, 255)
LENS_KEY = (178, 24, 36, 255)


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

    def top_row(self, xs):
        """Píxel más alto de cada columna (para trazar la espina sobre el lomo)."""
        out = []
        for x in xs:
            ys = [y for (px, y) in self.px if px == x]
            if ys:
                out.append((x, min(ys)))
        return out

    def outlined(self):
        out = dict(self.px)
        for (x, y) in self.px:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (x + dx, y + dy)
                if n not in self.px and 0 <= n[0] < FRAME and 0 <= n[1] < FRAME:
                    out[n] = OUTLINE
        return out


def _hash(x, y, salt=0):
    h = (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
    h ^= h >> 13
    return (h * 1274126177) & 0xFFFF


def scruffy(px, ox, oy, salt=0):
    """Mechones: algunos bordes superiores se levantan un píxel (pelo despeinado)."""
    tufts = []
    for (x, y), c in px.items():
        if c != OUTLINE:
            continue
        below = px.get((x, y + 1))
        if below in (FUR, FUR_DARK) and (x, y - 1) not in px and _hash(x - ox, y - oy, salt) % 5 == 0:
            tufts.append((x, y))
    for x, y in tufts:
        px[(x, y)] = FUR
        for n in ((x, y - 1), (x - 1, y), (x + 1, y)):
            if n not in px and 0 <= n[0] < FRAME and 0 <= n[1] < FRAME:
                px[n] = OUTLINE
    return px


def grime(px, ox, oy, region=None, salt=0):
    """Manchas de tierra y polvo sobre el pelaje, fijas respecto al cuerpo."""
    for (x, y), c in list(px.items()):
        if c != FUR or (region and not region(x, y)):
            continue
        h = _hash(x - ox, y - oy, salt) % 23
        if h == 0:
            px[(x, y)] = DIRT
        elif h == 1:
            px[(x, y)] = DUST
        elif h in (2, 3):
            px[(x, y)] = FUR_HI
    return px


def spine(px, pts):
    """Tira de fibra óptica sobre los píxeles del lomo que siguen siendo pelaje.
    pts van de la cola al cuello; el último que quede es el extremo del cuello."""
    kept = [p for p in pts if px.get(p) in (FUR, FUR_DARK, FUR_HI, DIRT, DUST)]
    for p in kept:
        px[p] = SPINE_KEY
    if kept:
        px[kept[-1]] = SPINE_NECK
    return px


def draw_eye(px, x, y, state):
    """Único ojo de perfil: la lente cibernética de 2x2 con borde de metal."""
    if state == "closed":
        px[(x, y)] = OUTLINE
        px[(x + 1, y)] = OUTLINE
        return
    if state == "half":
        px[(x, y - 1)] = OUTLINE
        px[(x + 1, y - 1)] = OUTLINE
    else:
        px[(x, y - 1)] = LENS_KEY
        px[(x + 1, y - 1)] = LENS_KEY
    px[(x, y)] = LENS_KEY
    px[(x + 1, y)] = LENS_KEY
    px[(x - 1, y)] = METAL


def head(c, hx, hy, torn=True):
    """Cabeza redonda con orejas; la oreja lejana tiene la punta mordida."""
    c.ellipse(hx, hy, 5.5, 5, FUR)
    for ex in (hx - 3.5, hx + 1.5):
        ex = round(ex)
        c.line(ex, hy - 5, ex + 1, hy - 7, FUR, width=2)
        if not (torn and ex < hx - 2):
            c.set(ex + 1, hy - 8, FUR)
        c.set(ex + 1, hy - 5, EAR_IN)
    c.ellipse(hx + 3.5, hy + 2, 2.5, 1.8, FUR_HI)


def draw_cat(
    body_y=0,
    legs=((0, 0), (0, 0), (0, 0), (0, 0)),
    tail=((7, 20), (4, 17), (3, 13), (4, 10)),
    blink=False,
    head_dy=0,
    eyes="open",
):
    """legs: (dx, lift) para [trasera lejana, delantera lejana, trasera cercana, delantera cercana]."""
    c = Canvas()
    by = 21 + body_y
    hy = 14 + body_y + head_dy

    # Patas lejanas (más oscuras, detrás del cuerpo)
    for (hip_x, (dx, lift)) in ((10, legs[0]), (21, legs[1])):
        c.line(hip_x, by + 2, hip_x + dx, 29 - lift, FUR_DARK)

    c.poly(list(tail), FUR, width=2)

    body = Canvas()
    body.ellipse(15, by, 9, 4.5, FUR)
    back = body.top_row(range(8, 21))
    c.px.update(body.px)
    c.ellipse(16, by + 2.5, 6, 1.5, FUR_DARK)

    head(c, 23.5, hy)

    # Patas cercanas
    for (hip_x, (dx, lift)) in ((8, legs[2]), (19, legs[3])):
        c.line(hip_x, by + 2, hip_x + dx, 29 - lift, FUR)

    px = scruffy(c.outlined(), 0, by)
    grime(px, 0, by, region=lambda x, y: y > hy + 4 or x < 18)
    grime(px, 0, hy, region=lambda x, y: not (y > hy + 4 or x < 18), salt=1)
    spine(px, back)
    draw_eye(px, 25, hy, "closed" if blink else eyes)
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
    """8 cuadros: respiración suave, la cola ondea y parpadea en dos pasos al final."""
    frames = []
    breath = [0, 0, 1, 1, 1, 1, 0, 0]
    eyes = ["open"] * 6 + ["half", "closed"]
    for i in range(8):
        phase = i / 8 * 2 * math.pi
        frames.append(draw_cat(
            body_y=breath[i],
            head_dy=-breath[i],
            tail=tail_wave(phase, amp=2.0),
            eyes=eyes[i],
        ))
    return frames


def run_frames():
    """8 cuadros de galope: patas en fase, el cuerpo rebota dos veces por ciclo."""
    frames = []
    n = 8
    for i in range(n):
        phase = i / n * 2 * math.pi

        def leg(p):
            dx = round(3.2 * math.sin(p))
            lift = max(0, round(2.2 * math.cos(p)))
            return (dx, lift)

        bob = -1 if i % 4 in (1, 2) else 0
        tail_end = round(15 + math.sin(phase * 2) * 1.2)
        frames.append(draw_cat(
            body_y=bob,
            head_dy=1 if i % 4 == 0 else 0,
            legs=(
                leg(phase + math.pi + 0.6),   # trasera lejana
                leg(phase + 0.6),             # delantera lejana
                leg(phase + math.pi),         # trasera cercana
                leg(phase),                   # delantera cercana
            ),
            tail=((7, 19), (4, 17), (2, 16), (0, tail_end)),
        ))
    return frames


def jump_frames():
    """Impulso, subida y patas recogiéndose hacia el punto más alto."""
    return [
        draw_cat(body_y=-1, legs=((-3, 0), (3, 2), (-4, 0), (4, 3)),
                 tail=((7, 19), (4, 17), (2, 14), (1, 12))),
        draw_cat(body_y=-2, legs=((-5, 2), (5, 4), (-6, 1), (6, 5)),
                 tail=((7, 19), (4, 16), (2, 12), (2, 9))),
        draw_cat(body_y=-2, legs=((-5, 3), (5, 5), (-6, 2), (6, 6)),
                 tail=((7, 19), (4, 15), (3, 11), (4, 8))),
        draw_cat(body_y=-2, legs=((-3, 4), (3, 5), (-4, 3), (4, 5)),
                 tail=((7, 19), (4, 15), (4, 11), (5, 8))),
    ]


def fall_frames():
    """Patas estirándose hacia el suelo; la cola aletea para equilibrarse."""
    frames = []
    tails = [
        ((7, 19), (4, 14), (5, 10), (7, 7)),
        ((7, 19), (3, 14), (4, 10), (6, 6)),
        ((7, 19), (3, 14), (3, 9), (5, 6)),
        ((7, 19), (4, 14), (4, 9), (6, 7)),
    ]
    legs = [
        ((-3, 0), (4, 1), (-2, 1), (5, 0)),
        ((-4, 1), (5, 0), (-3, 0), (6, 1)),
        ((-4, 0), (5, 1), (-3, 1), (6, 0)),
        ((-3, 1), (4, 0), (-2, 0), (5, 1)),
    ]
    for i in range(4):
        frames.append(draw_cat(body_y=-1, head_dy=1, legs=legs[i], tail=tails[i]))
    return frames


# --- vueltas, acostarse, dormir y enojo -------------------------------------

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
                c.set(ex + (w if direction == 1 else -w), top_y + 3 - i, FUR)
        if inner:
            c.set(ex + direction, top_y + 2, EAR_IN)
    # Punta mordida en la oreja derecha de la imagen
    c.px.pop((right_x, top_y), None)


def front_view():
    """De frente: el único cuadro donde se ven los dos ojos."""
    c = Canvas()
    c.ellipse(16, 22.5, 6, 5, FUR)
    c.ellipse(16, 24, 3, 3, FUR_DARK)
    for lx in (13, 18):
        c.line(lx, 24, lx, 29, FUR)
    c.poly([(21, 27), (24, 25), (25, 21)], FUR)
    c.ellipse(16, 14, 6, 5, FUR)
    ears(c, 11, 21, 7)
    c.ellipse(16, 16.5, 2.5, 1.6, FUR_HI)
    px = scruffy(c.outlined(), 0, 0)
    grime(px, 0, 0)
    px[(13, 13)] = EYE
    px[(13, 14)] = PUPIL
    px[(19, 13)] = LENS_KEY
    px[(19, 14)] = LENS_KEY
    px[(20, 14)] = METAL
    px[(16, 16)] = NOSE
    return px


def back_view():
    c = Canvas()
    c.ellipse(16, 21.5, 6.5, 5.5, FUR)
    for lx in (12, 19):
        c.line(lx, 25, lx, 29, FUR)
    c.ellipse(16, 13, 5.5, 4.5, FUR)
    ears(c, 11, 21, 7, inner=False)
    px = scruffy(c.outlined(), 0, 0)
    grime(px, 0, 0)
    spine(px, [(16, y) for y in range(26, 17, -1)])
    tail = Canvas()
    tail.poly([(17, 26), (21, 25), (24, 21), (24, 16), (23, 13)], FUR)
    return overlay(px, tail)


def draw_lying(head_drop=0, eyes="open", breathe=0, zs=()):
    """Gato echado de lado mirando a la derecha.
    head_drop: 0 cabeza en alto ... 3 apoyada. zs: posiciones (x, y) de las "z"."""
    c = Canvas()
    c.poly([(8, 27), (4, 28), (5, 30), (12, 30)], FUR)   # cola enroscada
    body = Canvas()
    body.ellipse(14, 26 - breathe * 0.5, 10, 3.5 + breathe * 0.5, FUR)
    back = body.top_row(range(7, 20))
    c.px.update(body.px)
    c.ellipse(15, 28, 6, 1.5, FUR_DARK)
    c.line(20, 28, 25, 29, FUR)                              # patas delanteras
    hy = 21 + head_drop
    c.ellipse(23.5, hy, 5, 4.5, FUR)
    ex = 20
    for i in range(3):
        c.set(ex + i, hy - 5 + i // 2, FUR)
        c.set(ex + 4 + i, hy - 5 + i // 2, FUR)
    c.set(ex + 5, hy - 6, FUR)
    c.ellipse(27, hy + 1.5, 2.5, 1.6, FUR_HI)
    px = scruffy(c.outlined(), 0, 0)
    grime(px, 0, 0)
    spine(px, back)
    draw_eye(px, 25, hy, eyes)
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


def draw_angry(peak_y=10, tail_top=4, hiss=False, hop=0, puff=1):
    """Lomo arqueado estilo gato de Halloween: patas rectas, pelo y cola erizados."""
    c = Canvas()
    foot = 29 - hop
    arch = Canvas()
    pts = []
    for i in range(15):
        t = i / 14
        x = 7 + 14 * t
        y = 20 - hop - (20 - hop - peak_y) * math.sin(math.pi * t)
        pts.append((x, y))
        arch.circle(x, y + 1, 3.6, FUR)
    back = arch.top_row(range(6, 21))
    c.px.update(arch.px)
    for i, (x, y) in enumerate(pts[1:-1]):
        if puff and i % 2 == 0:
            c.set(round(x), round(y - 4), FUR)
            if puff > 1:
                c.set(round(x), round(y - 5), FUR)
    for lx in (7, 10, 18, 21):
        c.line(lx, 20 - hop, lx, foot, FUR if lx in (7, 18) else FUR_DARK)
    hx, hy = 25, 20 - hop
    c.ellipse(hx, hy, 5, 4.5, FUR)
    c.line(21, hy - 3, 19, hy - 5, FUR)
    c.line(24, hy - 4, 23, hy - 6, FUR)
    c.ellipse(28.5, hy + 1.5, 2.2, 1.6, FUR_HI)
    px = scruffy(c.outlined(), 0, hop)
    grime(px, 0, hop)
    spine(px, back)
    tail = Canvas()
    tail.line(6, 19 - hop, 5, tail_top, FUR, width=3)
    for y in range(tail_top + 1, 18 - hop, 3):
        tail.set(4, y, FUR)
        tail.set(8, y + 1, FUR)
    tail_px = scruffy(tail.outlined(), 0, hop, salt=2)
    grime(tail_px, 0, hop, salt=2)
    px.update(tail_px)
    # Lente muy abierta
    for p in ((26, hy - 2), (27, hy - 2), (26, hy - 1), (27, hy - 1)):
        px[p] = LENS_KEY
    px[(25, hy - 1)] = METAL
    px[(30, hy)] = NOSE
    if hiss:
        for mx in (27, 28, 29):
            px[(mx, hy + 2)] = MOUTH
        px[(28, hy + 3)] = MOUTH
        px[(29, hy + 1)] = FANG
    return px


def front_head(c, cx, cy, inner=True):
    """Cabeza vista de frente (o de espaldas con inner=False)."""
    c.ellipse(cx, cy, 5.5, 5, FUR)
    ears(c, round(cx - 5), round(cx + 5), round(cy - 7), inner=inner)
    if inner:
        c.ellipse(cx, cy + 2.5, 2.5, 1.6, FUR_HI)


def front_eyes(px, cx, cy):
    """Ojo orgánico verde a la izquierda de la imagen y lente a la derecha."""
    px[(cx - 3, cy - 1)] = EYE
    px[(cx - 3, cy)] = PUPIL
    px[(cx + 2, cy - 1)] = LENS_KEY
    px[(cx + 2, cy)] = LENS_KEY
    px[(cx + 3, cy)] = METAL
    px[(cx, cy + 2)] = NOSE


def three_quarter_front():
    """Girando hacia la cámara (venía caminando a la derecha): cabeza de frente,
    cuerpo en escorzo hacia atrás y la cola asomando detrás."""
    c = Canvas()
    c.line(9, 24, 9, 29, FUR_DARK)                      # trasera lejana
    c.poly([(8, 21), (5, 18), (4, 14), (5, 11)], FUR)   # cola
    body = Canvas()
    body.ellipse(13, 22, 6.5, 4.5, FUR)
    back = body.top_row(range(8, 17))
    c.px.update(body.px)
    c.ellipse(19, 23, 4, 4.5, FUR)                      # pecho
    c.line(11, 25, 11, 29, FUR)                         # trasera cercana
    c.line(17, 26, 17, 29, FUR_DARK)                    # delanteras
    c.line(20, 26, 20, 29, FUR)
    front_head(c, 20, 14)
    px = scruffy(c.outlined(), 0, 0, salt=3)
    grime(px, 0, 0, salt=3)
    spine(px, back)
    front_eyes(px, 20, 14)
    return px


def three_quarter_back():
    """Alejándose hacia la izquierda: nuca y orejas por detrás, el lomo con la
    espina en diagonal y la cola hacia la cámara."""
    c = Canvas()
    c.line(12, 25, 12, 29, FUR_DARK)                    # delantera lejana
    c.line(21, 26, 21, 29, FUR_DARK)                    # trasera lejana
    body = Canvas()
    body.ellipse(17, 22, 6.5, 5, FUR)
    back = body.top_row(range(22, 12, -1))
    c.px.update(body.px)
    c.line(15, 26, 15, 29, FUR)
    c.line(19, 27, 19, 29, FUR)
    front_head(c, 11, 14, inner=False)
    px = scruffy(c.outlined(), 0, 0, salt=4)
    grime(px, 0, 0, salt=4)
    spine(px, back)
    tail = Canvas()
    tail.poly([(22, 24), (25, 21), (26, 16), (25, 12)], FUR)
    return overlay(px, tail)


def turn_frames():
    """Vistas para dar vueltas: lado, 3/4 hacia la cámara, frente, 3/4 al otro
    lado, 3/4 de espaldas, espalda, 3/4 de espaldas al otro lado, lado opuesto."""
    side = idle_frames()[0]
    q_front = three_quarter_front()
    q_back = three_quarter_back()
    return [
        side,
        q_front,
        front_view(),
        mirror(q_front),
        q_back,
        back_view(),
        mirror(q_back),
        mirror(side),
    ]


def walk_frames():
    """Paso tranquilo de 4 cuadros (patas en secuencia lateral), hacia la
    derecha y su espejo hacia la izquierda."""
    def leg(p):
        return (round(2 * math.sin(p)), max(0, round(1.5 * math.cos(p))))

    right = []
    for i in range(4):
        ph = i / 4 * 2 * math.pi
        right.append(draw_cat(
            body_y=1 if i % 2 else 0,
            head_dy=-1 if i % 2 else 0,
            legs=(leg(ph + math.pi), leg(ph + 1.5 * math.pi), leg(ph), leg(ph + 0.5 * math.pi)),
            tail=tail_wave(ph, amp=1.0),
        ))
    return right + [mirror(f) for f in right]


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
    """Respiración lenta y una "z" que sube de a poco en diagonal."""
    breath = [0, 0, 1, 1, 1, 1, 0, 0]
    z_path = [(24, 16), (25, 14), (25, 12), (26, 10), (26, 8), (27, 6), (27, 4), (28, 2)]
    return [draw_lying(head_drop=3, eyes="closed", breathe=breath[i], zs=[z_path[i]])
            for i in range(8)]


def angry_frames():
    return [
        draw_angry(peak_y=14, tail_top=9, hop=2, puff=0),    # 0 sobresalto
        draw_angry(peak_y=12, tail_top=7, hop=3, puff=1),    # 1 en el aire
        draw_angry(peak_y=11, tail_top=5, hop=1, puff=1),    # 2 cae arqueándose
        draw_angry(peak_y=9, tail_top=3, puff=1),            # 3 lomo arqueado
        draw_angry(peak_y=9, tail_top=3, puff=2),            # 4 pelo muy erizado
        draw_angry(peak_y=9, tail_top=3, puff=2, hiss=True), # 5 bufido
        draw_angry(peak_y=11, tail_top=6, puff=1),           # 6 se relaja
        draw_angry(peak_y=13, tail_top=9, puff=0),           # 7 casi normal
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
        walk_frames(),
    ]
