# Prozedurale Bauwerke (Blender, auf loc_kit.Kit): Mausoleen, Friedhofsmauern, eiserne Zäune, Grabkreuze,
# Grabplatten, Obelisken, Torpfeiler. Alles in Weltkoordinaten (Blender: X rechts, Y vor, Z oben); die Materialien
# tragen sprechende Namen (MI_Mausoleum, MI_IronFence …) – im Spiel ersetzt scripts/world3d/building_look.gd sie
# durch Fotomaterialien (dreiseitig projiziert), die UVs hier sind nur Notbehelf.
#   sk = Structs(kit, town)        town (town_kit.Town) optional – belegt dann das Raster
#   sk.mausoleum(x, y, rot, w=5, d=6, h=4, style="gable"|"dome"|"pyramid"|"grand")
#   sk.plain_wall(linie, height=3.2, gaps=[(x, y)], …)   sk.iron_fence(punkte, …)
#   sk.cross(x, y, rot) / sk.slab(x, y, rot) / sk.obelisk(x, y) / sk.gate_pillars(x, y, rot, breite)
#   sk.flush()                      fasst alles zu wenigen Meshes zusammen (ein Objekt je Material-Satz)
import math

import bmesh
import bpy
from mathutils import Matrix, Vector

MATS = ["MI_Mausoleum", "MI_MausoleumDark", "MI_MausoleumRoof", "MI_CryptStone", "MI_CemeteryWall", "MI_GraveStone",
        "MI_IronFence", "MI_CryptDoor", "MI_MarbleWhite", "MI_BlackStone", "MI_Thatch", "MI_Planks", "MI_LogWood", "MI_Bone",
        "MI_DwarfStone", "MI_DwarfGold", "MI_Bark", "MI_ElfStone", "MI_CaveRock"]
COL = {"MI_Mausoleum": (0.62, 0.58, 0.52), "MI_MausoleumDark": (0.35, 0.35, 0.36), "MI_MausoleumRoof": (0.22, 0.22, 0.24),
       "MI_CryptStone": (0.4, 0.38, 0.35), "MI_CemeteryWall": (0.45, 0.43, 0.4), "MI_GraveStone": (0.42, 0.42, 0.43),
       "MI_IronFence": (0.04, 0.04, 0.04), "MI_CryptDoor": (0.12, 0.08, 0.05), "MI_MarbleWhite": (0.8, 0.78, 0.74),
       "MI_BlackStone": (0.08, 0.08, 0.09), "MI_Thatch": (0.3, 0.26, 0.18), "MI_Planks": (0.3, 0.24, 0.17),
       "MI_LogWood": (0.25, 0.2, 0.15), "MI_Bone": (0.7, 0.66, 0.56), "MI_DwarfStone": (0.4, 0.38, 0.36),
       "MI_DwarfGold": (0.75, 0.55, 0.2), "MI_Bark": (0.3, 0.25, 0.2), "MI_ElfStone": (0.7, 0.7, 0.68),
       "MI_CaveRock": (0.3, 0.29, 0.27)}


