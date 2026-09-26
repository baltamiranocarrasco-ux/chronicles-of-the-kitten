"""Genera el sprite sheet del gato usado por player.tscn.

Uso:  python3 tools/generate_cat_sprites.py           gato ilustrado en alta resolución
      python3 tools/generate_cat_sprites.py --pixel   gato en pixel art (versión anterior)
Requiere Pillow y numpy (pip install pillow numpy).

El dibujo está en tools/hd_cat.py (cuadros de 96x96, que el juego muestra a
escala 1/3 con filtrado suave) o en tools/cyber_cat.py (pixel art de 32x32).
Hoja de 8 columnas x 8 filas, gato mirando a la derecha:
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
import sys
from pathlib import Path

from PIL import Image

import cyber_cat
import hd_cat

COLS, ROWS = 8, 8
GAME_FRAME = 32  ## tamaño del cuadro en píxeles del juego

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


def update_player_scene(sprite_scale):
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
    # Nodo Sprite2D: escala 1/3 y filtrado suave para el gato en alta resolución
    hd = sprite_scale != 1.0
    sprite = ('[node name="Sprite2D" type="Sprite2D" parent="."]\n'
              + ("texture_filter = 2\n" if hd else "")
              + "z_index = 1\n"
              + ("scale = Vector2(%g, %g)\n" % (sprite_scale, sprite_scale) if hd else "")
              + 'texture = ExtResource("2_sheet")\n'
              + f"hframes = {COLS}\nvframes = {ROWS}\n")
    text, count = re.subn(r'\[node name="Sprite2D" type="Sprite2D" parent="\."\]\n.*?\n\n', sprite + "\n", text,
                          count=1, flags=re.S)
    assert count == 1, "No encontré el nodo Sprite2D en player.tscn"
    path.write_text(text)
    print(f"Actualizado {path}")


def write_icon(frame):
    """Escribe icon.svg (128x128) con el primer cuadro de reposo, reducido a
    una rejilla de 32x32."""
    img = frame.resize((GAME_FRAME, GAME_FRAME), Image.LANCZOS) if frame.width != GAME_FRAME else frame
    box = img.getbbox()
    ox = (GAME_FRAME - (box[2] - box[0])) // 2 - box[0]
    oy = (GAME_FRAME - (box[3] - box[1])) // 2 - box[1]
    rects = []
    for y in range(GAME_FRAME):
        for x in range(GAME_FRAME):
            r, g, b, a = img.getpixel((x, y))
            if a < 40:
                continue
            opacity = "" if a > 245 else f' fill-opacity="{a / 255:.2f}"'
            rects.append(f'<rect x="{(x + ox) * 4}" y="{(y + oy) * 4}" width="4" height="4" '
                         f'fill="#{r:02x}{g:02x}{b:02x}"{opacity}/>')
    svg = (
        '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" '
        'viewBox="0 0 128 128" shape-rendering="crispEdges">\n'
        f'<rect width="128" height="128" rx="16" fill="{ICON_BG}"/>\n'
        + "\n".join(rects) + "\n</svg>\n"
    )
    out = ROOT / "icon.svg"
    out.write_text(svg)
    print(f"Guardado {out}")


def _pixel_image(px):
    img = Image.new("RGBA", (GAME_FRAME, GAME_FRAME), (0, 0, 0, 0))
    for (x, y), color in px.items():
        img.putpixel((x, y), color)
    return img


def main():
    pixel = "--pixel" in sys.argv
    rows = cyber_cat.sheet_rows() if pixel else hd_cat.sheet_rows()
    if pixel:
        rows = [[_pixel_image(px) for px in r] for r in rows]
    frame = rows[0][0].width
    sheet = Image.new("RGBA", (frame * COLS, frame * ROWS), (0, 0, 0, 0))
    for r, frames in enumerate(rows):
        assert len(frames) <= COLS, f"fila {r} con {len(frames)} cuadros"
        for col, img in enumerate(frames):
            sheet.alpha_composite(img, (col * frame, r * frame))
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out = OUT_DIR / "cat_sheet.png"
    sheet.save(out)
    print(f"Guardado {out} ({'pixel art' if pixel else 'alta resolución'}, cuadros de {frame}x{frame})")
    write_icon(rows[0][0])
    update_player_scene(GAME_FRAME / frame)


if __name__ == "__main__":
    main()
