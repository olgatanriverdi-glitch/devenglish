"""tools/vocab.txt -> assets/data/vocab.json (+ kalite kontrolü)."""
import json
import os
import re
import sys

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def slug(s):
    s = s.lower().replace("ı", "i").replace("ö", "o").replace("ü", "u").replace("ç", "c").replace("ş", "s").replace("ğ", "g")
    return re.sub(r"[^a-z0-9]+", "-", s).strip("-")


def main():
    kategoriler, kelimeler, goruldu, uyarilar = [], [], {}, []
    cat = None
    with open(os.path.join(KOK, "tools", "vocab.txt"), encoding="utf-8") as f:
        for no, satir in enumerate(f, 1):
            satir = satir.strip()
            if not satir or satir.startswith("# "):
                continue
            if satir.startswith("## "):
                cid, ad = [p.strip() for p in satir[3:].split("|")]
                kategoriler.append({"id": cid, "name": ad})
                cat = cid
                continue
            parcalar = [p.strip() for p in satir.split("|")]
            if len(parcalar) != 5:
                sys.exit("Satır %d: 5 alan olmalı: %s" % (no, satir))
            term, pos, tr, tanim, ornek = parcalar
            anahtar = term.lower()
            if anahtar in goruldu:
                uyarilar.append("yinelenen terim atlandı: %s (%s, ilk: %s)" % (term, cat, goruldu[anahtar]))
                continue
            goruldu[anahtar] = cat
            if anahtar not in ornek.lower():
                uyarilar.append("örnek cümlede terim aynen geçmiyor (boşluk doldurma kullanılmaz): %s" % term)
            kelimeler.append({"id": slug(term), "term": term, "pos": pos, "tr": tr, "def": tanim, "ex": ornek, "cat": cat})
    ids = [k["id"] for k in kelimeler]
    assert len(ids) == len(set(ids)), "yinelenen id: %s" % [i for i in ids if ids.count(i) > 1]
    with open(os.path.join(KOK, "assets", "data", "vocab.json"), "w", encoding="utf-8") as f:
        json.dump({"categories": kategoriler, "words": kelimeler}, f, ensure_ascii=False, indent=0)
    print("%d kelime, %d kategori" % (len(kelimeler), len(kategoriler)))
    for k in kategoriler:
        print("  %-8s %3d" % (k["id"], sum(1 for w in kelimeler if w["cat"] == k["id"])))
    for u in uyarilar:
        print("UYARI:", u)


main()
