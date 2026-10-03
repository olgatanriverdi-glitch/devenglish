"""Tüm İngilizce metinler için önceden kaydedilmiş ses dosyaları üretir (macOS `say` + afconvert).
Neden: tarayıcı/telefon sesleri (özellikle Türkçe iPhone'da) İngilizceyi Türkçe okuyabiliyor. Bu dosyalar her cihazda aynı doğru sesi verir.
Ses A = Samantha (ABD, kadın), ses B = Daniel (İngiltere, erkek). Dosya adı: sha1("<ses>|<metin>")[:16].m4a
Kullanım: python3 tools/make_audio.py   (var olanları atlar; metin değişince yeni dosya üretir, eskiler `--temizle` ile silinir)
"""
import hashlib
import json
import os
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VERI = os.path.join(KOK, "assets", "data")
CIKTI = os.path.join(KOK, "assets", "audio")
SESLER = {"a": ("Samantha", 165), "b": ("Daniel", 170)}


def anahtar(ses: str, metin: str) -> str:
    return hashlib.sha1(("%s|%s" % (ses, metin)).encode("utf-8")).hexdigest()[:16]


def metinleri_topla():
    def oku(ad):
        with open(os.path.join(VERI, ad), encoding="utf-8") as f:
            return json.load(f)

    s = set()
    for w in oku("vocab.json")["words"]:
        s.add(("a", w["term"]))
        s.add(("a", w["ex"]))
    l = oku("listening.json")
    for d in l["dialogues"]:
        for satir in d["lines"]:
            s.add(("b" if satir["s"] == 1 else "a", satir["t"]))
    for c in l["sentences"]:
        s.add(("a", c["t"]))
    k = oku("speaking.json")
    for p in k["prompts"]:
        s.add(("a", p["q"]))
        s.add(("a", p["model"]))
    for w in k["words"]:
        s.add(("a", w["w"]))
    for a in oku("articles.json")["articles"]:
        for p in a["paragraphs"]:
            s.add(("a", p))
    return s


def uret(oge):
    ses, metin = oge
    yol = os.path.join(CIKTI, anahtar(ses, metin) + ".m4a")
    if os.path.exists(yol):
        return 0
    ad, hiz = SESLER[ses]
    with tempfile.TemporaryDirectory() as d:
        aiff = os.path.join(d, "x.aiff")
        subprocess.run(["say", "-v", ad, "-r", str(hiz), "-o", aiff, "--", metin], check=True)
        subprocess.run(["afconvert", "-f", "m4af", "-d", "aac", "-b", "32000", "-c", "1", aiff, yol], check=True)
    return 1


def main():
    os.makedirs(CIKTI, exist_ok=True)
    metinler = sorted(metinleri_topla())
    print("%d ses dosyası gerekli" % len(metinler))
    with ThreadPoolExecutor(max_workers=6) as ex:
        yeni = sum(ex.map(uret, metinler))
    gerekli = {anahtar(s, m) + ".m4a" for s, m in metinler}
    eski = [f for f in os.listdir(CIKTI) if f.endswith(".m4a") and f not in gerekli]
    if "--temizle" in sys.argv:
        for f in eski:
            os.remove(os.path.join(CIKTI, f))
    boyut = sum(os.path.getsize(os.path.join(CIKTI, f)) for f in os.listdir(CIKTI)) / 1e6
    print("yeni üretilen: %d, kullanılmayan: %d%s, toplam boyut: %.1f MB" % (yeni, len(eski), " (silindi)" if "--temizle" in sys.argv else "", boyut))


main()
