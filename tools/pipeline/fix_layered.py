"""Schicht-Materialien reparieren: Materialien ohne echte Farbtextur (Platzhalter wie
T_Substance_graph_BC oder T_empty_white_BC) bekommen die Textur, deren Name am besten zum
Materialnamen passt (MI_HouseWallV1 -> T_HouseWallV1_BC).

  python fix_layered.py paths <export-ordner> <Content/Paket-Ordner>   -> /Game-Pfade zum Nachexportieren
  python fix_layered.py patch <export-ordner> <nachexport-ordner>        -> Texturen kopieren, materials.json ergänzen
"""
import difflib
import json
import os
import re
import shutil
import sys
from pathlib import Path

JUNK = ("substance_graph", "empty", "default", "white", "noise")


def needs_fix(entry):
    bc = (entry or {}).get("basecolor", "")
    return not bc or any(k in bc.lower() for k in JUNK)


def key(s):
    return re.sub(r"[^a-z0-9]", "", s.lower())


def normal_of(t):
    return re.sub(r"_BC(_\d+)?$", r"_N\1", t)


def build_map(exp, pack):
    mats = json.load(open(Path(exp) / "materials.json"))["materials"]
    index = {p.stem: p for p in Path(pack).rglob("T_*.uasset")}
    bcs = [n for n in index if re.search(r"_BC(_\d+)?$", n) and not any(k in n.lower() for k in JUNK)]
    cand = {key(n[2:].rsplit("_BC", 1)[0]): n for n in bcs}
    out = {}
    for m, e in mats.items():
        if not needs_fix(e):
            continue
        k = key(re.sub(r"^(MI|M)_", "", m))
        best = difflib.get_close_matches(k, cand.keys(), n=1, cutoff=0.6)
        if best:
            out[m] = cand[best[0]]
    return out, index


if __name__ == "__main__":
    mode, exp = sys.argv[1], sys.argv[2]
    if mode == "paths":
        pack = Path(sys.argv[3])
        content = pack
        while content.name != "Content":
            content = content.parent
        tmap, index = build_map(exp, pack)
        json.dump(tmap, open(Path(exp) / "texmap.json", "w"), indent=1)
        paths = set()
        for t in set(tmap.values()):
            for n in (t, normal_of(t)):
                if n in index:
                    rel = index[n].relative_to(content).with_suffix("").as_posix()
                    paths.add("/Game/%s.%s" % (rel, n))
        print(" ".join(sorted(paths)))
    else:
        extra = Path(sys.argv[3])
        tmap = json.load(open(Path(exp) / "texmap.json"))
        for f in (extra / "textures").glob("*"):
            shutil.copy(f, Path(exp) / "textures" / f.name)
        files = os.listdir(Path(exp) / "textures")
        d = json.load(open(Path(exp) / "materials.json"))

        def fname(t):
            return next((f for f in files if f == t + ".png" or f.endswith("_" + t + ".png")), None)

        n = 0
        for mat, t in tmap.items():
            bc, nm = fname(t), fname(normal_of(t))
            if bc:
                d["materials"].setdefault(mat, {})["basecolor"] = bc
                if nm:
                    d["materials"][mat]["normal"] = nm
                n += 1
        json.dump(d, open(Path(exp) / "materials.json", "w"), indent=1)
        print("repariert", n, "von", len(tmap))
