"""Genera el sprite sheet del gato cíborg (pixel art) usado por player.tscn.

Uso:  python3 tools/generate_cat_sprites.py
Requiere Pillow (pip install pillow).

El dibujo está en tools/cyber_cat.py. Hoja de 8 columnas x 7 filas, cuadros
de 32x32, gato mirando a la derecha:
  fila 0: idle (8)        fila 1: run (8)
  fila 2: jump (4) + fall (4)
  fila 3: vistas para dar vueltas: lado, 3/4 hacia la cámara, frente,
          3/4 al otro lado, 3/4 de espaldas, espalda, 3/4 de espaldas al
          otro lado, lado opuesto
  fila 4: acostarse (7)   fila 5: dormir (8)   fila 6: enojo (8)
  fila 7: caminar a la derecha (4) y a la izquierda (4)

Además reescribe las animaciones de scenes/player.tscn según ANIMATIONS,
para que la hoja y las animaciones siempre coincidan.
"""

import re
from pathlib import Path

from PIL import Image

from cyber_cat import FRAME, sheet_rows

COLS, ROWS = 8, 8

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "cat"
ICON_BG = "#1d1830"


# --- animaciones de player.tscn -------------------------------------------
# Cada animación: (loop, [(frame, duración en s), ...]). frame = fila * COLS + columna.

def _row(r, cols, duration):
    return [(r * COLS + c, duration) for c in cols]


def _settle():
    """Da dos vueltas antes de acostarse, desplazándose de verdad: camina a la
    derecha, gira hacia la cámara, vuelve caminando a la izquierda, se da la
    vuelta de espaldas y regresa al punto de partida. Cada clave lleva el
    desplazamiento horizontal del sprite (Player.settle_offset)."""
    turn = 3 * COLS
    walk_r = [7 * COLS + c for c in range(4)]
    walk_l = [7 * COLS + 4 + c for c in range(4)]
    keys, x = [], 0.0

    def add(frames, step, duration):
        nonlocal x
        for f in frames:
            keys.append((f, duration, round(x)))
            x += step

    for _ in range(2):
        add(walk_r, 1.25, 0.1)                          # 0 -> +5
        add([turn + 1, turn + 2, turn + 3], 0, 0.12)    # gira hacia la cámara
        add(walk_l + walk_l, -1.25, 0.1)                # +5 -> -5
        add([turn + 4, turn + 5, turn + 6], 0, 0.12)    # gira de espaldas
        add(walk_r, 1.25, 0.1)                          # -5 -> 0
    add([turn], 0, 0.1)
    for c, d in [(0, 0.1), (1, 0.1), (2, 0.1), (3, 0.3), (4, 0.2), (5, 0.2), (6, 0.3)]:
        add([4 * COLS + c], 0, d)
    return keys


ANIMATIONS = {
    "idle": (True, _row(0, range(8), 1 / 7)),
    "run": (True, _row(1, range(8), 1 / 13)),
    "jump": (False, _row(2, range(4), 1 / 12)),
    "fall": (True, _row(2, range(4, 8), 1 / 10)),
    "settle": (False, _settle()),
    "sleep": (True, _row(5, range(8), 1 / 5)),
    # Reutiliza el gato agachado de "acostarse" (sin cuadros nuevos)
    "slide": (False, [(4 * COLS + 1, 0.05), (4 * COLS + 2, 0.5)]),
    "angry": (False, [(6 * COLS + c, d) for c, d in
                      [(0, 0.06), (1, 0.06), (2, 0.08), (3, 0.1), (4, 0.15), (5, 0.25),
                       (4, 0.1), (5, 0.2), (3, 0.1), (6, 0.1), (7, 0.1)]]),
}


def _animation_resource(name, loop, keys):
    times, t = [], 0.0
    for key in keys:
        times.append(round(t, 4))
        t += key[1]
    times_str = ", ".join(str(x) for x in times)
    transitions = ", ".join("1" for _ in keys)
    values = ", ".join(str(k[0]) for k in keys)
    text = f"""[sub_resource type="Animation" id="Animation_{name}"]
resource_name = "{name}"
length = {round(t, 4)}
loop_mode = {1 if loop else 0}
step = 0.01
tracks/0/type = "value"
tracks/0/imported = false
tracks/0/enabled = true
tracks/0/path = NodePath("Sprite2D:frame")
tracks/0/interp = 1
tracks/0/loop_wrap = true
tracks/0/keys = {{
"times": PackedFloat32Array({times_str}),
"transitions": PackedFloat32Array({transitions}),
"update": 1,
"values": [{values}]
}}
"""
    if len(keys[0]) > 2:
        offsets = ", ".join(f"{float(k[2])}" for k in keys)
        text += f"""tracks/1/type = "value"
tracks/1/imported = false
tracks/1/enabled = true
tracks/1/path = NodePath(".:settle_offset")
tracks/1/interp = 1
tracks/1/loop_wrap = true
tracks/1/keys = {{
"times": PackedFloat32Array({times_str}),
"transitions": PackedFloat32Array({transitions}),
"update": 1,
"values": [{offsets}]
}}
"""
    return text + "\n"


def update_player_scene():
    path = ROOT / "scenes" / "player.tscn"
    text = path.read_text()
    for name, (loop, keys) in ANIMATIONS.items():
        pattern = re.compile(
            r'\[sub_resource type="Animation" id="Animation_%s"\].*?(?=\[sub_resource)' % name,
            re.S)
        if pattern.search(text):
            text = pattern.sub(lambda _m: _animation_resource(name, loop, keys), text, count=1)
        else:
            # Animación nueva: se agrega antes de la librería y se registra en ella
            text = text.replace('[sub_resource type="AnimationLibrary"',
                                _animation_resource(name, loop, keys) + '[sub_resource type="AnimationLibrary"', 1)
            text = text.replace('_data = {\n', f'_data = {{\n&"{name}": SubResource("Animation_{name}"),\n', 1)
    text = re.sub(r"hframes = \d+\nvframes = \d+", f"hframes = {COLS}\nvframes = {ROWS}", text)
    path.write_text(text)
    print(f"Actualizado {path}")


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
    rows = sheet_rows()
    for r, frames in enumerate(rows):
        assert len(frames) <= COLS, f"fila {r} con {len(frames)} cuadros"
        for col, px in enumerate(frames):
            for (x, y), color in px.items():
                sheet.putpixel((col * FRAME + x, r * FRAME + y), color)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out = OUT_DIR / "cat_sheet.png"
    sheet.save(out)
    print(f"Guardado {out}")
    write_icon(rows[0][0])
    update_player_scene()


if __name__ == "__main__":
    main()
