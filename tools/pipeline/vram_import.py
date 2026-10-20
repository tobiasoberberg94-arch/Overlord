# 3D-Texturen auf GPU-Kompression (BCn) mit Mipmaps umstellen: ein Viertel des Grafikspeichers gegenüber
# „Lossless“, kein Flimmern in der Ferne. Normalmaps (…_N, …_NM, …_nor(_gl), …_normal) werden als RG-Normalmap
# (BC5) gespeichert – Godot rekonstruiert Z ohnehin aus XY.
# Godot setzt das sonst nur im Editor über „Detect 3D“ – headless importierte Texturen bleiben unkomprimiert.
# --ue: Normalmaps aus Unreal (DirectX-Konvention, Grün nach unten) → Grün beim Import umdrehen (Godot/glTF: OpenGL).
#   python vram_import.py [--ue] <ordner> [...]   danach: godot --headless --path . --import
import os
import re
import sys

NORMAL = re.compile(r"_(n|nm|nor|nor_gl|nor_dx|normal|nrm)(_\d+k)?(_\d+)?$", re.I)


def fix(imp, ue=False):
    src = imp[:-len(".import")]
    base = os.path.splitext(os.path.basename(src))[0]
    lines = open(imp, encoding="utf-8").read().split("\n")
    if not any(l.strip() == 'importer="texture"' for l in lines):
        return False
    is_n = bool(NORMAL.search(base))
    want = {"compress/mode": "2", "mipmaps/generate": "true", "compress/normal_map": "1" if is_n else "0",
            "process/normal_map_invert_y": "true" if (is_n and ue) else "false"}
    out, changed = [], False
    for l in lines:
        k = l.split("=", 1)[0]
        if k in want and l != k + "=" + want[k]:
            l = k + "=" + want[k]
            changed = True
        out.append(l)
    if changed:
        open(imp, "w", encoding="utf-8", newline="\n").write("\n".join(out))
    return changed


n = 0
ue = "--ue" in sys.argv
for root_dir in [a for a in sys.argv[1:] if not a.startswith("--")]:
    for d, _, files in os.walk(root_dir):
        for f in files:
            if f.endswith(".import") and not f.endswith((".glb.import", ".gltf.import", ".hdr.import", ".exr.import")):
                n += fix(os.path.join(d, f), ue)
print("umgestellt:", n)
