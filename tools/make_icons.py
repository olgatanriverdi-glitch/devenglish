"""Uygulama simgesi: koyu mavi gradyan üstünde beyaz "En" + imleç bloğu (kod yazarken yanıp sönen imleç)."""
import json
import os

from PIL import Image, ImageDraw, ImageFont

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = 1024


def ana(maskable=False):
    im = Image.new("RGB", (S, S))
    px = im.load()
    for y in range(S):
        for x in range(S):
            t = (x * 0.35 + y * 0.65) / S
            px[x, y] = (int(36 + 40 * t), int(78 + 60 * t), int(205 - 25 * t))   # lacivert -> mavi
    d = ImageDraw.Draw(im)
    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 560 if not maskable else 470, index=1)
    metin = "En"
    kutu = d.textbbox((0, 0), metin, font=font)
    w, h = kutu[2] - kutu[0], kutu[3] - kutu[1]
    imlec_w, bosluk = (150 if not maskable else 120), 30
    toplam = w + bosluk + imlec_w
    x0 = (S - toplam) // 2 - kutu[0]
    y0 = (S - h) // 2 - kutu[1] - 10
    d.text((x0, y0), metin, font=font, fill=(255, 255, 255))
    ix = x0 + kutu[0] + w + bosluk
    iy2 = y0 + kutu[1] + h
    iy1 = iy2 - 44
    d.rounded_rectangle((ix, iy1, ix + imlec_w, iy2), radius=14, fill=(255, 193, 7))   # alt çizgi imleç: En_
    return im


def kaydet(im, yol, boyut):
    os.makedirs(os.path.dirname(yol), exist_ok=True)
    im.resize((boyut, boyut), Image.LANCZOS).save(yol)


def main():
    buyuk, maskable = ana(), ana(True)
    kaydet(buyuk, os.path.join(KOK, "web/icons/Icon-192.png"), 192)
    kaydet(buyuk, os.path.join(KOK, "web/icons/Icon-512.png"), 512)
    kaydet(maskable, os.path.join(KOK, "web/icons/Icon-maskable-192.png"), 192)
    kaydet(maskable, os.path.join(KOK, "web/icons/Icon-maskable-512.png"), 512)
    kaydet(buyuk, os.path.join(KOK, "web/favicon.png"), 32)
    set_dir = os.path.join(KOK, "ios/Runner/Assets.xcassets/AppIcon.appiconset")
    with open(os.path.join(set_dir, "Contents.json")) as f:
        icerik = json.load(f)
    for ic in icerik["images"]:
        boyut = float(ic["size"].split("x")[0]) * int(ic["scale"][0])
        kaydet(buyuk, os.path.join(set_dir, ic["filename"]), int(round(boyut)))
    buyuk.resize((256, 256), Image.LANCZOS).save("/tmp/claude-501/scratch/icon_preview_devenglish.png")
    print("tamam")


main()