class Structs:
    def __init__(self, kit, town=None, tile=3.0):
        self.kit = kit
        self.town = town
        self.rng = kit.rng
        self.tile = tile
        self.mats = []
        for n in MATS:
            m = bpy.data.materials.get(n)
            if m is None:
                m = bpy.data.materials.new(n)
                m.use_nodes = True
                b = m.node_tree.nodes["Principled BSDF"]
                b.inputs["Base Color"].default_value = (*COL[n], 1.0)
                b.inputs["Roughness"].default_value = 0.9
                if n == "MI_IronFence":
                    b.inputs["Metallic"].default_value = 0.6
                    b.inputs["Roughness"].default_value = 0.55
            kit.keep_mats.add(m.name)
            self.mats.append(m)
        self.mi = {n: i for i, n in enumerate(MATS)}
        self._bms = {}                 # Kachel → (bmesh, uv-Schicht): eigene Objekte je 32-m-Kachel (Culling)
        self.count = 0

    # --- Grundformen -------------------------------------------------------------------------------------
    def _uvf(self, f):
        n = f.normal
        t = self.tile
        for lp in f.loops:
            co = lp.vert.co
            if abs(n.z) > 0.7:
                lp[self.uv].uv = (co.x / t, co.y / t)
            elif abs(n.x) > abs(n.y):
                lp[self.uv].uv = (co.y / t, co.z / t)
            else:
                lp[self.uv].uv = (co.x / t, co.z / t)

    def _bm_for(self, p):
        key = (int(math.floor(p[0] / 32.0)), int(math.floor(p[1] / 32.0)))
        if key not in self._bms:
            bm = bmesh.new()
            self._bms[key] = (bm, bm.loops.layers.uv.new("UVMap"))
        return self._bms[key]

    def poly(self, pts, mat, want=None):
        bm, self.uv = self._bm_for(pts[0])
        vs = [bm.verts.new(Vector(p)) for p in pts]
        f = bm.faces.new(vs)
        f.normal_update()
        if want is not None and f.normal.dot(Vector(want)) < 0:
            f.normal_flip()
        f.material_index = self.mi[mat]
        self._uvf(f)
        return f

    def tube(self, rings, mat, cap_end=True, cap_start=False, smooth=True):
        """Röhre aus Ringen gleicher Punktzahl mit gemeinsamen Eckpunkten: rund (weich schattiert) statt facettiert."""
        bm, self.uv = self._bm_for(rings[0][0])
        vr = [[bm.verts.new(Vector(p)) for p in ring] for ring in rings]
        n = len(rings[0])
        cents = [sum((Vector(p) for p in ring), Vector()) / n for ring in rings]
        for i in range(len(vr) - 1):
            axis_c = (cents[i] + cents[i + 1]) / 2
            for k in range(n):
                k2 = (k + 1) % n
                f = bm.faces.new((vr[i][k], vr[i][k2], vr[i + 1][k2], vr[i + 1][k]))
                f.normal_update()
                fc = f.calc_center_median()
                if f.normal.dot(fc - axis_c) < 0:
                    f.normal_flip()
                f.material_index = self.mi[mat]
                f.smooth = smooth
                self._uvf(f)
        for (do, ring, other) in ((cap_end, vr[-1], cents[-2] if len(cents) > 1 else cents[-1]),
                                  (cap_start, vr[0], cents[1] if len(cents) > 1 else cents[0])):
            if not do:
                continue
            f = bm.faces.new(ring)
            f.normal_update()
            if f.normal.dot(f.calc_center_median() - other) < 0:
                f.normal_flip()
            f.material_index = self.mi[mat]
            self._uvf(f)

    def box(self, M, sx, sy, sz, mat, z0=0.0, top=True, bottom=False, taper=1.0):
        """Quader (bzw. Pyramidenstumpf, taper < 1) im System M, Grundfläche sx × sy ab z0, Höhe sz."""
        lo = [M @ Vector((x, y, z0)) for (x, y) in ((-sx / 2, -sy / 2), (sx / 2, -sy / 2), (sx / 2, sy / 2), (-sx / 2, sy / 2))]
        hi = [M @ Vector((x * taper, y * taper, z0 + sz)) for (x, y) in ((-sx / 2, -sy / 2), (sx / 2, -sy / 2), (sx / 2, sy / 2),
                                                                         (-sx / 2, sy / 2))]
        c = M @ Vector((0, 0, z0 + sz / 2))
        for e in range(4):
            mid = (lo[e] + lo[(e + 1) % 4] + hi[e] + hi[(e + 1) % 4]) / 4
            self.poly([lo[e], lo[(e + 1) % 4], hi[(e + 1) % 4], hi[e]], mat, mid - c)
        if top:
            self.poly(hi, mat, (0, 0, 1))
        if bottom:
            self.poly(lo, mat, (0, 0, -1))

    def cyl(self, M, r, z0, h, mat, sides=12, r_top=None, top=True):
        r_top = r if r_top is None else r_top
        ring0 = [M @ Vector((math.cos(k * math.tau / sides) * r, math.sin(k * math.tau / sides) * r, z0)) for k in range(sides)]
        ring1 = [M @ Vector((math.cos(k * math.tau / sides) * r_top, math.sin(k * math.tau / sides) * r_top, z0 + h)) for k in range(sides)]
        self.tube([ring0, ring1], mat, cap_end=top and r_top > 0.001, smooth=sides >= 8)

    def gable(self, M, sx, sy, z0, h, mat, gable_mat=None):
        """Satteldach: First entlang der lokalen Y-Achse (Tiefe); Giebeldreiecke vorn/hinten."""
        gm = gable_mat or mat
        a, b, c_, d = (M @ Vector((-sx / 2, -sy / 2, z0)), M @ Vector((sx / 2, -sy / 2, z0)), M @ Vector((sx / 2, sy / 2, z0)),
                       M @ Vector((-sx / 2, sy / 2, z0)))
        r0, r1 = M @ Vector((0, -sy / 2, z0 + h)), M @ Vector((0, sy / 2, z0 + h))
        left = (M.to_3x3() @ Vector((-h, 0, sx / 2))).normalized()
        right = (M.to_3x3() @ Vector((h, 0, sx / 2))).normalized()
        self.poly([a, d, r1, r0], mat, left)
        self.poly([b, c_, r1, r0], mat, right)
        fwd = M.to_3x3() @ Vector((0, -1, 0))
        self.poly([a, b, r0], gm, fwd)
        self.poly([d, c_, r1], gm, -fwd)
        self.poly([a, b, c_, d], gm, (0, 0, -1))

    def pyramid(self, M, sx, sy, z0, h, mat):
        pts = [M @ Vector((x, y, z0)) for (x, y) in ((-sx / 2, -sy / 2), (sx / 2, -sy / 2), (sx / 2, sy / 2), (-sx / 2, sy / 2))]
        apex = M @ Vector((0, 0, z0 + h))
        c = M @ Vector((0, 0, z0 + h * 0.3))
        for e in range(4):
            mid = (pts[e] + pts[(e + 1) % 4] + apex) / 3
            self.poly([pts[e], pts[(e + 1) % 4], apex], mat, mid - c)

    def dome(self, M, r, z0, mat, segs=16, rings=6):
        prev = None
        c = M @ Vector((0, 0, z0))
        for i in range(rings + 1):
            phi = i / rings * math.pi / 2
            rr, zz = math.cos(phi) * r, math.sin(phi) * r
            ring = [M @ Vector((math.cos(k * math.tau / segs) * rr, math.sin(k * math.tau / segs) * rr, z0 + zz)) for k in range(segs)]
            if prev:
                for k in range(segs):
                    k2 = (k + 1) % segs
                    if i == rings:
                        mid = (prev[k] + prev[k2] + ring[0]) / 3
                        self.poly([prev[k], prev[k2], ring[0]], mat, mid - c)
                    else:
                        mid = (prev[k] + prev[k2] + ring[k] + ring[k2]) / 4
                        self.poly([prev[k], prev[k2], ring[k2], ring[k]], mat, mid - c)
            prev = ring if i < rings else prev

    def beam(self, a, b, w, h, mat, up=(0.0, 0.0, 1.0)):
        a, b = Vector(a), Vector(b)
        d = b - a
        L = d.length
        if L < 1e-4:
            return
        x = d / L
        y = Vector(up).cross(x)
        if y.length < 1e-4:
            y = Vector((0, 1, 0)).cross(x)
        y.normalize()
        z = x.cross(y).normalized()
        c = (a + b) / 2
        ra = [a + y * (sy * w / 2) + z * (sz * h / 2) for sy, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        rb = [b + y * (sy * w / 2) + z * (sz * h / 2) for sy, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        for k in range(4):
            k2 = (k + 1) % 4
            mid = (ra[k] + ra[k2] + rb[k] + rb[k2]) / 4
            self.poly([ra[k], ra[k2], rb[k2], rb[k]], mat, mid - c)
        self.poly(ra, mat, -x)
        self.poly(rb, mat, x)

    # --- Hilfen ------------------------------------------------------------------------------------------------
    def ground(self, x, y, w=1.0, d=1.0, rot=0.0):
        r = math.radians(rot)
        pts = [(x + math.cos(r) * u - math.sin(r) * v, y + math.sin(r) * u + math.cos(r) * v)
               for u in (-w / 2, 0, w / 2) for v in (-d / 2, 0, d / 2)]
        return min(self.kit.ground_fn(px, py) for px, py in pts)

    def frame(self, x, y, z, rot):
        return Matrix.Translation((x, y, z)) @ Matrix.Rotation(math.radians(rot), 4, "Z")

    def occupy(self, x, y, w, d, rot, val=1):
        if self.town:
            self.town.mark_rect(x, y, w, d, rot, val)
        self.kit.occupy(x, y, max(w, d) * 0.5)

    # --- Mausoleum ----------------------------------------------------------------------------------------------
    def mausoleum(self, x, y, rot=0.0, w=5.0, d=6.0, h=4.0, style="gable", mat="MI_Mausoleum", portico=None, finial=True,
                  steps=3, door_model="large_castle_door"):
        """Grabkapelle: Sockel mit Stufen, Körper mit Ecklisenen, Sockel- und Kranzgesims, Tür mit Gewände,
        Dach als Satteldach mit Giebel / Kuppel auf Tambour / Pyramide; „grand“: Säulenvorhalle, Treppe, Attika.
        Vorderseite = lokal -Y."""
        rng = self.rng
        g = self.ground(x, y, w + 2, d + 3, rot)
        M = self.frame(x, y, g, rot)
        base_h = 0.35 + 0.22 * steps
        stone, roof, door = mat, "MI_MausoleumRoof", "MI_CryptDoor"
        plinth = "MI_CryptStone"
        self.box(M, w + 1.2, d + 1.2, base_h + 0.8, plinth, z0=-0.8)
        for s in range(steps):                                   # Stufen vor dem Eingang
            sw = (w * 0.55 if style != "grand" else w * 0.8) + (steps - s) * 0.3
            depth = (steps - s) * 0.38
            self.box(M @ Matrix.Translation((0, -(d + 1.2) / 2 - depth / 2, 0)), sw, depth, 0.22 * (s + 1) + 0.13, plinth, z0=0.0)
        z0 = base_h
        self.box(M, w + 0.24, d + 0.24, 0.32, stone, z0=z0)          # Sockelgesims
        self.box(M, w, d, h, stone, z0=z0)
        for (sx, sy) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):          # Ecklisenen
            self.box(M @ Matrix.Translation((sx * (w / 2 - 0.12), sy * (d / 2 - 0.12), 0)), 0.5, 0.5, h, stone, z0=z0)
        for k in (-1, 1):                                            # Wandfelder an den Seiten (Blendnischen)
            for yy in ((-d / 4, d / 4) if d > 4.5 else (0.0,)):
                self.box(M @ Matrix.Translation((k * (w / 2 + 0.04), yy, 0)), 0.1, min(1.4, d / 3), h * 0.55, "MI_MausoleumDark",
                         z0=z0 + h * 0.2)
        # Tür mit Gewände und Sturz
        dw, dh = min(1.4, w * 0.36), min(2.6, h * 0.68)
        fy = -d / 2
        self.box(M @ Matrix.Translation((0, fy - 0.1, 0)), dw + 0.7, 0.24, dh + 0.55, stone, z0=z0)
        self.box(M @ Matrix.Translation((0, fy - 0.12, 0)), dw, 0.06, dh, "MI_BlackStone", z0=z0 + 0.02)
        if door_model:                                       # schwere Holztür mit Eisenbeschlägen (Fotoscan)
            ds = min(dh / 2.96, (dw + 0.35) / 2.01)
            dp = M @ Vector((0, fy - 0.05 - 0.17 * ds, z0))
            self.kit.ph(door_model, dp.x, dp.y, z=dp.z, rot=rot, s=ds)
        else:
            self.box(M @ Matrix.Translation((0, fy - 0.17, 0)), dw, 0.06, dh, door, z0=z0 + 0.02)
        self.box(M @ Matrix.Translation((0, fy - 0.2, 0)), dw + 1.0, 0.3, 0.3, stone, z0=z0 + dh + 0.5)
        # Kranzgesims
        ztop = z0 + h
        self.box(M, w + 0.6, d + 0.6, 0.38, stone, z0=ztop)
        ztop += 0.38
        if style == "gable" or style == "grand":
            rh = w * (0.32 if style == "gable" else 0.26)
            self.gable(M, w + 0.9, d + 0.9, ztop, rh, roof, gable_mat=stone)
            if finial:
                apex = M @ Vector((0, -(d + 0.9) / 2 + 0.2, ztop + rh))
                self._finial_cross(apex, rot, 0.9)
        elif style == "dome":
            self.box(M, w * 0.78, d * 0.78, 0.5, stone, z0=ztop)
            self.cyl(M, min(w, d) * 0.36, ztop + 0.5, 0.9, stone, sides=16)
            self.dome(M, min(w, d) * 0.38, ztop + 1.4, roof, segs=16, rings=6)
            if finial:
                self._finial_cross(M @ Vector((0, 0, ztop + 1.4 + min(w, d) * 0.38)), rot, 0.8)
        elif style == "pyramid":
            self.pyramid(M, w + 0.5, d + 0.5, ztop, max(w, d) * 0.6, roof)
        if style == "grand" or portico:
            # Säulenvorhalle mit Gebälk und Giebel
            pc = 4 if w > 7 else 2
            py = -d / 2 - 1.6
            for i in range(pc):
                px = -w * 0.38 + i * (w * 0.76 / max(pc - 1, 1))
                Mc = M @ Matrix.Translation((px, py, 0))
                self.box(Mc, 0.7, 0.7, 0.3, stone, z0=z0)
                self.cyl(Mc, 0.26, z0 + 0.3, h - 0.6, stone, sides=12, r_top=0.23)
                self.box(Mc, 0.62, 0.62, 0.3, stone, z0=z0 + h - 0.3)
            self.box(M @ Matrix.Translation((0, py + 0.35, 0)), w + 0.2, 2.4, 0.45, stone, z0=z0 + h)
            self.gable(M @ Matrix.Translation((0, py + 0.6, 0)), w + 0.4, 2.6, z0 + h + 0.45, w * 0.2, roof, gable_mat=stone)
            self.box(M @ Matrix.Translation((0, -(d + 1.2) / 2 - 0.9, 0)), w + 0.8, 3.6, base_h + 0.8, plinth, z0=-0.8)
        self.occupy(x, y, w + 1.6, d + (5.0 if (style == "grand" or portico) else 2.6), rot)
        self.count += 1
        return {"x": x, "y": y, "z": g, "rot": rot, "door": tuple(M @ Vector((0, fy - 0.6, z0)))}

    def _finial_cross(self, p, rot, s):
        r = math.radians(rot)
        ax = Vector((math.cos(r), math.sin(r), 0))
        self.beam(p, p + Vector((0, 0, s)), 0.12 * s, 0.12 * s, "MI_Mausoleum")
        self.beam(p + Vector((0, 0, s * 0.65)) - ax * s * 0.3, p + Vector((0, 0, s * 0.65)) + ax * s * 0.3, 0.1 * s, 0.1 * s,
                  "MI_Mausoleum")

    # --- Gräber -----------------------------------------------------------------------------------------------
    def cross(self, x, y, rot=0.0, h=1.3, mat="MI_GraveStone", tilt=0.0):
        g = self.ground(x, y, 0.6, 0.4, rot)
        M = self.frame(x, y, g, rot) @ Matrix.Rotation(math.radians(tilt), 4, "X")
        self.box(M, 0.55, 0.35, 0.3, mat, z0=-0.1)
        self.box(M, 0.16, 0.14, h, mat, z0=0.2)
        self.box(M @ Matrix.Translation((0, 0, 0)), 0.7, 0.13, 0.15, mat, z0=0.2 + h * 0.62)
        self.occupy(x, y, 0.8, 0.6, rot)

    def slab(self, x, y, rot=0.0, mat="MI_GraveStone", head=True):
        g = self.ground(x, y, 1.0, 2.2, rot)
        M = self.frame(x, y, g, rot)
        self.box(M, 1.0, 2.1, 0.32, mat, z0=-0.12)
        self.box(M, 0.86, 1.95, 0.08, "MI_MausoleumDark", z0=0.2)
        if head:
            self.box(M @ Matrix.Translation((0, 1.0, 0)), 0.95, 0.18, 0.95, mat, z0=0.0)
            self.box(M @ Matrix.Translation((0, 1.0, 0)), 0.75, 0.2, 0.2, mat, z0=0.95, taper=0.6)
        self.occupy(x, y, 1.2, 2.4, rot)

    def obelisk(self, x, y, h=3.2, mat="MI_GraveStone"):
        g = self.ground(x, y, 1.2, 1.2)
        M = self.frame(x, y, g, self.rng.uniform(0, 90))
        self.box(M, 1.1, 1.1, 0.5, mat, z0=-0.2)
        self.box(M, 0.8, 0.8, 0.45, mat, z0=0.3)
        self.box(M, 0.5, 0.5, h, mat, z0=0.75, taper=0.62)
        self.pyramid(M, 0.31, 0.31, 0.75 + h, 0.35, mat)
        self.occupy(x, y, 1.3, 1.3, 0)

    def plot(self, x, y, rot, w=3.2, d=3.6):
        """Familiengrab: Steinrahmen, eisernes Gitter, Grabplatte oder Kreuz darin."""
        r = math.radians(rot)
        ux, uy = math.cos(r), math.sin(r)
        vx, vy = -math.sin(r), math.cos(r)
        pts = [(x + ux * a + vx * b, y + uy * a + vy * b) for a, b in ((-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, d / 2), (-w / 2, d / 2))]
        self.iron_fence(pts + [pts[0]], h=0.95, gap_at=0, gap_w=0.9)
        if self.rng.random() < 0.5:
            self.slab(x, y, rot)
        else:
            self.cross(x + vx * (d / 2 - 0.7), y + vy * (d / 2 - 0.7), rot, h=1.6)
        self.occupy(x, y, w + 0.4, d + 0.4, rot)

    # --- Mauern, Zäune, Tore --------------------------------------------------------------------------------------
    def plain_wall(self, line, height=3.0, T=0.7, gaps=(), gap_w=4.0, mat="MI_CemeteryWall", seg=2.5, buttress=8.0, closed=False):
        pts = list(line) + ([line[0]] if closed else [])
        run = 0.0
        for (ax, ay), (bx, by) in zip(pts[:-1], pts[1:]):
            L = math.hypot(bx - ax, by - ay)
            rot = math.degrees(math.atan2(by - ay, bx - ax))
            n = max(1, int(round(L / seg)))
            for k in range(n):
                cx, cy = ax + (bx - ax) * (k + 0.5) / n, ay + (by - ay) * (k + 0.5) / n
                if any(math.hypot(cx - gx, cy - gy) < gap_w / 2 + L / n / 2 for gx, gy in gaps):
                    continue
                g = self.ground(cx, cy, L / n, T, rot)
                M = self.frame(cx, cy, g, rot)
                sl = L / n + 0.02
                self.box(M, sl, T, height + 0.6, mat, z0=-0.6)
                self.box(M, sl, T + 0.22, 0.18, "MI_MausoleumDark", z0=height)                 # Abdeckplatte
                self.gable(M @ Matrix.Rotation(math.pi / 2, 4, "Z"), T + 0.1, sl, height + 0.18, 0.22, "MI_MausoleumDark")
                run += L / n
                if run >= buttress:
                    run = 0.0
                    self.box(M, 0.7, T + 0.9, height * 0.75 + 0.6, mat, z0=-0.6, taper=0.85)
                if self.town:
                    self.town.mark_rect(cx, cy, L / n + 0.3, T + 0.8, rot, 6)

    def iron_fence(self, pts, h=1.6, spacing=0.14, gap_at=None, gap_w=1.2, mat="MI_IronFence"):
        """Eisengitter: senkrechte Stäbe mit Spitzen, zwei Riegel; gap_at = Index der Kante mit Lücke (Pforte)."""
        for i, ((ax, ay), (bx, by)) in enumerate(zip(pts[:-1], pts[1:])):
            L = math.hypot(bx - ax, by - ay)
            if L < 0.05:
                continue
            tx, ty = (bx - ax) / L, (by - ay) / L
            n = max(1, int(L / spacing))
            for k in range(n + 1):
                t = k / n
                x, y = ax + (bx - ax) * t, ay + (by - ay) * t
                if gap_at == i and abs(t - 0.5) * L < gap_w / 2:
                    continue
                g = self.kit.ground_fn(x, y)
                self.beam((x, y, g - 0.1), (x, y, g + h), 0.03, 0.03, mat)
                self.pyramid(self.frame(x, y, g + h, 0), 0.06, 0.06, 0.0, 0.12, mat)
            for zz in (0.15, h - 0.15):
                if gap_at == i:
                    m1 = (ax + tx * (L / 2 - gap_w / 2), ay + ty * (L / 2 - gap_w / 2))
                    m2 = (ax + tx * (L / 2 + gap_w / 2), ay + ty * (L / 2 + gap_w / 2))
                    segs = [((ax, ay), m1), (m2, (bx, by))]
                else:
                    segs = [((ax, ay), (bx, by))]
                for (p, q) in segs:
                    self.beam((p[0], p[1], self.kit.ground_fn(*p) + zz), (q[0], q[1], self.kit.ground_fn(*q) + zz), 0.05, 0.04, mat)
            if self.town:
                self.town.mark_rect((ax + bx) / 2, (ay + by) / 2, L, 0.4, math.degrees(math.atan2(ty, tx)), 6)

    def gate_pillars(self, x, y, rot, width=4.0, h=4.2, mat="MI_CemeteryWall", arch=True, gate=True):
        """Torpfeiler mit Deckplatten und Kugeln, Bogen darüber, offene Gitterflügel."""
        r = math.radians(rot)
        ux, uy = math.cos(r), math.sin(r)
        vx, vy = -math.sin(r), math.cos(r)
        for s in (-1, 1):
            px, py = x + ux * s * (width / 2 + 0.55), y + uy * s * (width / 2 + 0.55)
            g = self.ground(px, py, 1.2, 1.2, rot)
            M = self.frame(px, py, g, rot)
            self.box(M, 1.1, 1.1, h + 0.6, mat, z0=-0.6)
            self.box(M, 1.35, 1.35, 0.25, "MI_MausoleumDark", z0=h)
            self.box(M, 0.9, 0.9, 0.25, mat, z0=h + 0.25, taper=0.7)
            self.cyl(M, 0.32, h + 0.5, 0.5, "MI_MausoleumDark", sides=10, r_top=0.05)
        g = self.ground(x, y, width, 1.0, rot)
        if arch:
            prev = None
            for k in range(13):
                a = math.pi * k / 12
                px = x + ux * math.cos(a) * (width / 2 + 0.2)
                py = y + uy * math.cos(a) * (width / 2 + 0.2)
                pz = g + h + 0.2 + math.sin(a) * width * 0.35
                cur = Vector((px, py, pz))
                if prev is not None:
                    self.beam(prev, cur, 0.5, 0.4, mat, up=(vx, vy, 0))
                prev = cur
        if gate:
            for s in (-1, 1):                                    # Flügel nach innen geöffnet
                hx, hy = x + ux * s * (width / 2 - 0.05), y + uy * s * (width / 2 - 0.05)
                ang = r + math.pi / 2 * 0.0
                ex, ey = hx + vx * width * 0.48 - ux * s * width * 0.12, hy + vy * width * 0.48 - uy * s * width * 0.12
                self.iron_fence([(hx, hy), (ex, ey)], h=h * 0.72, spacing=0.16)
        if self.town:
            self.town.mark_rect(x, y, width + 2.4, 1.6, rot, 2)

    # --- Pfahlbauten (Echsenmenschen), Stege, Gestelle ------------------------------------------------------------
    def log(self, a, b, r, mat="MI_LogWood", sides=7):
        """Rundholz zwischen zwei Punkten."""
        a, b = Vector(a), Vector(b)
        d = b - a
        L = d.length
        if L < 1e-4:
            return
        z = d / L
        x = Vector((1, 0, 0)) if abs(z.x) < 0.9 else Vector((0, 1, 0))
        y = z.cross(x).normalized()
        x = y.cross(z).normalized()
        ra = [a + (x * math.cos(k * math.tau / sides) + y * math.sin(k * math.tau / sides)) * r for k in range(sides)]
        rb = [b + (x * math.cos(k * math.tau / sides) + y * math.sin(k * math.tau / sides)) * r for k in range(sides)]
        self.tube([ra, rb], mat, cap_end=True)

    def stilt_hut(self, x, y, rot=0.0, r=3.0, deck_z=None, wall_h=2.2, roof_h=3.2, door=True, chief=False, stairs=True):
        """Rundhütte auf Pfählen: Plattform aus Bohlen mit Geländer, Wände aus senkrechten Stämmen, Kegeldach aus
        Stroh mit Überstand, Treppe zur Tür (Vorderseite = lokal -Y). deck_z: Höhe der Plattform (sonst Boden + 1,4)."""
        g = self.ground(x, y, r * 2, r * 2, rot)
        dz = (g + 1.4) if deck_z is None else deck_z
        M = self.frame(x, y, 0.0, rot)
        rp = r + 1.1
        n_st = 6 if not chief else 8
        for k in range(n_st):
            a = k * math.tau / n_st + 0.3
            p = M @ Vector((math.cos(a) * (rp - 0.4), math.sin(a) * (rp - 0.4), 0))
            self.log((p.x, p.y, min(g, dz) - 1.2), (p.x, p.y, dz), 0.16)
        self.log((x, y, min(g, dz) - 1.2), (x, y, dz), 0.2)
        sides = 10
        ring = [M @ Vector((math.cos(k * math.tau / sides) * rp, math.sin(k * math.tau / sides) * rp, dz)) for k in range(sides)]
        ring_lo = [p - Vector((0, 0, 0.18)) for p in ring]
        self.poly(ring, "MI_Planks", (0, 0, 1))
        self.poly(ring_lo, "MI_Planks", (0, 0, -1))
        c = M @ Vector((0, 0, dz))
        for k in range(sides):
            k2 = (k + 1) % sides
            mid = (ring[k] + ring[k2]) / 2
            self.poly([ring_lo[k], ring_lo[k2], ring[k2], ring[k]], "MI_Planks", mid - c)
        front = -math.pi / 2                                   # lokal -Y
        for k in range(sides):
            a0, a1 = k * math.tau / sides, (k + 1) * math.tau / sides
            mid_a = (a0 + a1) / 2
            if abs(math.atan2(math.sin(mid_a - front), math.cos(mid_a - front))) < 0.5:
                continue
            p0 = M @ Vector((math.cos(a0) * (rp - 0.1), math.sin(a0) * (rp - 0.1), dz))
            p1 = M @ Vector((math.cos(a1) * (rp - 0.1), math.sin(a1) * (rp - 0.1), dz))
            self.log(p0, p0 + Vector((0, 0, 0.95)), 0.05)
            self.log(p0 + Vector((0, 0, 0.9)), p1 + Vector((0, 0, 0.9)), 0.045)
        n_logs = int(math.tau * r / 0.24)
        for k in range(n_logs):
            a = k * math.tau / n_logs
            if door and abs(math.atan2(math.sin(a - front), math.cos(a - front))) < 0.7 / r:
                continue
            p = M @ Vector((math.cos(a) * r, math.sin(a) * r, dz))
            self.log(p, p + Vector((0, 0, wall_h + 0.1 * math.sin(k * 1.7))), 0.12, sides=6)
        if door:
            self.log(M @ Vector((-0.75, -r, dz + 1.95)), M @ Vector((0.75, -r, dz + 1.95)), 0.1)
            self.poly([M @ Vector((-0.65, -r + 0.35, dz + 0.01)), M @ Vector((0.65, -r + 0.35, dz + 0.01)),
                       M @ Vector((0.65, -r + 0.35, dz + 1.9)), M @ Vector((-0.65, -r + 0.35, dz + 1.9))], "MI_BlackStone",
                      M.to_3x3() @ Vector((0, -1, 0)))
        roof_r = r + 1.0
        base_z = dz + wall_h - 0.15
        segs = 18
        ring_r = [M @ Vector((math.cos(k * math.tau / segs) * roof_r, math.sin(k * math.tau / segs) * roof_r,
                              base_z - 0.25 * (1 + math.sin(k * 2.3) * 0.2))) for k in range(segs)]
        apex = M @ Vector((0, 0, base_z + roof_h))
        centre = M @ Vector((0, 0, base_z))
        for k in range(segs):
            k2 = (k + 1) % segs
            mid = (ring_r[k] + ring_r[k2] + apex) / 3
            self.poly([ring_r[k], ring_r[k2], apex], "MI_Thatch", mid - centre)
            self.poly([ring_r[k], ring_r[k2], apex - Vector((0, 0, 0.12))], "MI_Thatch", centre - mid)
        self.log(apex - Vector((0, 0, 0.6)), apex + Vector((0, 0, 0.5)), 0.12)
        top = M @ Vector((0, -rp, dz))
        foot = M @ Vector((0, -rp - max(1.2, (dz - g) * 1.1), 0))
        foot.z = min(self.kit.ground_fn(foot.x, foot.y), dz - 0.3)
        if stairs:
            sideways = M.to_3x3() @ Vector((0.55, 0, 0))
            self.log(top + sideways, foot + sideways, 0.06)
            self.log(top - sideways, foot - sideways, 0.06)
            n_r = max(2, int((dz - foot.z) / 0.32))
            for k in range(1, n_r):
                p = foot.lerp(top, k / n_r)
                self.log(p - sideways, p + sideways, 0.045)
        if chief:
            q = M @ Vector((0, -r - 0.15, dz + 2.3))
            self.cyl(self.frame(q.x, q.y, q.z, rot), 0.22, 0.0, 0.3, "MI_Bone", sides=8, r_top=0.12)
        self.occupy(x, y, rp * 2 + 0.6, rp * 2 + 2.5, rot)
        self.count += 1
        return {"x": x, "y": y, "deck": dz, "door": tuple(foot)}

    def boardwalk(self, pts, z, width=1.6, post_every=2.4):
        """Bohlensteg auf Pfählen in Höhe z entlang einer Polylinie (Bretter quer zur Laufrichtung)."""
        for (ax, ay), (bx, by) in zip(pts[:-1], pts[1:]):
            L = math.hypot(bx - ax, by - ay)
            if L < 0.1:
                continue
            tx, ty = (bx - ax) / L, (by - ay) / L
            nx, ny = -ty, tx
            n = max(1, int(L / 0.32))
            for k in range(n):
                cx, cy = ax + tx * (k + 0.5) * L / n, ay + ty * (k + 0.5) * L / n
                jitter = (self.rng.random() - 0.5) * 0.04
                M = self.frame(cx, cy, z + jitter, math.degrees(math.atan2(ty, tx)))
                self.box(M, L / n - 0.03, width * self.rng.uniform(0.94, 1.0), 0.07, "MI_Planks", z0=-0.07)
            m = max(1, int(L / post_every))
            for k in range(m + 1):
                px, py = ax + tx * k * L / m, ay + ty * k * L / m
                g = self.kit.ground_fn(px, py)
                for s in (-1, 1):
                    qx, qy = px + nx * s * (width / 2 - 0.1), py + ny * s * (width / 2 - 0.1)
                    self.log((qx, qy, min(g, z) - 1.0), (qx, qy, z - 0.07), 0.08, sides=6)
            for s in (-1, 1):
                self.beam((ax + nx * s * (width / 2 - 0.1), ay + ny * s * (width / 2 - 0.1), z - 0.15),
                          (bx + nx * s * (width / 2 - 0.1), by + ny * s * (width / 2 - 0.1), z - 0.15), 0.12, 0.14, "MI_LogWood")
            if self.town:
                self.town.mark_rect((ax + bx) / 2, (ay + by) / 2, L, width + 0.4, math.degrees(math.atan2(ty, tx)), 2)

    def drying_rack(self, x, y, rot=0.0, w=3.0, h=2.0):
        """Trockengestell (Fisch, Häute): zwei A-Böcke, Querstangen, hängende Bündel."""
        r = math.radians(rot)
        ux, uy = math.cos(r), math.sin(r)
        g = self.kit.ground_fn(x, y)
        for s in (-1, 1):
            bx, by = x + ux * s * w / 2, y + uy * s * w / 2
            for t in (-1, 1):
                self.log((bx - uy * t * 0.5, by + ux * t * 0.5, g - 0.2), (bx, by, g + h), 0.05, sides=5)
        for zz in (h - 0.05, h - 0.6):
            self.log((x - ux * w / 2, y - uy * w / 2, g + zz), (x + ux * w / 2, y + uy * w / 2, g + zz), 0.04, sides=5)
        for k in range(6):
            t = -w / 2 + 0.3 + k * (w - 0.6) / 5
            self.box(self.frame(x + ux * t, y + uy * t, g + h - 0.75, rot + 90), 0.06, 0.22, 0.6, "MI_Thatch", z0=0.0, taper=0.6)
        self.occupy(x, y, w + 0.5, 1.5, rot)

    def totem(self, x, y, h=4.0, skulls=3):
        """Totempfahl mit Querholz, Hörnern und Schädeln (Echsenmenschen)."""
        g = self.kit.ground_fn(x, y)
        self.log((x, y, g - 0.5), (x, y, g + h), 0.18)
        a = self.rng.uniform(0, math.tau)
        ux, uy = math.cos(a), math.sin(a)
        self.log((x - ux * 0.9, y - uy * 0.9, g + h * 0.78), (x + ux * 0.9, y + uy * 0.9, g + h * 0.78), 0.08)
        for k in range(skulls):
            M = self.frame(x + uy * 0.2, y - ux * 0.2, g + h * (0.45 + 0.15 * k), math.degrees(a))
            self.box(M, 0.26, 0.3, 0.24, "MI_Bone", z0=0.0, taper=0.8)
        for s in (-1, 1):
            p = Vector((x + ux * s * 0.9, y + uy * s * 0.9, g + h * 0.78))
            self.log(p, p + Vector((ux * s * 0.3, uy * s * 0.3, 0.7)), 0.05, mat="MI_Bone", sides=5)
        self.occupy(x, y, 0.8, 0.8, 0)

    # --- Zwergenbauten: Felsentor, Stollenmundloch ------------------------------------------------------------------
    def dwarf_gate(self, x, y, rot=0.0, W=26.0, H=24.0, depth=10.0, z=None, stairs=6):
        """Monumentales Felsentor der Zwerge: Fassade aus Quadern (in den Fels gesetzt), dreifach gestuftes Portal,
        zweiflügeliges Steintor mit Goldbändern, Säulen mit Kapitellen, gestufter Giebel mit Emblem, Treppe mit Podest.
        Vorderseite = lokal -Y; die Fassade reicht `depth` Meter in den Fels."""
        g = self.ground(x, y - 0.0, W, 4.0, rot) if z is None else z
        M = self.frame(x, y, g, rot)
        st, gold, dark = "MI_DwarfStone", "MI_DwarfGold", "MI_BlackStone"
        plat = 0.3 * stairs
        # Fundament und Fassadenblock
        self.box(M @ Matrix.Translation((0, depth / 2, 0)), W, depth, H + 2.0, st, z0=-2.0)
        # Treppe und Podest davor
        for k in range(stairs):
            d = (stairs - k) * 0.55
            self.box(M @ Matrix.Translation((0, -1.6 - d / 2 - 2.2, 0)), W * 0.62 - k * 0.6, d, 0.3 * (k + 1) + 1.0, st, z0=-1.0)
        self.box(M @ Matrix.Translation((0, -1.6, 0)), W * 0.7, 4.4, plat + 1.0, st, z0=-1.0)
        # Gestuftes Portal (drei Rahmen, nach innen zurückspringend)
        ow, oh = 9.0, 13.0
        for i, (grow, dy) in enumerate(((3.0, -1.2), (1.6, -0.6), (0.0, 0.0))):
            fw, fh = ow + 2 * grow, oh + grow
            jamb = 1.4
            for s in (-1, 1):
                self.box(M @ Matrix.Translation((s * (fw / 2 + jamb / 2), dy, 0)), jamb, 1.2, fh + plat, st, z0=0.0)
            self.box(M @ Matrix.Translation((0, dy, 0)), fw + 2 * jamb, 1.2, 1.6, st, z0=plat + fh)
            if i == 0:                                    # Runenband im äußeren Sturz
                for k in range(9):
                    self.box(M @ Matrix.Translation((-fw / 2 + 1.2 + k * (fw - 2.4) / 8, dy - 0.62, 0)), 0.5, 0.06, 0.7, gold,
                             z0=plat + fh + 0.45)
        # Torflügel (leicht zurückgesetzt), Goldbänder, Mittelfuge
        for s in (-1, 1):
            leaf = M @ Matrix.Translation((s * ow / 4, 0.45, 0))
            self.box(leaf, ow / 2 - 0.08, 0.6, oh, st, z0=plat)
            for zz in (1.2, oh * 0.38, oh * 0.62, oh - 1.4):
                self.box(leaf @ Matrix.Translation((0, -0.32, 0)), ow / 2 - 0.4, 0.08, 0.35, gold, z0=plat + zz)
            self.cyl(leaf @ Matrix.Translation((-s * (ow / 4 - 0.7), -0.38, 0)) @ Matrix.Rotation(math.pi / 2, 4, "X"),
                     0.45, -0.05, 0.12, gold, sides=12)       # Türring
        self.box(M @ Matrix.Translation((0, 0.12, 0)), 0.12, 0.2, oh, dark, z0=plat)
        # Säulen vor der Fassade
        for s in (-1, 1):
            for px in (ow / 2 + 4.8, ow / 2 + 8.6):
                Pm = M @ Matrix.Translation((s * px, -2.4, 0))
                self.box(Pm, 2.2, 2.2, 0.8, st, z0=plat)
                self.box(Pm, 1.6, 1.6, oh + 1.4, st, z0=plat + 0.8)
                for k in range(4):                         # Kannelur-Andeutung: dunkle Rillen
                    self.box(Pm @ Matrix.Rotation(k * math.pi / 2, 4, "Z") @ Matrix.Translation((0, -0.81, 0)), 0.18, 0.04,
                             oh + 1.0, dark, z0=plat + 1.0)
                self.box(Pm, 2.4, 2.4, 0.9, st, z0=plat + oh + 2.2)
                self.box(Pm, 2.0, 2.0, 0.5, gold, z0=plat + oh + 3.1)
        # Gebälk über den Säulen und gestufter Giebel mit Emblem
        self.box(M @ Matrix.Translation((0, -2.4, 0)), W - 1.0, 3.2, 1.4, st, z0=plat + oh + 3.6)
        for k in range(4):
            self.box(M @ Matrix.Translation((0, -1.2 + k * 0.4, 0)), W * (0.78 - k * 0.17), 2.0, 1.3, st, z0=plat + oh + 5.0 + k * 1.3)
        self.cyl(M @ Matrix.Translation((0, -2.3, plat + oh + 7.2)) @ Matrix.Rotation(math.pi / 2, 4, "X"), 1.7, -0.2, 0.4, gold, sides=20)
        self.cyl(M @ Matrix.Translation((0, -2.55, plat + oh + 7.2)) @ Matrix.Rotation(math.pi / 2, 4, "X"), 1.1, -0.2, 0.3, st, sides=6)
        self.occupy(x, y - 4.0, W + 2.0, 14.0, rot)
        self.count += 1
        top = M @ Vector((0, -1.6, plat))
        return {"platform": tuple(top), "front": tuple(M @ Vector((0, -10.0, 0)))}

    def mine_adit(self, x, y, rot=0.0, w=3.4, h=3.2, depth=9.0):
        """Stollenmundloch: Türstock aus Rundhölzern (Kappe auf zwei Stempeln), ausgebauter Stollen mit Bodenbrettern,
        dunkles Ende, Schienen davor (Vorderseite = lokal -Y)."""
        g = self.ground(x, y, w + 2, 2.0, rot)
        M = self.frame(x, y, g, rot)
        dark, plank = "MI_BlackStone", "MI_Planks"
        for k in range(int(depth / 1.5) + 1):              # Türstöcke alle 1,5 m
            yy = k * 1.5
            for s in (-1, 1):
                a = M @ Vector((s * w / 2, yy, -0.2))
                b = M @ Vector((s * w / 2 * 0.9, yy, h))
                self.log(a, b, 0.17)
            self.log(M @ Vector((-w / 2 - 0.3, yy, h)), M @ Vector((w / 2 + 0.3, yy, h)), 0.18)
        # Verzug (Bretter) an Wänden und Decke, Bodenbelag
        self.box(M @ Matrix.Translation((0, depth / 2, 0)), w + 0.6, depth, 0.1, plank, z0=-0.05)
        for s in (-1, 1):
            self.box(M @ Matrix.Translation((s * (w / 2 + 0.25), depth / 2, 0)), 0.12, depth, h, plank, z0=0.0)
        self.box(M @ Matrix.Translation((0, depth / 2, 0)), w + 0.8, depth, 0.12, plank, z0=h + 0.2)
        self.box(M @ Matrix.Translation((0, depth + 0.2, 0)), w + 0.8, 0.3, h + 0.4, dark, z0=-0.2)
        self.occupy(x, y + depth / 2, w + 2.0, depth + 2.0, rot)
        self.count += 1
        return {"mouth": tuple(M @ Vector((0, -0.5, 0)))}

    # --- Elfenbauten: Riesenbäume, Baumplattformen, Ringpavillons, Hängebrücken, Wendeltreppen ----------------------
    def _P(self, x, y, a, r, z):
        return Vector((x + math.cos(a) * r, y + math.sin(a) * r, z))

    def giant_trunk(self, x, y, h, r0, r1, flare=1.8, roots=7, segs=22, rings=20, twist=0.5):
        """Mächtiger Stamm (Höhe h, Radius r0 unten → r1 oben), leicht gedreht, mit Rindenwülsten und Wurzelanläufen.
        Rückgabe: (Bodenhöhe, Funktion radius(z))."""
        g = self.ground(x, y, r0 * 2, r0 * 2, 0) - 0.6
        seed = self.rng.uniform(0, math.tau)

        def radius_at(t):
            return r0 + (r1 - r0) * min(max(t, 0.0), 1.0) ** 0.7

        all_rings = []
        for i in range(rings + 1):
            t = (i / rings) ** 1.5
            z = g + h * t
            r = radius_at(t)
            ring = []
            for k in range(segs):
                a = k / segs * math.tau + twist * t
                bump = 1.0 + 0.06 * math.sin(a * 5 + t * 11 + seed) + 0.04 * math.sin(a * 13 - t * 7)
                root = flare * (1 - t / 0.2) ** 2 * max(0.0, math.cos(roots * (a + seed))) ** 6 if t < 0.2 else 0.0
                ring.append(self._P(x, y, a, r * bump + root, z))
            all_rings.append(ring)
        self.tube(all_rings, "MI_Bark", cap_end=True)
        self.occupy(x, y, (r0 + flare) * 2, (r0 + flare) * 2, 0)
        return g, (lambda zz: radius_at((zz - g) / h) * 1.06)

    def tree_platform(self, x, y, z, r_in, r_out, openings=(), inner_openings=(), sides=28, braces=7, rail=True,
                      inner_rail=True, r_trunk=None):
        """Ringförmige Bohlenplattform um einen Stamm in Höhe z (Innenradius r_in), Streben zum Stamm, Geländer außen
        (und innen, falls zwischen Stamm und Deck eine Wendeltreppe frei bleibt). openings: Winkel (Grad) der Lücken."""
        def gap(a, ops, r):
            return any(abs(math.atan2(math.sin(a - math.radians(o)), math.cos(a - math.radians(o)))) < 0.75 / r for o in ops)
        for k in range(sides):
            a0, a1 = k / sides * math.tau, (k + 1) / sides * math.tau
            top = [self._P(x, y, a0, r_in, z), self._P(x, y, a1, r_in, z), self._P(x, y, a1, r_out, z), self._P(x, y, a0, r_out, z)]
            self.poly(top, "MI_Planks", (0, 0, 1))
            bot = [p - Vector((0, 0, 0.22)) for p in top]
            self.poly(bot, "MI_Planks", (0, 0, -1))
            am = (a0 + a1) / 2
            out = Vector((math.cos(am), math.sin(am), 0))
            self.poly([bot[3], bot[2], top[2], top[3]], "MI_LogWood", out)
            self.poly([bot[0], bot[1], top[1], top[0]], "MI_LogWood", -out)
            if rail and not gap(am, openings, r_out):
                p0 = self._P(x, y, a0, r_out - 0.12, z)
                p1 = self._P(x, y, a1, r_out - 0.12, z)
                self.log(p0, p0 + Vector((0, 0, 1.05)), 0.055, sides=6)
                self.log(p0 + Vector((0, 0, 1.0)), p1 + Vector((0, 0, 1.0)), 0.05, sides=6)
                self.log(p0 + Vector((0, 0, 0.5)), p1 + Vector((0, 0, 0.5)), 0.035, sides=5)
            if inner_rail and not gap(am, inner_openings, r_in):
                q0 = self._P(x, y, a0, r_in + 0.1, z)
                q1 = self._P(x, y, a1, r_in + 0.1, z)
                self.log(q0, q0 + Vector((0, 0, 1.0)), 0.05, sides=6)
                self.log(q0 + Vector((0, 0, 0.95)), q1 + Vector((0, 0, 0.95)), 0.045, sides=6)
        rt = r_trunk if r_trunk is not None else r_in - 0.1
        for k in range(braces):                                  # Streben schräg zum Stamm
            a = (k + 0.5) / braces * math.tau
            self.log(self._P(x, y, a, rt, z - 3.2), self._P(x, y, a, r_out - 0.5, z - 0.22), 0.13)
            self.log(self._P(x, y, a, rt, z - 0.3), self._P(x, y, a, r_out - 0.3, z - 0.3), 0.11)
        self.count += 1

    def ring_pavilion(self, x, y, z, r_in, r_out, h=3.0, openings=(), sides=24, wall_mat="MI_Planks"):
        """Pavillon ringsum am Stamm: schlanke Pfosten, Brüstungen, geschwungenes Dach mit aufgebogener Traufe."""
        rp = r_out - 0.6
        def gap(a):
            return any(abs(math.atan2(math.sin(a - math.radians(o)), math.cos(a - math.radians(o)))) < 1.0 / rp for o in openings)
        for k in range(0, sides, 2):
            a = k / sides * math.tau
            p = self._P(x, y, a, rp, z)
            self.log(p, p + Vector((0, 0, h)), 0.11, sides=8)
        for k in range(sides):
            a0, a1 = k / sides * math.tau, (k + 1) / sides * math.tau
            am = (a0 + a1) / 2
            if not gap(am):                                   # Brüstung (Bretter) zwischen den Pfosten
                b0, b1 = self._P(x, y, a0, rp, z), self._P(x, y, a1, rp, z)
                out = Vector((math.cos(am), math.sin(am), 0))
                self.poly([b0, b1, b1 + Vector((0, 0, 1.0)), b0 + Vector((0, 0, 1.0))], wall_mat, out)
                self.poly([b0, b1, b1 + Vector((0, 0, 1.0)), b0 + Vector((0, 0, 1.0))], wall_mat, -out)
            # Dach: geschwungen vom Stamm zur Traufe, Traufe aufgebogen
            prof = [(r_in - 0.05, h + 1.6), (r_in + (r_out - r_in) * 0.45, h + 0.75), (r_out + 0.35, h - 0.1), (r_out + 0.95, h + 0.12)]
            for j in range(len(prof) - 1):
                (ra, za), (rb, zb) = prof[j], prof[j + 1]
                q = [self._P(x, y, a0, ra, z + za), self._P(x, y, a1, ra, z + za), self._P(x, y, a1, rb, z + zb), self._P(x, y, a0, rb, z + zb)]
                n_up = Vector((math.cos(am) * (za - zb), math.sin(am) * (za - zb), rb - ra)).normalized()
                self.poly(q, "MI_Thatch" if wall_mat == "MI_Planks" else "MI_MausoleumRoof", n_up)
                self.poly([v - Vector((0, 0, 0.08)) for v in q], "MI_Planks", -n_up)
        self.count += 1

    def rope_bridge(self, p0, p1, width=1.5, sag=None, plank=0.36):
        """Hängebrücke zwischen zwei Punkten (x, y, z): Bohlen auf durchhängender Linie, Seile, Hänger."""
        p0, p1 = Vector(p0), Vector(p1)
        d = p1 - p0
        L = math.hypot(d.x, d.y)
        if L < 1.0:
            return
        sag = 0.05 * L if sag is None else sag
        heading = math.atan2(d.y, d.x)
        side = Vector((-math.sin(heading), math.cos(heading), 0))

        def at(t, s=1.0):
            p = p0.lerp(p1, t)
            p.z -= sag * s * 4 * t * (1 - t)
            return p
        n = max(2, int(L / plank))
        for i in range(n):
            t0, t1 = i / n, (i + 0.82) / n
            a, b = at(t0), at(t1)
            mid = (a + b) / 2
            pitch = math.atan2(b.z - a.z, (b - a).xy.length)
            M = Matrix.Translation(mid) @ Matrix.Rotation(heading, 4, "Z") @ Matrix.Rotation(-pitch, 4, "Y")
            self.box(M, (b - a).length, width * self.rng.uniform(0.95, 1.0), 0.06, "MI_Planks", z0=-0.06)
        m = max(4, n // 2)
        for s in (-1, 1):
            off = side * (s * width / 2)
            prev_r = prev_g = None
            for i in range(m + 1):
                t = i / m
                g_ = at(t) + off + Vector((0, 0, -0.04))
                r_ = at(t, 0.65) + off + Vector((0, 0, 1.05))
                if prev_r is not None:
                    self.log(prev_r, r_, 0.035, sides=5)
                    self.log(prev_g, g_, 0.03, sides=5)
                if 0 < i < m and i % 2 == 0:
                    self.log(g_, r_, 0.02, sides=4)
                prev_r, prev_g = r_, g_
        self.count += 1

    def spiral_stair(self, x, y, z0, z1, a0_deg, r_fn, width=1.35, rise=0.27, tread=0.5, direction=1):
        """Wendeltreppe am Stamm von z0 nach z1, beginnend bei Winkel a0 (Grad); r_fn(z) = Stammradius in Höhe z.
        Stufen kragen aus dem Stamm, kleine Stützbögen darunter. Rückgabe: Winkel (Grad) der obersten Stufe."""
        n = max(2, int(math.ceil((z1 - z0) / rise)))
        rise = (z1 - z0) / n
        a = math.radians(a0_deg)
        for k in range(n):
            zt = z0 + (k + 1) * rise
            ri = r_fn(zt) + 0.02
            rm = ri + width / 2
            da = tread / rm
            am = a + direction * da / 2
            M = Matrix.Translation(self._P(x, y, am, rm, zt)) @ Matrix.Rotation(am, 4, "Z")
            self.box(M, width, tread + 0.04, 0.14, "MI_Planks", z0=-0.14)
            if k % 3 == 0:                                       # Stützbogen
                self.log(self._P(x, y, am, ri, zt - 1.0), self._P(x, y, am, ri + width - 0.15, zt - 0.16), 0.07, sides=6)
            if k % 2 == 0:                                       # Handlauf außen
                p_out = self._P(x, y, am, ri + width - 0.06, zt)
                self.log(p_out, p_out + Vector((0, 0, 1.0)), 0.04, sides=5)
                a_next = a + direction * da * 2.5
                q_out = self._P(x, y, a_next, r_fn(zt + rise * 2) + 0.02 + width - 0.06, zt + rise * 2 + 1.0)
                if k + 2 < n:
                    self.log(p_out + Vector((0, 0, 0.95)), q_out - Vector((0, 0, 0.05)), 0.035, sides=5)
            a += direction * da
        self.count += 1
        return math.degrees(a)

    # --- Höhlen, Unterstände ---------------------------------------------------------------------------------------
    def cave_alcove(self, x, y, rot=0.0, w=5.0, h=4.2, depth=7.0, mat="MI_CaveRock"):
        """Höhleneingang: nach vorn (lokal -Y) offene Röhre mit unregelmäßigem Querschnitt, Boden, nach hinten
        dunkler werdend (letzte Ringe schwarz), Rückwand schwarz. Die Außenseite verdecken Fotoscan-Felsen."""
        g = self.ground(x, y, w, depth, rot)
        M = self.frame(x, y, g, rot)
        rings = []
        segs = 14
        n_r = 8
        seed = self.rng.uniform(0, 10)
        for i in range(n_r + 1):
            t = i / n_r
            yy = t * depth
            shrink = 1.0 - 0.35 * t
            ring = []
            for k in range(segs + 1):
                a = math.pi * k / segs                       # Halbbogen von rechts (0) über oben nach links (π)
                n = 1.0 + 0.12 * math.sin(a * 5 + seed + t * 7) + 0.08 * math.sin(a * 11 - t * 5)
                px = math.cos(a) * w / 2 * shrink * n
                pz = math.sin(a) * h * shrink * n
                ring.append(M @ Vector((px, yy, max(pz, 0.0) - (0.25 if k in (0, segs) else 0.0))))
            rings.append(ring)
        for i in range(n_r):
            m = mat if i < n_r - 2 else "MI_BlackStone"
            for k in range(segs):
                a, b, c, d = rings[i][k], rings[i][k + 1], rings[i + 1][k + 1], rings[i + 1][k]
                mid = (a + b + c + d) / 4
                axis = M @ Vector((0, (i + 0.5) / n_r * depth, h * 0.3))
                self.poly([a, b, c, d], m, axis - mid)               # Normale nach innen
        floor = [M @ Vector((-w / 2, 0, 0.02)), M @ Vector((w / 2, 0, 0.02)), M @ Vector((w / 2 * 0.65, depth, 0.02)),
                 M @ Vector((-w / 2 * 0.65, depth, 0.02))]
        self.poly(floor, mat, (0, 0, 1))
        back = [M @ Vector((-w / 2, depth, -0.3)), M @ Vector((w / 2, depth, -0.3)), M @ Vector((w / 2, depth, h)), M @ Vector((-w / 2, depth, h))]
        self.poly(back, "MI_BlackStone", M.to_3x3() @ Vector((0, -1, 0)))
        self.occupy(x, y + 0, w + 1.0, depth * 2, rot)
        self.count += 1
        return {"floor": g, "inside": tuple(M @ Vector((0, depth * 0.5, 0)))}

    def lean_to(self, x, y, rot=0.0, w=4.0, d=2.6, h=2.4):
        """Unterstand aus Rundhölzern mit Strohdach, vorn offen (lokal -Y), hinten fast bis zum Boden."""
        g = self.ground(x, y, w, d, rot)
        M = self.frame(x, y, g, rot)
        for s in (-1, 1):
            self.log(M @ Vector((s * w / 2, -d / 2, -0.4)), M @ Vector((s * w / 2, -d / 2, h)), 0.11)
            self.log(M @ Vector((s * w / 2, d / 2, -0.3)), M @ Vector((s * w / 2, d / 2, 0.55)), 0.09)
            self.log(M @ Vector((s * w / 2, -d / 2, h)), M @ Vector((s * w / 2, d / 2 + 0.3, 0.35)), 0.08)
        self.log(M @ Vector((-w / 2 - 0.3, -d / 2, h)), M @ Vector((w / 2 + 0.3, -d / 2, h)), 0.1)
        top = [M @ Vector((-w / 2 - 0.35, -d / 2 - 0.35, h + 0.12)), M @ Vector((w / 2 + 0.35, -d / 2 - 0.35, h + 0.12)),
               M @ Vector((w / 2 + 0.35, d / 2 + 0.45, 0.3)), M @ Vector((-w / 2 - 0.35, d / 2 + 0.45, 0.3))]
        n_up = (M.to_3x3() @ Vector((0, h, d))).normalized()
        self.poly(top, "MI_Thatch", n_up)
        self.poly([p - Vector((0, 0, 0.1)) for p in top], "MI_Thatch", -n_up)
        self.box(M, w - 0.2, d - 0.4, 0.12, "MI_Planks", z0=0.0)          # Lager aus Brettern
        self.occupy(x, y, w + 0.8, d + 0.8, rot)
        self.count += 1

    # --- Abschluss --------------------------------------------------------------------------------------------------
    def flush(self, name="SM_ProcStructs"):
        objs = []
        for (kx, ky), (bm, _) in self._bms.items():
            if len(bm.faces) == 0:
                bm.free()
                continue
            bm.normal_update()
            me = bpy.data.meshes.new("%s_%d_%d" % (name, kx, ky))
            bm.to_mesh(me)
            bm.free()
            for m in self.mats:
                me.materials.append(m)
            o = bpy.data.objects.new(me.name, me)
            self.kit.out.objects.link(o)
            objs.append(o)
        self._bms = {}
        print("OVERLORD bauwerke", self.count, "objekte", len(objs))
        return objs
