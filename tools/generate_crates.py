"""Genera los sprites de las cajas que el gato puede romper a zarpazos.

Uso:  python3 tools/generate_crates.py
Requiere Pillow (pip install pillow).

Igual que el gato, se dibujan con el triple de detalle (el juego las muestra a
escala 1/3 con filtrado suave). Se dibujan a 4x ese tamaño y se reducen,
para bordes suaves.

Salida en objects/:
  crate_metal.png  3 cuadros de 48x48 (16x16 en el juego): contenedor de carga
                   de acero. Cuadro 0 intacto, 1 y 2 con los arañazos y
                   abolladuras de cada golpe (resiste 3).
  crate_box.png    42x33 (14x11 en el juego): caja de cartón mojada por la
                   lluvia. Se rompe de un golpe.
"""

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

OUT_DIR = Path(__file__).resolve().parent.parent / "objects"
S = 3  # detalle respecto del juego
SS = 4  # sobremuestreo para el antialias

OUTLINE = (10, 8, 16, 255)
RIM_LEFT = (90, 210, 240)
RIM_RIGHT = (240, 80, 200)


def canvas(w, h):
    img = Image.new("RGBA", (w * S * SS, h * S * SS), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def u(v):
    """Unidades del juego -> píxeles del lienzo sobremuestreado."""
    return v * S * SS


def box(d, x0, y0, x1, y1, fill, r=0.0, outline=None, width=0.0):
    d.rounded_rectangle([u(x0), u(y0), u(x1) - 1, u(y1) - 1], radius=u(r), fill=fill,
                        outline=outline, width=int(u(width)) if width else 0)


def line(d, pts, fill, width):
    d.line([(u(x), u(y)) for x, y in pts], fill=fill, width=max(1, int(u(width))), joint="curve")


def translucent(img, draw_fn):
    """Dibuja en una capa aparte y la mezcla encima: ImageDraw reemplaza el
    alfa en vez de mezclar, y una mancha translúcida dejaría un agujero."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(layer))
    img.alpha_composite(layer)


def glow_layer(size, draw_fn, blur):
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(layer))
    return layer.filter(ImageFilter.GaussianBlur(u(blur)))


def finish(img):
    w, h = img.size
    return img.resize((w // SS, h // SS), Image.LANCZOS)


def rim(img, w, h):
    """Luz de neón en los bordes, como la del gato (cian a la izquierda,
    magenta a la derecha) y cielo arriba."""
    alpha = img.getchannel("A")
    mask = alpha.point(lambda a: 255 if a > 128 else 0)
    for dx, dy, color, strength in ((u(0.6), 0, RIM_LEFT, 0.55), (-u(0.6), 0, RIM_RIGHT, 0.5),
                                    (0, u(0.5), (150, 140, 230), 0.4)):
        shifted = Image.new("L", mask.size, 0)
        shifted.paste(mask, (int(dx), int(dy)))
        edge = Image.composite(Image.new("L", mask.size, 0), mask, shifted)  # borde sin cubrir al desplazar
        edge = edge.point(lambda a: int(a * strength))
        tint = Image.new("RGBA", mask.size, color + (255,))
        tint.putalpha(edge)
        img.alpha_composite(tint)


# --- contenedor de acero ----------------------------------------------------------

STEEL = (58, 64, 84, 255)
STEEL_HI = (122, 132, 162, 255)
STEEL_DK = (30, 33, 46, 255)
PANEL = (40, 44, 60, 255)
PANEL_DK = (26, 28, 40, 255)
HAZARD = (236, 186, 48, 255)
LED_OK = (90, 240, 255)
LED_BAD = (255, 60, 70)


def metal_crate(damage):
    W = H = 16
    img, d = canvas(W, H)
    # Cuerpo y marco
    box(d, 0, 0, W, H, OUTLINE, r=1.2)
    box(d, 0.5, 0.5, W - 0.5, H - 0.5, STEEL, r=1.0)
    box(d, 0.5, 0.5, W - 0.5, 1.5, STEEL_HI, r=0.8)          # canto superior iluminado
    box(d, 0.5, H - 1.6, W - 0.5, H - 0.5, STEEL_DK, r=0.8)  # base en sombra
    # Panel hundido con refuerzos en X
    box(d, 2.4, 2.8, W - 2.4, H - 2.4, PANEL_DK, r=0.4)
    box(d, 2.8, 3.2, W - 2.8, H - 2.8, PANEL, r=0.3)
    for y in (5.2, 8.0, 10.8):  # nervaduras horizontales
        line(d, [(3.0, y), (W - 3.0, y)], PANEL_DK, 0.35)
    line(d, [(3.2, 3.6), (W - 3.2, H - 3.2)], STEEL_DK, 1.5)
    line(d, [(3.2, H - 3.2), (W - 3.2, 3.6)], STEEL_DK, 1.5)
    line(d, [(3.2, 3.4), (W - 3.2, H - 3.4)], STEEL, 1.0)
    line(d, [(3.2, H - 3.4), (W - 3.2, 3.4)], STEEL, 1.0)
    line(d, [(3.4, 3.2), (W - 3.4, H - 3.6)], STEEL_HI, 0.3)
    # Franja de peligro en el canto superior del panel
    for i in range(6):
        x = 3.0 + i * 1.8
        d.polygon([(u(x), u(2.8)), (u(x + 0.9), u(2.8)), (u(x + 0.4), u(3.5)), (u(x - 0.5), u(3.5))],
                  fill=HAZARD)
    # Esquineros con remaches
    for cx, cy in ((0.5, 0.5), (W - 0.5, 0.5), (0.5, H - 0.5), (W - 0.5, H - 0.5)):
        sx = 1 if cx < W / 2 else -1
        sy = 1 if cy < H / 2 else -1
        pts = [(cx, cy), (cx + sx * 3.4, cy), (cx + sx * 3.4, cy + sy * 1.3), (cx + sx * 1.3, cy + sy * 1.3),
               (cx + sx * 1.3, cy + sy * 3.4), (cx, cy + sy * 3.4)]
        d.polygon([(u(x), u(y)) for x, y in pts], fill=STEEL_DK)
        rx, ry = cx + sx * 0.9, cy + sy * 0.9
        d.ellipse([u(rx - 0.45), u(ry - 0.45), u(rx + 0.45), u(ry + 0.45)], fill=STEEL_HI)
    # Placa con el código del lote y LED de estado
    box(d, W - 6.2, H - 5.4, W - 3.0, H - 3.4, STEEL_DK, r=0.2)
    for i in range(3):
        line(d, [(W - 5.8 + i * 0.9, H - 4.9), (W - 5.8 + i * 0.9, H - 3.9)], STEEL_HI, 0.25)
    led = LED_BAD if damage >= 2 else LED_OK
    lx, ly = W - 3.6, H - 4.4
    img.alpha_composite(glow_layer(img.size, lambda g: g.ellipse(
        [u(lx - 1.2), u(ly - 1.2), u(lx + 1.2), u(ly + 1.2)], fill=led + (150,)), 0.5))
    d.ellipse([u(lx - 0.4), u(ly - 0.4), u(lx + 0.4), u(ly + 0.4)], fill=(255, 255, 255, 255))

    # Daño: arañazos de garras al rojo y abolladuras
    rnd = random.Random(7)
    sets = [((10.5, 3.5), 1.0), ((5.0, 6.5), 0.9)][:damage]
    for (sx, sy), scale in sets:
        dent = (sx - 2.0, sy + 3.2)
        d.ellipse([u(dent[0] - 2.4), u(dent[1] - 1.6), u(dent[0] + 2.4), u(dent[1] + 1.6)], fill=PANEL_DK)
        d.arc([u(dent[0] - 2.4), u(dent[1] - 1.6), u(dent[0] + 2.4), u(dent[1] + 1.6)], 200, 340,
              fill=STEEL_HI, width=int(u(0.25)))
        for k in range(3):
            a = (sx + k * 1.3, sy + k * 0.35)
            b = (a[0] - 4.6 * scale, a[1] + 6.2 * scale)
            hot = glow_layer(img.size, lambda g, a=a, b=b: line(g, [a, b], (255, 120, 40, 200), 0.9), 0.35)
            img.alpha_composite(hot)
            line(d, [a, b], (20, 18, 26, 255), 0.55)
            line(d, [(a[0] + 0.15, a[1]), (b[0] + 0.15, b[1])], (255, 214, 170, 255), 0.22)
        if damage >= 2:
            # Esquina doblada y el canto rajado
            d.polygon([(u(W - 0.5), u(H - 5.5)), (u(W - 2.2), u(H - 3.8)), (u(W - 0.5), u(H - 2.4))], fill=OUTLINE)
            line(d, [(1.0, 9.5), (2.2, 10.4), (1.4, 11.6)], OUTLINE, 0.35)
    rim(img, W, H)
    # Suciedad y lluvia: manchas oscuras abajo y gotas claras
    def grime(g):
        for _ in range(40):
            x, y = rnd.uniform(0.8, W - 0.8), rnd.uniform(H * 0.55, H - 0.8)
            r = rnd.uniform(0.2, 0.6)
            g.ellipse([u(x - r), u(y - r), u(x + r), u(y + r)], fill=(20, 16, 14, rnd.randint(30, 90)))
        for _ in range(10):
            x, y = rnd.uniform(1.5, W - 1.5), rnd.uniform(1.5, H - 2)
            line(g, [(x, y), (x, y + rnd.uniform(0.8, 2.0))], (180, 200, 240, 70), 0.2)
    translucent(img, grime)
    return finish(img)


# --- caja de cartón --------------------------------------------------------------

CARD = (128, 92, 58, 255)
CARD_HI = (160, 120, 78, 255)
CARD_DK = (86, 60, 38, 255)
CARD_WET = (70, 48, 32, 255)
TAPE = (196, 170, 118, 255)
INK = (58, 40, 30, 255)


def cardboard_box():
    W, H = 14, 11
    img, d = canvas(W, H)
    box(d, 0, 0, W, H, OUTLINE, r=0.5)
    box(d, 0.5, 0.5, W - 0.5, H - 0.5, CARD, r=0.3)
    box(d, 0.5, 0.5, W - 0.5, 3.0, CARD_HI, r=0.3)  # tapas de arriba
    line(d, [(0.6, 3.0), (W - 0.6, 3.0)], CARD_DK, 0.35)
    line(d, [(W / 2, 0.6), (W / 2, 3.0)], CARD_DK, 0.3)
    # Base empapada por la lluvia (borde irregular)
    rnd = random.Random(3)
    pts = [(0.5, H - 0.5)]
    for i in range(15):
        x = 0.5 + i * (W - 1) / 14
        pts.append((x, H - 2.6 + rnd.uniform(-0.5, 0.5)))
    pts.append((W - 0.5, H - 0.5))
    d.polygon([(u(x), u(y)) for x, y in pts], fill=CARD_WET)
    # Cinta de embalar, algo despegada en la punta
    box(d, W / 2 - 1.3, 0.5, W / 2 + 1.3, 5.6, TAPE)
    line(d, [(W / 2 - 1.0, 0.8), (W / 2 - 1.0, 5.4)], (222, 202, 156, 255), 0.25)
    d.polygon([(u(W / 2 - 1.3), u(5.6)), (u(W / 2 + 1.3), u(5.6)), (u(W / 2 + 1.8), u(6.5))], fill=TAPE)
    # Estampado: flechas de "este lado arriba" y un código de envío
    for ax in (2.4, 4.0):
        line(d, [(ax, 8.0), (ax, 5.2)], INK, 0.35)
        d.polygon([(u(ax - 0.7), u(5.8)), (u(ax + 0.7), u(5.8)), (u(ax), u(4.8))], fill=INK)
    for i in range(5):
        line(d, [(9.0 + i * 0.7, 5.2), (9.0 + i * 0.7, 6.4 + (i % 2) * 0.4)], INK, 0.28)
    line(d, [(9.0, 7.4), (12.2, 7.4)], INK, 0.22)
    rim(img, W, H)
    # Arrugas y manchas
    def grime(g):
        for _ in range(25):
            x, y = rnd.uniform(0.8, W - 0.8), rnd.uniform(0.8, H - 0.8)
            r = rnd.uniform(0.2, 0.7)
            g.ellipse([u(x - r), u(y - r), u(x + r), u(y + r)], fill=(40, 26, 18, rnd.randint(20, 60)))
        line(g, [(1.2, 4.4), (2.6, 6.8)], (70, 50, 34, 120), 0.2)
        line(g, [(W - 1.4, 3.8), (W - 2.2, 6.0)], (70, 50, 34, 120), 0.2)
    translucent(img, grime)
    return finish(img)


def main():
    frames = [metal_crate(dmg) for dmg in range(3)]
    fw, fh = frames[0].size
    sheet = Image.new("RGBA", (fw * len(frames), fh), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.alpha_composite(f, (i * fw, 0))
    sheet.save(OUT_DIR / "crate_metal.png")
    cardboard_box().save(OUT_DIR / "crate_box.png")
    print(f"Guardado {OUT_DIR / 'crate_metal.png'} y {OUT_DIR / 'crate_box.png'}")


if __name__ == "__main__":
    main()
