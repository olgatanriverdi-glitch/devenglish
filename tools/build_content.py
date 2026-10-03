"""content_*.py -> assets/data/{listening,speaking,articles}.json + doğrulama."""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from content_articles import ARTICLES, LINKS  # noqa: E402
from content_listening import DIALOGUES, SENTENCES  # noqa: E402
from content_speaking import PROMPTS, WORDS  # noqa: E402

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(KOK, "assets", "data")


def yaz(ad, veri):
    with open(os.path.join(OUT, ad), "w", encoding="utf-8") as f:
        json.dump(veri, f, ensure_ascii=False, indent=0)


def sorulari_kontrol(kimlik, sorular):
    assert sorular, kimlik
    for q in sorular:
        assert 2 <= len(q["options"]) <= 4, (kimlik, q["q"])
        assert 0 <= q["answer"] < len(q["options"]), (kimlik, q["q"])
        assert len(set(q["options"])) == len(q["options"]), (kimlik, q["q"])


def main():
    ids = [d["id"] for d in DIALOGUES]
    assert len(ids) == len(set(ids))
    dlg = []
    for d in DIALOGUES:
        sorulari_kontrol(d["id"], d["questions"])
        assert all(s in (0, 1) for s, _ in d["lines"]), d["id"]
        dlg.append({**d, "lines": [{"s": s, "t": t} for s, t in d["lines"]]})
    cumleler = [{"t": t, "level": lv, "tr": tr} for t, lv, tr in SENTENCES]
    assert len({c["t"] for c in cumleler}) == len(cumleler)
    yaz("listening.json", {"dialogues": dlg, "sentences": cumleler})

    for p in PROMPTS:
        assert all(k == k.lower() for k in p["keywords"]), p["id"]
        # model cevap kendi anahtar kelimelerinin çoğunu içermeli (puanlama makul olsun)
        ml = p["model"].lower()
        kapsam = sum(1 for k in p["keywords"] if k in ml) / len(p["keywords"])
        if kapsam < 0.7:
            print("UYARI: model cevap anahtar kelimeleri az kapsıyor: %s (%.0f%%)" % (p["id"], kapsam * 100))
    yaz("speaking.json", {"prompts": PROMPTS, "words": [{"w": w, "ipa": i, "tip": t} for w, i, t in WORDS]})

    aids = [a["id"] for a in ARTICLES]
    assert len(aids) == len(set(aids))
    for a in ARTICLES:
        sorulari_kontrol(a["id"], a["questions"])
        govde = " ".join(a["paragraphs"]).lower()
        kelime_sayisi = len(govde.split())
        a["minutes"] = max(1, round(kelime_sayisi / 120))
        a["words"] = kelime_sayisi
        for g in a["glossary"]:
            if g.lower() not in govde:
                print("UYARI: sözlükçedeki kelime metinde yok: %s (%s)" % (g, a["id"]))
    yaz("articles.json", {"articles": ARTICLES, "links": LINKS})
    print("diyalog %d, cümle %d, konuşma sorusu %d, telaffuz %d, makale %d (%s kelime), bağlantı %d" % (
        len(dlg), len(cumleler), len(PROMPTS), len(WORDS), len(ARTICLES), [a["words"] for a in ARTICLES], len(LINKS)))


main()
