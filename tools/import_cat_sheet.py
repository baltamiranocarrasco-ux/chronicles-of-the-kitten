"""Importa una hoja de sprites del gato hecha a mano/externa (24x7 cuadros de 32x32)
y configura scenes/player.tscn para usarla.

Uso:  python3 tools/import_cat_sheet.py ruta/a/pixel_cat_all_32x32.png

Filas de la hoja: idle 8, run 8, jump 4, fall 4, settle 24, sleep 8, angry 10.
Copia la imagen a assets/cat/cat_sheet_v2.png (la hoja generada, cat_sheet.png,
no se toca) y reescribe animaciones, textura, tamaño de cuadros y colisión.

Para volver al gato generado:  python3 tools/generate_cat_sprites.py
"""

import re
import shutil
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_cat_sprites import _animation_resource  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
FRAME = 32
COLS, ROWS = 24, 7
DEST = ROOT / "assets" / "cat" / "cat_sheet_v2.png"
TEXTURE = "res://assets/cat/cat_sheet_v2.png"

# Los pies de estos sprites llegan a la última fila del cuadro: se sube 1 px para
# que apoyen justo sobre el borde inferior de la colisión.
SPRITE_OFFSET = "Vector2(0, -1)"
# El gato ocupa casi todo el cuadro; la caja cubre el cuerpo (no cabeza ni cola)
# y sirve tanto parado como corriendo, donde el sprite es más bajo.
COLLISION_SIZE = "Vector2(22, 16)"
COLLISION_POSITION = "Vector2(0, 7)"


def _row(r, count, total_time):
    return [(r * COLS + c, total_time / count) for c in range(count)]


ANIMATIONS = {
    "idle": (True, _row(0, 8, 1.1)),
    "run": (True, _row(1, 8, 0.6)),
    "jump": (False, _row(2, 4, 0.33)),
    "fall": (True, _row(3, 4, 0.4)),
    "settle": (False, _row(4, 24, 3.0)),
    "sleep": (True, _row(5, 8, 1.6)),
    "angry": (False, _row(6, 10, 1.3)),
}


def main():
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    src = Path(sys.argv[1])
    size = Image.open(src).size
    if size != (COLS * FRAME, ROWS * FRAME):
        raise SystemExit(f"La hoja mide {size}; se esperaba {(COLS * FRAME, ROWS * FRAME)}")
    shutil.copyfile(src, DEST)
    print(f"Copiada {DEST}")

    path = ROOT / "scenes" / "player.tscn"
    text = path.read_text()
    for name, (loop, keys) in ANIMATIONS.items():
        pattern = re.compile(
            r'\[sub_resource type="Animation" id="Animation_%s"\].*?(?=\[sub_resource)' % name, re.S)
        if not pattern.search(text):
            raise SystemExit(f"No encontré la animación {name} en {path}")
        text = pattern.sub(lambda _m: _animation_resource(name, loop, keys), text, count=1)
    text = re.sub(r'(type="Texture2D" path=")[^"]+(" id="2_sheet")', rf"\g<1>{TEXTURE}\g<2>", text)
    text = re.sub(r"hframes = \d+\nvframes = \d+", f"hframes = {COLS}\nvframes = {ROWS}", text)
    text = re.sub(r"\noffset = Vector2\([^)]*\)", "", text)
    text = text.replace("vframes = %d\n" % ROWS, "vframes = %d\noffset = %s\n" % (ROWS, SPRITE_OFFSET), 1)
    text = re.sub(r'(id="RectangleShape2D_body"\]\nsize = )Vector2\([^)]*\)', rf"\g<1>{COLLISION_SIZE}", text)
    text = re.sub(r'(\[node name="CollisionShape2D" type="CollisionShape2D" parent="\."\]\nposition = )Vector2\([^)]*\)',
                  rf"\g<1>{COLLISION_POSITION}", text)
    path.write_text(text)
    print(f"Actualizado {path}")


if __name__ == "__main__":
    main()
