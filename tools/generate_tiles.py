"""Genera el tileset del suelo del nivel (pixel art, como el gato).

Uso:  python3 tools/generate_tiles.py
Requiere Pillow (pip install pillow).

Salida: assets/city/tiles.png, atlas 4x4 de 16x16:
  fila 0: tejado de chapa (izq, centro, der, centro con charco)
  fila 1: muro del edificio (izq, centro, der)
  fila 2: viga de acero, plataforma de un sentido (izq, centro, der)
  fila 3: púas electrificadas para los fosos (solo la primera)
"""

from pathlib import Path

from PIL import Image

TILE = 16
OUT = Path(__file__).resolve().parent.parent / "assets" / "city" / "tiles.png"


def rgb(h, a=255):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


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


def main():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    tiles().save(OUT)
    print(f"Guardado {OUT}")


if __name__ == "__main__":
    main()
