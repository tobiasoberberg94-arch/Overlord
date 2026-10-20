# Stadtbaukasten (Blender, auf loc_kit.Kit): dichte Straßenzüge wie in gewachsenen mittelalterlichen Städten.
#   town = Town(kit, half)
#   town.road(linie, breite, paved=True)          Straße ins Belegungsraster + Pflaster-/Erdmaske
#   town.plaza(x, y, radius)                       gepflasterter Platz
#   town.frontage(linie, breite, seite, katalog)   Häuserzeile Wand an Wand, Front (lokal -Y) zur Straße,
#                                                  mit Gassen und Hinterhöfen (Zäune, Schuppen, Holz, Gärten)
#   town.fill(...)                                 Blockinneres auffüllen (Werkstätten, Ställe, Gärten)
#   town.wall(...)                                 Stadtmauer mit Türmen und Toren
#   kit.terrain(..., path_fn=town.path_fn, dirt_fn=town.dirt_fn)
# Belegung als Raster (0,5 m): Gebäude als gedrehte Rechtecke statt Kreisen – Häuser dürfen eng stehen.
# Katalog: [(name, maßstab, gewicht), …]; Vorderseite der Gebäude = lokal -Y (Tür zur Straße).
import math

import numpy
from mathutils import Vector

FREE, HOUSE, ROAD, PLAZA, RESERVED, YARD, WALL = 0, 1, 2, 3, 4, 5, 6

YARD_PROPS = ["SM_WoodenBarrel01", "SM_FireWoodSet01", "SM_FireWoodSet02", "SM_WoodenBucket01", "SM_WoodenBucket02",
              "SM_WoodenBox01", "SM_WoodenBox03", "SM_WoodenChair01", "MW_crate_group_01", "MW_barrel_group_01"]
YARD_TREES = ["SM_Tree05", "SM_Tree06", "SM_Tree13", "SM_ChurchTree01"]
FENCES = [("SM_Fence01", 3.8), ("MW_fence_01", 2.36), ("MW_fence_02", 2.36), ("MW_fence_03", 2.35)]


class Town:
    def __init__(self, kit, half, cell=0.5):
        self.kit = kit
        self.rng = kit.rng
        self.half = half
        self.cell = cell
        self.n = int(round(2 * half / cell))
        self.occ = numpy.zeros((self.n, self.n), dtype=numpy.uint8)
        self.paved = numpy.zeros((self.n, self.n), dtype=numpy.float32)
        self.dirt = numpy.zeros((self.n, self.n), dtype=numpy.float32)
        self.xs = (numpy.arange(self.n) + 0.5) * cell - half
        self.plots = []
        self.smoke = []
        self.lamps = []
        self.have = None

    # --- Raster ---------------------------------------------------------------------------------
    def _sub(self, x0, y0, x1, y1):
        h, c = self.half, self.cell
        return (max(0, int((x0 + h) / c)), min(self.n, int((x1 + h) / c) + 1),
                max(0, int((y0 + h) / c)), min(self.n, int((y1 + h) / c) + 1))

    def _rect(self, cx, cy, w, d, rot):
        r = math.radians(rot)
        c, s = math.cos(r), math.sin(r)
        ex, ey = abs(c) * w / 2 + abs(s) * d / 2, abs(s) * w / 2 + abs(c) * d / 2
        i0, i1, j0, j1 = self._sub(cx - ex, cy - ey, cx + ex, cy + ey)
        if i0 >= i1 or j0 >= j1:
            return None
        X, Y = numpy.meshgrid(self.xs[i0:i1] - cx, self.xs[j0:j1] - cy, indexing="ij")
        m = (numpy.abs(X * c + Y * s) <= w / 2) & (numpy.abs(-X * s + Y * c) <= d / 2)
        return (i0, i1, j0, j1), m

    def rect_free(self, cx, cy, w, d, rot, allow=(FREE, YARD)):
        r = self._rect(cx, cy, w, d, rot)
        if r is None:
            return False
        (i0, i1, j0, j1), m = r
        if i0 == 0 or j0 == 0 or i1 == self.n or j1 == self.n:
            return False
        return bool(numpy.isin(self.occ[i0:i1, j0:j1][m], allow).all())

    def mark_rect(self, cx, cy, w, d, rot, val, paved=None, dirt=None):
        r = self._rect(cx, cy, w, d, rot)
        if r is None:
            return
        (i0, i1, j0, j1), m = r
        o = self.occ[i0:i1, j0:j1]
        o[m] = val
        if paved is not None:
            p = self.paved[i0:i1, j0:j1]
            p[m] = numpy.maximum(p[m], paved)
        if dirt is not None:
            q = self.dirt[i0:i1, j0:j1]
            q[m] = numpy.maximum(q[m], dirt)

    def at(self, x, y):
        i, j = int((x + self.half) / self.cell), int((y + self.half) / self.cell)
        if 0 <= i < self.n and 0 <= j < self.n:
            return int(self.occ[i, j])
        return RESERVED

    def _sample(self, grid, x, y):
        i, j = int((x + self.half) / self.cell), int((y + self.half) / self.cell)
        if 0 <= i < self.n and 0 <= j < self.n:
            return float(grid[i, j])
        return 0.0

    def path_fn(self, x, y):
        return self._sample(self.paved, x, y)

    def dirt_fn(self, x, y):
        return self._sample(self.dirt, x, y)

    # --- Straßen und Plätze -------------------------------------------------------------------------
    def road(self, line, width, paved=True, ragged=0.3, occ=ROAD):
        r = width / 2
        for (ax, ay), (bx, by) in zip(line[:-1], line[1:]):
            i0, i1, j0, j1 = self._sub(min(ax, bx) - r - 1, min(ay, by) - r - 1, max(ax, bx) + r + 1, max(ay, by) + r + 1)
            if i0 >= i1 or j0 >= j1:
                continue
            X, Y = numpy.meshgrid(self.xs[i0:i1], self.xs[j0:j1], indexing="ij")
            dx, dy = bx - ax, by - ay
            L = dx * dx + dy * dy or 1e-6
            t = numpy.clip(((X - ax) * dx + (Y - ay) * dy) / L, 0, 1)
            d = numpy.hypot(X - (ax + t * dx), Y - (ay + t * dy))
            m = d < r + numpy.sin(X * 1.7) * numpy.cos(Y * 1.3) * ragged
            o = self.occ[i0:i1, j0:j1]
            o[m & (o != HOUSE) & (o != WALL)] = occ
            g = (self.paved if paved else self.dirt)[i0:i1, j0:j1]
            g[m] = 1.0

    def plaza(self, x, y, r, paved=True, ragged=1.2):
        i0, i1, j0, j1 = self._sub(x - r - 2, y - r - 2, x + r + 2, y + r + 2)
        X, Y = numpy.meshgrid(self.xs[i0:i1], self.xs[j0:j1], indexing="ij")
        a = numpy.arctan2(Y - y, X - x)
        rr = r + numpy.sin(a * 3 + 1.3) * ragged + numpy.sin(a * 7) * ragged * 0.4
        m = numpy.hypot(X - x, Y - y) < rr
        o = self.occ[i0:i1, j0:j1]
        if paved is None:
            o[m & ((o == FREE) | (o == YARD))] = RESERVED
        else:
            o[m & (o != HOUSE) & (o != WALL)] = PLAZA
        if paved is not None:                      # None: nur freihalten (Gärten), Boden bleibt Gras
            g = (self.paved if paved else self.dirt)[i0:i1, j0:j1]
            g[m] = 1.0

    def reserve(self, x, y, w, d, rot=0.0, paved=None, dirt=None):
        self.mark_rect(x, y, w, d, rot, RESERVED, paved=paved, dirt=dirt)

    # --- Gebäude ------------------------------------------------------------------------------------
    def foot(self, name, s):
        sz = self.kit.size(name)
        return sz.x * s, sz.y * s

    def _pick(self, catalog):
        tot = sum(e[2] for e in catalog)
        r = self.rng.uniform(0, tot)
        for e in catalog:
            r -= e[2]
            if r <= 0:
                return e[0], e[1]
        return catalog[-1][0], catalog[-1][1]

    @staticmethod
    def _cum(line):
        cum = [0.0]
        for (ax, ay), (bx, by) in zip(line[:-1], line[1:]):
            cum.append(cum[-1] + math.hypot(bx - ax, by - ay))
        return cum

    @staticmethod
    def _at(line, cum, d):
        d = max(0.0, min(d, cum[-1] - 1e-6))
        k = next((k for k in range(len(cum) - 1) if cum[k + 1] >= d), len(line) - 2)
        t = (d - cum[k]) / max(1e-6, cum[k + 1] - cum[k])
        (ax, ay), (bx, by) = line[k], line[k + 1]
        L = math.hypot(bx - ax, by - ay) or 1.0
        return ax + (bx - ax) * t, ay + (by - ay) * t, (bx - ax) / L, (by - ay) / L

    def place(self, name, s, cx, cy, rot, jitter=0.0, val=HOUSE, pad=0.0):
        """Gebäude setzen (Mitte, Drehung), Raster belegen; Rückgabe Grundstücksdaten."""
        w, d = self.foot(name, s)
        self.kit.put(name, cx, cy, rot=rot + self.rng.uniform(-jitter, jitter), s=s, sink=0.2)
        self.mark_rect(cx, cy, w + pad, d + pad, rot, val)
        r = math.radians(rot)
        p = {"x": cx, "y": cy, "rot": rot, "w": w, "d": d, "name": name, "s": s,
             "fx": math.sin(r), "fy": -math.cos(r)}                  # Blickrichtung der Front (lokal -Y)
        self.plots.append(p)
        return p

    def frontage(self, line, width, side, catalog, setback=(0.3, 0.9), gap=(0.0, 0.5), alley=(4, 7),
                 alley_w=(2.2, 3.2), start=0.0, end=None, jitter=1.2, on_place=None, yards=True,
                 yard_depth=(5.0, 11.0), allow=(FREE, YARD)):
        cum = self._cum(line)
        total = cum[-1] if end is None else min(end, cum[-1])
        d = start
        since, nxt = 0, self.rng.randint(*alley)
        placed = []
        fails = 0
        while d < total - 2.0:
            if callable(catalog):                           # Katalog je Stadtviertel
                qx, qy = self._at(line, cum, d)[:2]
                cat = catalog(qx, qy)
                if not cat:
                    d += 4.0
                    continue
            else:
                cat = catalog
            name, s = self._pick(cat)
            s *= self.rng.uniform(0.96, 1.04)
            w, dp = self.foot(name, s)
            mid = d + w / 2
            if mid > total:
                break
            px, py, tx, ty = self._at(line, cum, mid)
            nx, ny = -ty * side, tx * side                 # zur Hausseite
            sb = width / 2 + self.rng.uniform(*setback)
            cx, cy = px + nx * (sb + dp / 2), py + ny * (sb + dp / 2)
            rot = math.degrees(math.atan2(-nx, ny))         # lokal -Y zeigt zur Straße
            if self.rect_free(cx, cy, w + 0.3, dp + 0.3, rot, allow):
                p = self.place(name, s, cx, cy, rot, jitter)
                p["street"] = (nx, ny)
                placed.append(p)
                if on_place:
                    on_place(p)
                d += w + self.rng.uniform(*gap)
                since += 1
                fails = 0
                if since >= nxt:                            # Gasse zwischen die Häuser
                    aw = self.rng.uniform(*alley_w)
                    ax, ay, atx, aty = self._at(line, cum, d + aw / 2)
                    anx, any_ = -aty * side, atx * side
                    depth = dp + 8.0
                    lx, ly = ax + anx * (sb + depth / 2), ay + any_ * (sb + depth / 2)
                    self.mark_rect(lx, ly, aw, depth, math.degrees(math.atan2(-anx, any_)), ROAD, dirt=1.0)
                    d += aw
                    since, nxt = 0, self.rng.randint(*alley)
            else:
                d += 1.0
                fails += 1
        if yards:
            for p in placed:
                self.yard(p, self.rng.uniform(*yard_depth))
        return placed

    def fill(self, inside, catalog, tries=400, margin=1.2, align=None, on_place=None):
        """Blockinneres: zufällige Punkte, Ausrichtung nach align(x, y) (Grad) oder in 90°-Schritten."""
        placed = []
        for _ in range(tries):
            x = self.rng.uniform(-self.half + 8, self.half - 8)
            y = self.rng.uniform(-self.half + 8, self.half - 8)
            if not inside(x, y) or self.at(x, y) not in (FREE, YARD):
                continue
            name, s = self._pick(catalog)
            w, d = self.foot(name, s)
            rot = (align(x, y) if align else self.rng.choice([0, 90, 180, 270])) + self.rng.uniform(-4, 4)
            if self.rect_free(x, y, w + margin * 2, d + margin * 2, rot, (FREE,)):
                p = self.place(name, s, x, y, rot, 0.0)
                placed.append(p)
                if on_place:
                    on_place(p)
                self.yard(p, self.rng.uniform(4, 8), fence=self.rng.random() < 0.5)
        return placed

    # --- Hinterhöfe ------------------------------------------------------------------------------------
    def yard(self, p, depth, fence=True):
        """Hof hinter dem Gebäude: festgetretene Erde, Zaun, Holzstapel, Fässer, Bäume, Wäsche."""
        bx, by = -p["fx"], -p["fy"]                            # nach hinten
        cx = p["x"] + bx * (p["d"] / 2 + depth / 2 + 0.2)
        cy = p["y"] + by * (p["d"] / 2 + depth / 2 + 0.2)
        if not self.rect_free(cx, cy, p["w"], depth, p["rot"], (FREE,)):
            depth *= 0.5
            cx = p["x"] + bx * (p["d"] / 2 + depth / 2 + 0.2)
            cy = p["y"] + by * (p["d"] / 2 + depth / 2 + 0.2)
            if depth < 2.5 or not self.rect_free(cx, cy, p["w"], depth, p["rot"], (FREE,)):
                return
        self.mark_rect(cx, cy, p["w"], depth, p["rot"], YARD, dirt=self.rng.uniform(0.55, 0.9))
        put, rng = self.kit.put, self.rng
        r = math.radians(p["rot"])
        ux, uy = math.cos(r), math.sin(r)                         # entlang der Front
        have = self._have()

        def local(a, b):                                          # a entlang der Front, b nach hinten ab Hofmitte
            return cx + ux * a + bx * b, cy + uy * a + by * b
        # Zaun hinten und an einer Seite
        if fence and depth > 3.0:
            fn, fl = rng.choice([f for f in FENCES if f[0] in have] or [FENCES[0]])
            n = max(1, int(p["w"] / fl))
            for k in range(n):
                a = -p["w"] / 2 + (k + 0.5) * p["w"] / n
                x, y = local(a, depth / 2 - 0.2)
                if rng.random() < 0.9:
                    put(fn, x, y, rot=p["rot"] + rng.uniform(-3, 3), s=p["w"] / n / fl)
            side = rng.choice((-1, 1))
            m = max(1, int(depth / fl))
            for k in range(m):
                b = -depth / 2 + (k + 0.5) * depth / m
                x, y = local(side * (p["w"] / 2 - 0.15), b)
                if rng.random() < 0.8:
                    put(fn, x, y, rot=p["rot"] + 90 + rng.uniform(-3, 3), s=depth / m / fl)
        # Gegenstände an der Hauswand
        for _ in range(rng.randint(1, 3)):
            a = rng.uniform(-p["w"] / 2 + 0.8, p["w"] / 2 - 0.8)
            x, y = local(a, -depth / 2 + rng.uniform(0.5, 1.4))
            nm = rng.choice([n for n in YARD_PROPS if n in have] or YARD_PROPS[:1])
            put(nm, x, y, rot=rng.uniform(0, 360), s=rng.uniform(0.85, 1.1))
        if rng.random() < 0.35 and "SM_Ladder01" in have:
            x, y = local(rng.uniform(-p["w"] / 3, p["w"] / 3), -depth / 2 + 0.25)
            put("SM_Ladder01", x, y, rot=p["rot"], rx=-12)
        # Baum oder Busch im Hof
        if depth > 5.0 and rng.random() < 0.55:
            x, y = local(rng.uniform(-p["w"] / 3, p["w"] / 3), rng.uniform(0, depth / 3))
            t = rng.choice([n for n in YARD_TREES if n in have] or YARD_TREES[:1])
            put(t, x, y, rot=rng.uniform(0, 360), s=rng.uniform(0.5, 0.75))
        elif rng.random() < 0.5 and "SM_Bush07" in have:
            x, y = local(rng.uniform(-p["w"] / 3, p["w"] / 3), rng.uniform(-depth / 4, depth / 3))
            put(rng.choice(["SM_Bush07", "SM_Bush01"]), x, y, rot=rng.uniform(0, 360), s=rng.uniform(0.7, 1.0), nocol=True)
        # Wäsche
        if rng.random() < 0.25 and "SM_Cloth01" in have:
            x, y = local(rng.uniform(-p["w"] / 4, p["w"] / 4), 0.0)
            put(rng.choice(["SM_Cloth01", "SM_Cloth02", "SM_Cloth03"]), x, y, z=self.kit.ground_fn(x, y) + 1.2,
                rot=p["rot"], nocol=True)
        # Hackklotz mit Beil und Holz, Werkzeug, Körbe (Fotoscans)
        if rng.random() < 0.4:
            x, y = local(rng.uniform(-p["w"] / 3, p["w"] / 3), rng.uniform(-depth / 4, depth / 4))
            self.kit.ph(rng.choice(["tree_stump_01", "tree_stump_02"]), x, y, rot=rng.uniform(0, 360), s=0.55)
            self.kit.ph(rng.choice(["hatchet", "wooden_axe"]), x + 0.6, y + 0.3, rot=rng.uniform(0, 360))
        for _ in range(rng.randint(0, 2)):
            x, y = local(rng.uniform(-p["w"] / 2 + 0.6, p["w"] / 2 - 0.6), rng.uniform(-depth / 2 + 0.6, depth / 2 - 0.6))
            self.kit.ph(rng.choice(["wicker_basket_01", "wicker_basket_02", "wooden_bucket_01", "wooden_crate_02",
                                    "rusted_spade_01", "wooden_broom", "spinning_wheel_01", "wooden_stool_01"]),
                        x, y, rot=rng.uniform(0, 360))
        # Schuppen am Ende tiefer Höfe
        if depth > 8.5 and rng.random() < 0.5 and "SM_StorageSet" in have:
            s = rng.uniform(0.55, 0.7)
            sw, sd = self.foot("SM_StorageSet", s)
            if sw < p["w"] + 1.0:
                x, y = local(rng.uniform(-(p["w"] - sw) / 2, (p["w"] - sw) / 2), depth / 2 - sd / 2 - 0.3)
                self.kit.put("SM_StorageSet", x, y, rot=p["rot"] + 180, s=s, sink=0.15)
                self.mark_rect(x, y, sw, sd, p["rot"], HOUSE)

    def _have(self):
        if self.have is None:
            import os
            self.have = {os.path.splitext(f)[0] for d in self.kit.dirs for f in os.listdir(os.path.join(d, "meshes"))}
        return self.have

    # --- Straßenleben --------------------------------------------------------------------------------
    def dress_front(self, p, props=("SM_WoodenBarrel01", "SM_WoodenBox01", "SM_WoodenBucket02", "SM_FlowerPot01",
                                    "SM_FlowerPot02", "FV_crate_01", "FV_barrel_01", "FV_bag"), chance=0.55):
        """Kleinkram vor der Hausfront (Fässer, Kisten, Blumentöpfe), Schild, Kaminrauch."""
        have = self._have()
        rng = self.rng
        r = math.radians(p["rot"])
        ux, uy = math.cos(r), math.sin(r)
        if rng.random() < chance:
            a = rng.choice((-1, 1)) * rng.uniform(p["w"] * 0.2, p["w"] * 0.42)
            fx = p["x"] + p["fx"] * (p["d"] / 2 + 0.55) + ux * a
            fy = p["y"] + p["fy"] * (p["d"] / 2 + 0.55) + uy * a
            for _ in range(rng.randint(1, 3)):
                nm = rng.choice([n for n in props if n in have] or ["SM_WoodenBarrel01"])
                self.kit.put(nm, fx + rng.uniform(-0.6, 0.6), fy + rng.uniform(-0.6, 0.6), rot=rng.uniform(0, 360),
                             s=rng.uniform(0.85, 1.1))
        if rng.random() < 0.22:                                # Bank vor dem Haus
            a = rng.choice((-1, 1)) * p["w"] * 0.25
            bx_ = p["x"] + p["fx"] * (p["d"] / 2 + 0.45) + ux * a
            by_ = p["y"] + p["fy"] * (p["d"] / 2 + 0.45) + uy * a
            if self.at(bx_, by_) != HOUSE:
                self.kit.ph(rng.choice(["painted_wooden_bench", "wooden_stool_02", "folding_wooden_stool"]), bx_, by_,
                            rot=p["rot"] + rng.uniform(-6, 6))
        if rng.random() < 0.18 and "SM_Sign01" in have:
            sx = p["x"] + p["fx"] * (p["d"] / 2 + 0.6) + ux * p["w"] * 0.3
            sy = p["y"] + p["fy"] * (p["d"] / 2 + 0.6) + uy * p["w"] * 0.3
            self.kit.put("SM_Sign01", sx, sy, z=self.kit.ground_fn(sx, sy) + 3.0, rot=p["rot"] + 90, nocol=True)
        if rng.random() < 0.45:
            self.smoke.append((p["x"] + ux * p["w"] * 0.2, p["y"] + uy * p["w"] * 0.2,
                               self.kit.ground_fn(p["x"], p["y"]) + self.kit.size(p["name"]).z * p["s"] * 0.92))

    def lamps_along(self, line, width, every=16.0, side=1, name="SM_StandLight", s=1.0, z_light=2.6):
        cum = self._cum(line)
        d = every * 0.5
        while d < cum[-1]:
            x, y, tx, ty = self._at(line, cum, d)
            nx, ny = -ty * side, tx * side
            lx, ly = x + nx * (width / 2 + 0.5), y + ny * (width / 2 + 0.5)
            if self.at(lx, ly) in (ROAD, PLAZA, FREE, YARD):
                self.kit.put(name, lx, ly, s=s)
                self.lamps.append((lx, ly, self.kit.ground_fn(lx, ly) + z_light * s))
            d += every
            side = -side

    # --- Stadtmauer ------------------------------------------------------------------------------------
    def wall(self, pts, gates=(), tower_every=34.0, seg=5.0, height_rows=2, gate_gap=7.0,
             tower=("SM_TowerrType2", 0.3), small_tower=("SM_TowerSmall", 0.62), closed=True):
        """Mauerring aus Steinlagen (SM_brick) mit Zinnen (SM_updan), Türmen; Lücken an den Toren."""
        put, kit = self.kit.put, self.kit
        P = list(pts) + ([pts[0]] if closed else [])
        run = 0.0
        for (ax, ay), (bx, by) in zip(P[:-1], P[1:]):
            L = math.hypot(bx - ax, by - ay)
            rot = math.degrees(math.atan2(by - ay, bx - ax))
            n = max(1, round(L / seg))
            for j in range(n):
                t = (j + 0.5) / n
                x, y = ax + (bx - ax) * t, ay + (by - ay) * t
                if any(math.hypot(x - gx, y - gy) < gate_gap for gx, gy in gates):
                    continue
                g = kit.ground_fn(x, y)
                for row in range(height_rows):
                    put("SM_brick", x, y, z=g - 0.5 + row * 5.0, rot=rot)
                put("SM_updan", x, y, z=g - 0.6 + height_rows * 5.0, rot=rot)
                self.mark_rect(x, y, L / n + 0.6, 4.0, rot, WALL)
            run += L
            if run >= tower_every:
                run = 0.0
                if all(math.hypot(bx - gx, by - gy) > 12 for gx, gy in gates):
                    nm, s = small_tower
                    put(nm, bx, by, s=s, rot=self.rng.uniform(0, 360))
                    self.mark_rect(bx, by, 8, 8, 0, WALL)
        for gx, gy in gates:
            self.mark_rect(gx, gy, 14, 14, 0, RESERVED)

    def save_map(self, path):
        """Belegungskarte als Bild (Kontrolle): Gebäude dunkel, Straßen/Plätze hell, Höfe braun, Mauern rot."""
        import bpy
        col = numpy.array([[0.35, 0.5, 0.25], [0.15, 0.12, 0.1], [0.75, 0.72, 0.65], [0.85, 0.82, 0.7],
                           [0.5, 0.3, 0.6], [0.55, 0.4, 0.25], [0.8, 0.15, 0.1]], dtype=numpy.float32)
        rgb = col[numpy.clip(self.occ, 0, 6)]                         # (i=x, j=y, 3)
        img = numpy.ones((self.n, self.n, 4), dtype=numpy.float32)
        img[..., :3] = numpy.transpose(rgb, (1, 0, 2))                 # Zeilen = y (unten nach oben)
        im = bpy.data.images.new("belegung", self.n, self.n, alpha=False)
        im.pixels.foreach_set(img.reshape(-1))
        im.filepath_raw = path
        im.file_format = "PNG"
        im.save()
        inner = (self.occ != FREE).sum()
        print("OVERLORD belegung: gebäude %.1f%%, straßen %.1f%%, höfe %.1f%% (von belegter fläche %d m²)" % (
            100 * (self.occ == HOUSE).sum() / max(inner, 1), 100 * ((self.occ == ROAD) | (self.occ == PLAZA)).sum() / max(inner, 1),
            100 * (self.occ == YARD).sum() / max(inner, 1), inner * self.cell * self.cell))

    # --- Marktstände -----------------------------------------------------------------------------------
    CLOTH = [((0.52, 0.1, 0.08), (0.86, 0.81, 0.68)), ((0.12, 0.2, 0.42), (0.85, 0.8, 0.68)),
             ((0.2, 0.33, 0.14), (0.84, 0.79, 0.64)), ((0.6, 0.42, 0.12), (0.4, 0.24, 0.12)),
             ((0.78, 0.72, 0.6), (0.7, 0.64, 0.52)), ((0.45, 0.12, 0.32), (0.86, 0.8, 0.66))]
    WARES = [["wicker_basket_01", "wicker_basket_02", "food_apple_01"],
             ["jug_01", "metal_jug", "wooden_bowl_01", "ceramic_vase_01"],
             ["wicker_basket_02", "yellow_onion", "sweet_potato"],
             ["wooden_bowl_02", "carved_wooden_plate", "wooden_cutting_board", "brass_pot_01"],
             ["wine_bottles_01", "jug_01", "brass_goblets"],
             ["CheeseBox_01", "wicker_basket_01", "wooden_bucket_02"]]

    def _wood_mat(self):
        import bpy
        m = bpy.data.materials.get("MI_StallWood")
        if m is None:
            m = self.kit._simple_mat("MI_StallWood", "Textures_T_Weathered_Wood_BC.png", "Textures_T_Weathered_Wood_N.png", 0.8)
            self.kit.keep_mats.add(m.name)
        return m

    def _cloth_mat(self, k):
        import os
        import bpy
        name = "MI_StallCloth_%d" % k
        m = bpy.data.materials.get(name)
        if m:
            return m
        a, b = self.CLOTH[k % len(self.CLOTH)]
        W = 256
        img = bpy.data.images.new(name + "_tex", W, W, alpha=False)
        px = numpy.zeros((W, W, 4), dtype=numpy.float32)
        xs = numpy.arange(W)
        stripe = ((xs // 32) % 2 == 0)[None, :, None]
        ca = numpy.array(a + (1.0,), dtype=numpy.float32)
        cb = numpy.array(b + (1.0,), dtype=numpy.float32)
        px[:] = numpy.where(stripe, ca, cb)
        rs = numpy.random.RandomState(k)
        px[..., :3] *= rs.uniform(0.82, 1.08, (W, W, 1)).astype(numpy.float32)        # Webstruktur, Flecken
        px[..., :3] *= numpy.linspace(0.75, 1.0, W, dtype=numpy.float32)[:, None, None]  # Rand dunkler
        px[..., :3] = numpy.clip(px[..., :3], 0, 1)                                      # Bytebild: sRGB-Werte
        img.pixels.foreach_set(px.reshape(-1))
        img.filepath_raw = os.path.join(self.kit.small_dir, name + ".png")
        img.file_format = "PNG"
        img.save()
        img.reload()
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        nt = m.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        bsdf.inputs["Roughness"].default_value = 0.95
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = img
        nt.links.new(t.outputs["Color"], bsdf.inputs["Base Color"])
        m.use_backface_culling = False
        self.kit.keep_mats.add(m.name)
        return m

    def stall(self, x, y, rot, w=2.8, d=1.8, h=2.5, cloth=None, goods=True):
        """Marktstand: vier Pfosten, Tisch, durchhängendes Stoffdach mit Streifen und Volant; Waren darauf
        (Fotoscans als Markierungen, kit.ph). Vorderseite = lokal -Y."""
        import bmesh
        import bpy
        from mathutils import Matrix
        k = self.rng.randrange(len(self.CLOTH)) if cloth is None else cloth
        wood = self._wood_mat()
        cl = self._cloth_mat(k)
        bm = bmesh.new()
        uv = bm.loops.layers.uv.new("UVMap")

        def box(cx, cy, cz, sx, sy, sz):
            r = bmesh.ops.create_cube(bm, size=1.0)
            vs = r["verts"]
            bmesh.ops.scale(bm, vec=(sx, sy, sz), verts=vs)
            bmesh.ops.translate(bm, vec=(cx, cy, cz), verts=vs)
            for f in {f for v in vs for f in v.link_faces}:
                f.material_index = 0
                n = f.normal
                for lp in f.loops:
                    co = lp.vert.co
                    if abs(n.z) > 0.5:
                        lp[uv].uv = (co.x * 0.5, co.y * 0.5)
                    elif abs(n.x) > 0.5:
                        lp[uv].uv = (co.y * 0.5, co.z * 0.5)
                    else:
                        lp[uv].uv = (co.x * 0.5, co.z * 0.5)
        hf = h - 0.45                                         # Vorderkante tiefer
        for sx in (-1, 1):
            box(sx * (w / 2 - 0.08), -d / 2 + 0.08, hf / 2, 0.1, 0.1, hf)
            box(sx * (w / 2 - 0.08), d / 2 - 0.08, h / 2, 0.1, 0.1, h)
        box(0, -d / 2 + 0.5, 0.86, w - 0.1, 0.9, 0.06)          # Tischplatte
        box(0, -d / 2 + 0.08, 0.43, w - 0.2, 0.04, 0.8)         # Blende unter dem Tisch
        box(0, d / 2 - 0.25, 0.55, w - 0.3, 0.4, 0.04)          # Ablage hinten
        nu, nv = 10, 6
        grid = []
        for i in range(nu + 1):
            row = []
            for j in range(nv + 1):
                u, v = i / nu, j / nv
                row.append(bm.verts.new((-w / 2 - 0.15 + u * (w + 0.3), -d / 2 - 0.25 + v * (d + 0.35),
                                         hf + (h - hf) * v - 0.13 * math.sin(math.pi * u) * math.sin(math.pi * v) + 0.06)))
            grid.append(row)
        for i in range(nu):
            for j in range(nv):
                f = bm.faces.new((grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]))
                f.material_index = 1
                for lp, (a_, b_) in zip(f.loops, ((i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1))):
                    lp[uv].uv = (a_ / nu * 3.0, b_ / nv * 0.9)
        prev = None
        for i in range(nu + 1):                                 # Volant vorn, gezackt
            top = grid[i][0].co.copy()
            dz = 0.28 if i % 2 == 0 else 0.2
            vt = bm.verts.new(top)
            vb = bm.verts.new((top.x, top.y - 0.01, top.z - dz))
            if prev:
                f = bm.faces.new((prev[0], vt, vb, prev[1]))
                f.material_index = 1
                for lp, (a_, b_) in zip(f.loops, ((i - 1, 0), (i, 0), (i, 1), (i - 1, 1))):
                    lp[uv].uv = (a_ / nu * 3.0, 0.9 + b_ * 0.1)
            prev = (vt, vb)
        bm.normal_update()
        me = bpy.data.meshes.new("stall_%d" % len(self.plots))
        bm.to_mesh(me)
        bm.free()
        me.materials.append(wood)
        me.materials.append(cl)
        o = bpy.data.objects.new("SM_MarketStall", me)
        g = self.kit.ground_fn(x, y)
        o.matrix_world = Matrix.Translation((x, y, g)) @ Matrix.Rotation(math.radians(rot), 4, "Z")
        self.kit.out.objects.link(o)
        self.mark_rect(x, y, w + 0.6, d + 0.6, rot, HOUSE)
        if goods:
            r = math.radians(rot)
            ux, uy = math.cos(r), math.sin(r)
            vx, vy = -math.sin(r), math.cos(r)                   # nach hinten
            wares = self.rng.choice(self.WARES)
            n = self.rng.randint(3, 6)
            for i in range(n):
                a = -w / 2 + 0.35 + (i + 0.5) * (w - 0.7) / n
                b = -d / 2 + 0.5 + self.rng.uniform(-0.15, 0.15)
                self.kit.ph(self.rng.choice(wares), x + ux * a + vx * b, y + uy * a + vy * b, z=g + 0.89,
                            rot=self.rng.uniform(0, 360))
            for _ in range(self.rng.randint(1, 3)):              # Kisten, Fässer, Körbe daneben
                a = self.rng.choice((-1, 1)) * (w / 2 + self.rng.uniform(0.45, 0.9))
                b = self.rng.uniform(-d / 2, d / 2)
                self.kit.ph(self.rng.choice(["wooden_crate_01", "wooden_crate_02", "wine_barrel_01", "barrel_03",
                                             "wicker_basket_01"]), x + ux * a + vx * b, y + uy * a + vy * b,
                            rot=self.rng.uniform(0, 360))
        return o

    # --- Amphitheater ------------------------------------------------------------------------------------
    def _named_mat(self, name, tex, normal, rough=0.85):
        import bpy
        m = bpy.data.materials.get(name)
        if m is None:
            m = self.kit._simple_mat(name, tex, normal, rough)
            m.name = name
            self.kit.keep_mats.add(m.name)
        return m

    def colosseum(self, cx, cy, R=30.0, r_arena=15.0, tiers=3, tier_h=5.0, attic_h=2.8, segs=56, T=1.6,
                  gates=(180.0,), podium_h=3.2, tunnel_h=3.0, rot=0.0):
        """Amphitheater: Arkadenfassade in drei Geschossen (Blendarkaden, Gesimse) und Attika mit Masten,
        begehbare Sitzstufen bis zur Podiumsmauer mit Brüstung, Sandarena; Tore (Winkel in Grad, 0 = +X) als
        Tunnel unter den Rängen. Alle Flächen zeigen zur offenen Seite (einseitige Kollision im Spiel)."""
        import bmesh
        import bpy
        wall_m = self._named_mat("MI_ArenaWall", "Texture_T_CastleWall_BC.png", "Texture_T_CastleWall_N.png", 0.85)
        seat_m = self._named_mat("MI_ArenaFloor", "Textures_T_BayStone_BC.png", "Textures_T_BayStone_N.png", 0.9)
        wood_m = self._wood_mat()
        bm = bmesh.new()
        uvl = bm.loops.layers.uv.new("UVMap")
        TILE = 3.0
        g0 = min(self.kit.ground_fn(cx + math.cos(a) * R, cy + math.sin(a) * R) for a in [k * math.tau / 12 for k in range(12)])
        g0 = min(g0, self.kit.ground_fn(cx, cy))
        base = -0.6                                      # Fundament unter Geländeniveau
        rot_r = math.radians(rot)

        def P(th, r, z):
            return Vector((cx + math.cos(th + rot_r) * r, cy + math.sin(th + rot_r) * r, g0 + z))

        def face(pts, mat, want, uvs=None):
            """Fläche aus Punkten; Reihenfolge so, dass die Normale zur Richtung `want` zeigt."""
            vs = [bm.verts.new(p) for p in pts]
            f = bm.faces.new(vs)
            f.normal_update()
            if f.normal.dot(want) < 0:
                f.normal_flip()
            f.material_index = mat
            th0 = None
            for lp in f.loops:
                co = lp.vert.co
                n = f.normal
                if abs(n.z) > 0.7:
                    lp[uvl].uv = (co.x / TILE, co.y / TILE)
                else:
                    th = math.atan2(co.y - cy, co.x - cx)
                    if th0 is None:
                        th0 = th
                    th += round((th0 - th) / math.tau) * math.tau      # Naht bei ±180° nicht durch die Fläche
                    rr = math.hypot(co.x - cx, co.y - cy)
                    lp[uvl].uv = (th * R / TILE, co.z / TILE)
            return f

        def radial(th):
            return Vector((math.cos(th + rot_r), math.sin(th + rot_r), 0.0))

        def tangent(th):
            return Vector((-math.sin(th + rot_r), math.cos(th + rot_r), 0.0))

        UP, DOWN = Vector((0, 0, 1)), Vector((0, 0, -1))
        dA = math.tau / segs
        w = R * dA
        pw = 0.9
        ow = w - pw
        ar = ow / 2
        r_o = R - T
        top_z = tiers * tier_h - 0.5
        H = tiers * tier_h + attic_h
        gate_th = [math.radians(g) for g in gates]

        # je Tor genau ein Segment: das, dessen Mitte dem Torwinkel am nächsten liegt
        gate_segs = {int(round(g / dA - 0.5)) % segs for g in gate_th}

        def is_gate(i):
            return i in gate_segs

        K = 8                                             # Bogenunterteilung
        for i in range(segs):
            a0 = i * dA
            ang = lambda u: a0 + u / w * dA              # noqa: E731
            gate = is_gate(i)
            for t in range(tiers):
                z0 = (base if t == 0 else t * tier_h)
                z1 = (t + 1) * tier_h
                zs = tier_h - 0.55 - ar                   # Kämpferlinie (über der Geschossunterkante zb)
                zb = t * tier_h
                n_out = radial(ang(w / 2))
                # Pfeilerhälften außen
                for (u0, u1) in ((0.0, pw / 2), (w - pw / 2, w)):
                    face([P(ang(u0), R, z0), P(ang(u1), R, z0), P(ang(u1), R, zb + zs), P(ang(u0), R, zb + zs)], 0, n_out)
                    face([P(ang(u0), R, zb + zs), P(ang(u1), R, zb + zs), P(ang(u1), R, z1), P(ang(u0), R, z1)], 0, n_out)
                # Laibung (Pfeilerseiten zur Öffnung)
                for (u, sgn) in ((pw / 2, 1), (w - pw / 2, -1)):
                    face([P(ang(u), R, z0), P(ang(u), r_o, z0), P(ang(u), r_o, zb + zs), P(ang(u), R, zb + zs)],
                         0, tangent(ang(u)) * sgn)
                # Bogenzwickel (zwischen Bogen und Gesims) und Bogenleibung
                uc = w / 2
                prev = None
                for k in range(K + 1):
                    phi = math.pi - k * math.pi / K
                    u = uc + ar * math.cos(phi)
                    z = zb + zs + ar * math.sin(phi)
                    cur = (u, z)
                    if prev:
                        (pu, pz) = prev
                        face([P(ang(pu), R, pz), P(ang(u), R, z), P(ang(u), R, z1), P(ang(pu), R, z1)], 0, n_out)
                        mid = (P(ang(pu), R, pz) + P(ang(u), r_o, z)) * 0.5
                        face([P(ang(pu), R, pz), P(ang(u), R, z), P(ang(u), r_o, z), P(ang(pu), r_o, pz)], 0,
                             P(ang(uc), (R + r_o) / 2, zb + zs) - mid)
                    prev = cur
                # Gesims (vorstehendes Band)
                zc0, zc1 = z1 - 0.32, z1 + 0.05
                face([P(a0, R + 0.28, zc0), P(a0 + dA, R + 0.28, zc0), P(a0 + dA, R + 0.28, zc1), P(a0, R + 0.28, zc1)], 0, n_out)
                face([P(a0, R, zc1), P(a0 + dA, R, zc1), P(a0 + dA, R + 0.28, zc1), P(a0, R + 0.28, zc1)], 0, UP)
                face([P(a0, R, zc0), P(a0 + dA, R, zc0), P(a0 + dA, R + 0.28, zc0), P(a0, R + 0.28, zc0)], 0, DOWN)
            # Attika: geschlossene Wand außen und innen, Abdeckung, Masten für das Sonnensegel
            za, zt = tiers * tier_h, H
            face([P(a0, R, za), P(a0 + dA, R, za), P(a0 + dA, R, zt), P(a0, R, zt)], 0, radial(a0 + dA / 2))
            face([P(a0, r_o, top_z), P(a0 + dA, r_o, top_z), P(a0 + dA, r_o, zt), P(a0, r_o, zt)], 0, -radial(a0 + dA / 2))
            face([P(a0, r_o, zt), P(a0 + dA, r_o, zt), P(a0 + dA, R + 0.1, zt), P(a0, R + 0.1, zt)], 0, UP)
            if i % 2 == 0:
                # Kragsteine unter dem Attikagesims (wie am Kolosseum: Halter der Segelmasten)
                th = a0 + dA / 2
                for (zb_, zh_) in ((za + 0.55, 0.35),):
                    c0 = P(th - 0.12 / R, R, zb_)
                    c1 = P(th + 0.12 / R, R, zb_)
                    o0 = P(th - 0.12 / R, R + 0.35, zb_)
                    o1 = P(th + 0.12 / R, R + 0.35, zb_)
                    up_ = Vector((0, 0, zh_))
                    face([c0, o0, o1, c1], 0, DOWN)
                    face([c0 + up_, o0 + up_, o1 + up_, c1 + up_], 0, UP)
                    face([o0, o1, o1 + up_, o0 + up_], 0, radial(th))
                    face([c0, o0, o0 + up_, c0 + up_], 0, -tangent(th))
                    face([c1, o1, o1 + up_, c1 + up_], 0, tangent(th))
            # Ränge (Sitzstufen) über diesem Segment: drei Scheiben (Pfeiler, Öffnung, Pfeiler)
            n_steps = max(4, int(round((top_z - podium_h) / 0.47)))
            sh = (top_z - podium_h) / n_steps
            r_i = r_arena + 0.6
            dep = (r_o - r_i) / n_steps
            for (b0, b1, opening) in ((a0, a0 + pw / 2 / w * dA, False), (a0 + pw / 2 / w * dA, a0 + dA - pw / 2 / w * dA, True),
                                      (a0 + dA - pw / 2 / w * dA, a0 + dA, False)):
                tunnel = gate and opening
                for k in range(n_steps):
                    ra, rb = r_o - k * dep, r_o - (k + 1) * dep
                    z = top_z - k * sh
                    face([P(b0, ra, z), P(b1, ra, z), P(b1, rb, z), P(b0, rb, z)], 1, UP)                  # Sitzfläche
                    face([P(b0, rb, z), P(b1, rb, z), P(b1, rb, z - sh), P(b0, rb, z - sh)], 1, -radial((b0 + b1) / 2))   # Setzstufe
                # Rückwand der Ränge (hinter den Blendarkaden) bzw. Tunnelende
                zlo = tunnel_h if tunnel else base
                face([P(b0, r_o, zlo), P(b1, r_o, zlo), P(b1, r_o, top_z), P(b0, r_o, top_z)], 0, radial((b0 + b1) / 2))
                # Podium: Abdeckung, Brüstung, Innenwand zur Arena
                face([P(b0, r_i, podium_h), P(b1, r_i, podium_h), P(b1, r_arena + 0.3, podium_h), P(b0, r_arena + 0.3, podium_h)], 1, UP)
                face([P(b0, r_arena + 0.3, podium_h), P(b1, r_arena + 0.3, podium_h), P(b1, r_arena + 0.3, podium_h + 1.0),
                      P(b0, r_arena + 0.3, podium_h + 1.0)], 0, radial((b0 + b1) / 2))
                face([P(b0, r_arena, podium_h + 1.0), P(b1, r_arena, podium_h + 1.0), P(b1, r_arena + 0.3, podium_h + 1.0),
                      P(b0, r_arena + 0.3, podium_h + 1.0)], 0, UP)
                face([P(b0, r_arena, tunnel_h if tunnel else base), P(b1, r_arena, tunnel_h if tunnel else base),
                      P(b1, r_arena, podium_h + 1.0), P(b0, r_arena, podium_h + 1.0)], 0, -radial((b0 + b1) / 2))
                if tunnel:
                    face([P(b0, r_o, tunnel_h), P(b1, r_o, tunnel_h), P(b1, r_arena, tunnel_h), P(b0, r_arena, tunnel_h)], 0, DOWN)
                    face([P(b0, r_o, base), P(b0, r_arena, base), P(b0, r_arena, tunnel_h), P(b0, r_o, tunnel_h)], 0, tangent(b0))
                    face([P(b1, r_o, base), P(b1, r_arena, base), P(b1, r_arena, tunnel_h), P(b1, r_o, tunnel_h)], 0, -tangent(b1))
        # Sandboden der Arena (eigene Fläche knapp über dem Gelände, im Spiel Fotosand)
        sand_m = self._named_mat("MI_ArenaSand", "Textures_T_LandScapeLayer05_BC.png", "Textures_T_LandScapeLayer04_N.png", 0.95)
        segs_s = 48
        centre = bm.verts.new(P(0.0, 0.0, 0.04))
        ring_s = [bm.verts.new(P(k * math.tau / segs_s, r_arena + 0.05, 0.04)) for k in range(segs_s)]
        for k in range(segs_s):
            f = bm.faces.new((centre, ring_s[k], ring_s[(k + 1) % segs_s]))
            f.normal_update()
            if f.normal.z < 0:
                f.normal_flip()
            f.material_index = 3
            for lp in f.loops:
                lp[uvl].uv = (lp.vert.co.x / TILE, lp.vert.co.y / TILE)
        bm.normal_update()
        me = bpy.data.meshes.new("SM_Colosseum")
        bm.to_mesh(me)
        bm.free()
        me.materials.append(wall_m)
        me.materials.append(seat_m)
        me.materials.append(wood_m)
        me.materials.append(sand_m)
        o = bpy.data.objects.new("SM_Colosseum", me)
        self.kit.out.objects.link(o)
        # Belegung: gepflasterter Umgang, Bauwerk (Straßen enden am Umgang), Arena mit Sand
        self.plaza(cx, cy, R + 6.0, paved=True, ragged=0.5)
        i0, i1, j0, j1 = self._sub(cx - R - 2, cy - R - 2, cx + R + 2, cy + R + 2)
        X, Y = numpy.meshgrid(self.xs[i0:i1], self.xs[j0:j1], indexing="ij")
        d = numpy.hypot(X - cx, Y - cy)
        inner = d < R + 0.8
        self.occ[i0:i1, j0:j1][inner] = RESERVED
        self.paved[i0:i1, j0:j1][inner] = 0.0
        self.dirt[i0:i1, j0:j1][inner] = 0.0
        self.dirt[i0:i1, j0:j1][d < r_arena] = 1.0              # Sand
        for g in gate_th:                                        # Tunnelboden: Erde
            for k in range(int(R - r_arena) + 2):
                rr = r_arena + k
                tx_, ty_ = cx + math.cos(g + rot_r) * rr, cy + math.sin(g + rot_r) * rr
                self.mark_rect(tx_, ty_, 1.4, ow, math.degrees(g + rot_r), RESERVED, dirt=1.0)
        self.colosseum_info = {"center": (cx, cy, g0), "R": R, "arena": r_arena, "podium": podium_h}
        return o

    # --- Große Wehrmauer ----------------------------------------------------------------------------------
    def great_wall(self, line, height=15.0, T=6.0, batter=1.2, merlon=(1.3, 1.4, 2.6), gaps=(), gap_w=10.0,
                   stairs_every=70.0, outer_side=-1, name="SM_GreatWall"):
        """Mächtige Mauer entlang einer Polylinie: geböschter Fuß, Wehrgang oben (begehbar), Zinnen zur Außenseite
        (outer_side: -1 = rechts der Laufrichtung … Vorzeichen der Normalen), Brüstung innen, Treppen auf der
        Innenseite. gaps: Punkte (x, y), an denen die Mauer für Tore offen bleibt."""
        import bmesh
        import bpy
        wall_m = self._named_mat("MI_GreatWall", "Texture_T_CastleWall_BC.png", "Texture_T_CastleWall_N.png", 0.88)
        bm = bmesh.new()
        uvl = bm.loops.layers.uv.new("UVMap")
        TILE = 3.5
        gfn = self.kit.ground_fn
        UP = Vector((0, 0, 1))

        def face(pts, want, along0=0.0):
            vs = [bm.verts.new(p) for p in pts]
            f = bm.faces.new(vs)
            f.normal_update()
            if f.normal.dot(want) < 0:
                f.normal_flip()
            n = f.normal
            for lp in f.loops:
                co = lp.vert.co
                if abs(n.z) > 0.7:
                    lp[uvl].uv = (co.x / TILE, co.y / TILE)
                else:
                    t = Vector((-n.y, n.x, 0.0))
                    lp[uvl].uv = ((co.x * t.x + co.y * t.y) / TILE, co.z / TILE)
            return f

        def box(c, ax, w, d, h, z0):
            """Quader: Mitte c (x, y), Längsachse ax (Einheitsvektor), Breite w (längs), Tiefe d, Höhe h ab z0."""
            nx = Vector((-ax.y, ax.x, 0.0))
            p = [Vector((c.x, c.y, 0)) + ax * (sx * w / 2) + nx * (sy * d / 2) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
            lo = [Vector((q.x, q.y, z0)) for q in p]
            hi = [Vector((q.x, q.y, z0 + h)) for q in p]
            for e in range(4):
                mid = (lo[e] + lo[(e + 1) % 4]) * 0.5
                face([lo[e], lo[(e + 1) % 4], hi[(e + 1) % 4], hi[e]], mid - Vector((c.x, c.y, mid.z)))
            face(hi, UP)

        # Abschnitte zwischen den Toren
        pts = [Vector((x, y, 0.0)) for x, y in line]
        dense = []
        for a, b in zip(pts[:-1], pts[1:]):
            n = max(1, int((b - a).length / 4.0))
            for k in range(n):
                dense.append(a.lerp(b, k / n))
        dense.append(pts[-1])
        runs, cur = [], []
        for p in dense:
            if any(math.hypot(p.x - gx, p.y - gy) < gap_w / 2 for gx, gy in gaps):
                if len(cur) > 1:
                    runs.append(cur)
                cur = []
            else:
                cur.append(p)
        if len(cur) > 1:
            runs.append(cur)
        made_stairs = 0.0
        for run in runs:
            prof = []
            for i, p in enumerate(run):
                a = run[max(i - 1, 0)]
                b = run[min(i + 1, len(run) - 1)]
                tdir = (b - a).normalized()
                nrm = Vector((-tdir.y, tdir.x, 0.0)) * outer_side         # zur Außenseite
                g = gfn(p.x, p.y)
                prof.append((p, tdir, nrm, g))
            top_of = [g + height for (_, _, _, g) in prof]
            # Wehrgang glätten (keine Sprünge an Hügeln)
            for _ in range(6):
                top_of = [top_of[0]] + [(top_of[i - 1] + 2 * top_of[i] + top_of[i + 1]) / 4 for i in range(1, len(top_of) - 1)] + [top_of[-1]]
            for i in range(len(prof) - 1):
                (p0, t0, n0, g0), (p1, t1, n1, g1) = prof[i], prof[i + 1]
                z0t, z1t = top_of[i], top_of[i + 1]
                zb0, zb1 = g0 - 2.0, g1 - 2.0
                o0b, o1b = p0 + n0 * (T / 2 + batter), p1 + n1 * (T / 2 + batter)
                o0, o1 = p0 + n0 * (T / 2), p1 + n1 * (T / 2)
                i0, i1 = p0 - n0 * (T / 2), p1 - n1 * (T / 2)
                zk0, zk1 = g0 + height * 0.3, g1 + height * 0.3                # Böschungsknick
                outn = (n0 + n1).normalized()
                face([Vector((o0b.x, o0b.y, zb0)), Vector((o1b.x, o1b.y, zb1)), Vector((o1.x, o1.y, zk1)), Vector((o0.x, o0.y, zk0))], outn)
                face([Vector((o0.x, o0.y, zk0)), Vector((o1.x, o1.y, zk1)), Vector((o1.x, o1.y, z1t)), Vector((o0.x, o0.y, z0t))], outn)
                face([Vector((i0.x, i0.y, zb0)), Vector((i1.x, i1.y, zb1)), Vector((i1.x, i1.y, z1t)), Vector((i0.x, i0.y, z0t))], -outn)
                face([Vector((o0.x, o0.y, z0t)), Vector((o1.x, o1.y, z1t)), Vector((i1.x, i1.y, z1t)), Vector((i0.x, i0.y, z0t))], UP)
                # Brüstung innen (0,9 m) und Zinnen außen
                pi0, pi1 = i0 + n0 * 0.45, i1 + n1 * 0.45
                face([Vector((i0.x, i0.y, z0t)), Vector((i1.x, i1.y, z1t)), Vector((i1.x, i1.y, z1t + 0.95)), Vector((i0.x, i0.y, z0t + 0.95))], -outn)
                face([Vector((pi0.x, pi0.y, z0t)), Vector((pi1.x, pi1.y, z1t)), Vector((pi1.x, pi1.y, z1t + 0.95)), Vector((pi0.x, pi0.y, z0t + 0.95))], outn)
                face([Vector((i0.x, i0.y, z0t + 0.95)), Vector((i1.x, i1.y, z1t + 0.95)), Vector((pi1.x, pi1.y, z1t + 0.95)), Vector((pi0.x, pi0.y, z0t + 0.95))], UP)
                # Brustwehr außen (durchgehend 1 m) + Zinnen
                po0, po1 = o0 - n0 * merlon[1], o1 - n1 * merlon[1]
                face([Vector((po0.x, po0.y, z0t)), Vector((po1.x, po1.y, z1t)), Vector((po1.x, po1.y, z1t + 1.0)), Vector((po0.x, po0.y, z0t + 1.0))], -outn)
                face([Vector((o0.x, o0.y, z0t)), Vector((o1.x, o1.y, z1t)), Vector((o1.x, o1.y, z1t + 1.0)), Vector((o0.x, o0.y, z0t + 1.0))], outn)
                face([Vector((o0.x, o0.y, z0t + 1.0)), Vector((o1.x, o1.y, z1t + 1.0)), Vector((po1.x, po1.y, z1t + 1.0)), Vector((po0.x, po0.y, z0t + 1.0))], UP)
                seg_len = (p1 - p0).length
                k = 0
                while k * merlon[2] < seg_len:
                    t = (k * merlon[2] + merlon[0] / 2) / max(seg_len, 1e-3)
                    if t < 1.0:
                        c = p0.lerp(p1, t) + outn * (T / 2 - merlon[1] / 2)
                        box(c, t0, merlon[0], merlon[1], 1.35, (z0t + (z1t - z0t) * t) + 1.0)
                    k += 1
                # Treppe auf der Innenseite: bis auf Brüstungshöhe, vom Podest steigt man über die Brüstung
                made_stairs += seg_len
                if made_stairs > stairs_every and i < len(prof) - 8:
                    made_stairs = 0.0
                    top = z0t + 0.95
                    steps = int((top - g0) / 0.4) + 1
                    run_len = steps * 0.42
                    base = p0 - outn * (T / 2 + 1.5)
                    for s_ in range(steps):
                        zt = g0 + (s_ + 1) * (top - g0) / steps
                        c = base + t0 * (s_ * 0.42 + 0.21)
                        box(c, t0, 0.44, 3.0, zt - (g0 - 1.0), g0 - 1.0)
                    c = base + t0 * (run_len + 1.5)
                    box(c, t0, 3.0, 3.0, top - (g0 - 1.0), g0 - 1.0)
                    self.mark_rect(c.x, c.y, run_len + 4.0, 4.0, math.degrees(math.atan2(t0.y, t0.x)), WALL)
            # Stirnseiten an Toren und Enden
            for (k_, sgn) in ((0, -1), (len(prof) - 1, 1)):
                p, tdir, nrm, g = prof[k_]
                zt = top_of[k_]
                ob, o, ii = p + nrm * (T / 2 + batter), p + nrm * (T / 2), p - nrm * (T / 2)
                face([Vector((ob.x, ob.y, g - 2.0)), Vector((ii.x, ii.y, g - 2.0)), Vector((ii.x, ii.y, zt + 0.95)),
                      Vector((o.x, o.y, zt + 1.0)), Vector((o.x, o.y, g + height * 0.3))], tdir * sgn)
            for (p, tdir, _, _) in prof:
                self.mark_rect(p.x, p.y, 4.5, T + 2 * batter + 1.0, math.degrees(math.atan2(tdir.y, tdir.x)), WALL)
        bm.normal_update()
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        me.materials.append(wall_m)
        o = bpy.data.objects.new(name, me)
        self.kit.out.objects.link(o)
        return o

    # --- Palisade und Wachtürme (Holz) ----------------------------------------------------------------------
    def _log_mats(self):
        log_m = self._named_mat("MI_PalisadeLog", "Textures_T_Log02_BC.png", "Textures_T_Log02_N.png", 0.9)
        plank_m = self._wood_mat()
        return log_m, plank_m

    @staticmethod
    def _cyl(bm, uvl, base, top_z, r, sides=8, tip=0.0, mat=0, roll=0.0):
        """Rundholz von base (x, y, z) bis top_z, optional mit Spitze (tip Meter)."""
        ring_b, ring_t = [], []
        for k in range(sides):
            a = roll + k * math.tau / sides
            ring_b.append(bm.verts.new((base[0] + math.cos(a) * r, base[1] + math.sin(a) * r, base[2])))
            ring_t.append(bm.verts.new((base[0] + math.cos(a) * r, base[1] + math.sin(a) * r, top_z)))
        h = top_z - base[2]
        for k in range(sides):
            k2 = (k + 1) % sides
            f = bm.faces.new((ring_b[k], ring_b[k2], ring_t[k2], ring_t[k]))
            f.material_index = mat
            f.smooth = True
            for lp, (u, v) in zip(f.loops, ((k / sides, 0), ((k + 1) / sides, 0), ((k + 1) / sides, h / 2.5), (k / sides, h / 2.5))):
                lp[uvl].uv = (u * 0.6, v)
        if tip > 0:
            apex = bm.verts.new((base[0], base[1], top_z + tip))
            for k in range(sides):
                k2 = (k + 1) % sides
                f = bm.faces.new((ring_t[k], ring_t[k2], apex))
                f.material_index = mat
                for lp, (u, v) in zip(f.loops, ((k / sides, h / 2.5), ((k + 1) / sides, h / 2.5), ((k + 0.5) / sides, h / 2.5 + 0.2))):
                    lp[uvl].uv = (u * 0.6, v)
        else:
            f = bm.faces.new(ring_t)
            f.material_index = mat
            for lp in f.loops:
                lp[uvl].uv = (lp.vert.co.x * 0.5, lp.vert.co.y * 0.5)

    @staticmethod
    def _beam(bm, uvl, a, b, w, h, mat, up=(0.0, 0.0, 1.0)):
        """Kantholz von Punkt a nach b (3D), Querschnitt w × h."""
        a, b = Vector(a), Vector(b)
        d = (b - a)
        L = d.length
        if L < 1e-4:
            return
        x = d / L
        z = Vector(up)
        y = z.cross(x)
        if y.length < 1e-4:
            y = Vector((0, 1, 0)).cross(x)
        y.normalize()
        z = x.cross(y).normalized()
        cs = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
        ra = [bm.verts.new(a + y * (sy * w / 2) + z * (sz * h / 2)) for sy, sz in cs]
        rb = [bm.verts.new(b + y * (sy * w / 2) + z * (sz * h / 2)) for sy, sz in cs]
        for k in range(4):
            k2 = (k + 1) % 4
            f = bm.faces.new((ra[k], ra[k2], rb[k2], rb[k]))
            f.material_index = mat
            for lp, (u, v) in zip(f.loops, ((0, 0), (0, 0.15), (L / 2, 0.15), (L / 2, 0))):
                lp[uvl].uv = (u, v + k * 0.15)
        for ring in (list(reversed(ra)), rb):                 # Stirnseiten nach außen
            f = bm.faces.new(ring)
            f.material_index = mat

    def palisade(self, loop, gates=(), gate_w=5.0, height=3.8, log_r=0.17, towers=(), tower_h=7.5, name="SM_Palisade"):
        """Palisade aus angespitzten Rundhölzern entlang einer geschlossenen Linie, Riegel innen, Torrahmen
        mit offenen Flügeln an den Toren; Wachtürme (Pfosten, Plattform, Geländer, Dach, Leiter) an `towers`."""
        import bmesh
        import bpy
        log_m, plank_m = self._log_mats()
        bm = bmesh.new()
        uvl = bm.loops.layers.uv.new("UVMap")
        gfn = self.kit.ground_fn
        rng = self.rng
        P = list(loop) + [loop[0]]
        step = log_r * 1.92
        for (ax, ay), (bx, by) in zip(P[:-1], P[1:]):
            L = math.hypot(bx - ax, by - ay)
            if L < 1e-3:
                continue
            tx, ty = (bx - ax) / L, (by - ay) / L
            n = max(1, int(L / step))
            prev_open = True
            for k in range(n):
                x, y = ax + tx * (k + 0.5) * L / n, ay + ty * (k + 0.5) * L / n
                if any(math.hypot(x - gx, y - gy) < gate_w / 2 for gx, gy in gates):
                    prev_open = True
                    continue
                g = gfn(x, y)
                hh = height * rng.uniform(0.92, 1.08)
                self._cyl(bm, uvl, (x + rng.uniform(-0.03, 0.03), y + rng.uniform(-0.03, 0.03), g - 0.6), g + hh,
                          log_r * rng.uniform(0.9, 1.1), sides=7, tip=0.45, mat=0, roll=rng.uniform(0, 1))
                self.mark_rect(x, y, step + 0.3, 1.2, math.degrees(math.atan2(ty, tx)), WALL)
            # Riegel auf der Innenseite (links der Laufrichtung = innen bei Gegenuhrzeigersinn)
            nx, ny = -ty, tx
            for frac in (0.3, 0.72):
                segs = []
                cur = []
                for k in range(n + 1):
                    x, y = ax + tx * k * L / n, ay + ty * k * L / n
                    if any(math.hypot(x - gx, y - gy) < gate_w / 2 + 0.3 for gx, gy in gates):
                        if len(cur) > 1:
                            segs.append(cur)
                        cur = []
                    else:
                        cur.append((x, y))
                if len(cur) > 1:
                    segs.append(cur)
                for s_ in segs:
                    (x0, y0), (x1, y1) = s_[0], s_[-1]
                    z0, z1 = gfn(x0, y0) + height * frac, gfn(x1, y1) + height * frac
                    o = log_r + 0.08
                    self._beam(bm, uvl, (x0 + nx * o, y0 + ny * o, z0), (x1 + nx * o, y1 + ny * o, z1), 0.14, 0.2, 1)
        # Tore: Pfosten, Sturz, offene Flügel
        for gx, gy in gates:
            # Richtung der Palisade am Tor
            best = min(zip(P[:-1], P[1:]), key=lambda ab: abs((ab[1][0] - ab[0][0]) * (gy - ab[0][1]) - (ab[1][1] - ab[0][1]) * (gx - ab[0][0])) /
                       max(math.hypot(ab[1][0] - ab[0][0], ab[1][1] - ab[0][1]), 1e-3) + 0.01 * math.hypot(
                           (ab[0][0] + ab[1][0]) / 2 - gx, (ab[0][1] + ab[1][1]) / 2 - gy))
            (ax, ay), (bx, by) = best
            L = math.hypot(bx - ax, by - ay) or 1.0
            tx, ty = (bx - ax) / L, (by - ay) / L
            g = gfn(gx, gy)
            posts = []
            for sgn in (-1, 1):
                px_, py_ = gx + tx * sgn * (gate_w / 2), gy + ty * sgn * (gate_w / 2)
                self._cyl(bm, uvl, (px_, py_, g - 0.8), g + height + 1.4, 0.24, sides=8, tip=0.0, mat=0)
                posts.append((px_, py_))
            (p0x, p0y), (p1x, p1y) = posts
            self._beam(bm, uvl, (p0x, p0y, g + height + 1.0), (p1x, p1y, g + height + 1.0), 0.3, 0.35, 1)
            nx, ny = -ty, tx
            for sgn in (-1, 1):                               # Flügel nach innen aufgeschwenkt
                hx, hy = gx + tx * sgn * (gate_w / 2 - 0.2), gy + ty * sgn * (gate_w / 2 - 0.2)
                lw = gate_w / 2 - 0.25
                ex, ey = hx + nx * lw * 0.95 - tx * sgn * lw * 0.3, hy + ny * lw * 0.95 - ty * sgn * lw * 0.3
                for z_ in (0.4, 1.6, 2.8):
                    self._beam(bm, uvl, (hx, hy, g + z_), (ex, ey, g + z_), 0.12, 0.22, 1)
                for f_ in (0.1, 0.5, 0.9):
                    bx_, by_ = hx + (ex - hx) * f_, hy + (ey - hy) * f_
                    self._beam(bm, uvl, (bx_, by_, g + 0.1), (bx_, by_, g + 3.1), 0.16, 0.16, 1, up=(nx, ny, 0))
            self.mark_rect(gx, gy, gate_w, 3.0, math.degrees(math.atan2(ty, tx)), ROAD, dirt=1.0)
        for (tx_, ty_) in towers:
            self._watchtower(bm, uvl, tx_, ty_, tower_h)
        bm.normal_update()
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        me.materials.append(log_m)
        me.materials.append(plank_m)
        o = bpy.data.objects.new(name, me)
        self.kit.out.objects.link(o)
        return o

    def _watchtower(self, bm, uvl, x, y, h, size=3.0):
        g = min(self.kit.ground_fn(x + dx, y + dy) for dx in (-size, size) for dy in (-size, size))
        s2 = size / 2
        corners = [(x - s2, y - s2), (x + s2, y - s2), (x + s2, y + s2), (x - s2, y + s2)]
        for cx_, cy_ in corners:
            self._cyl(bm, uvl, (cx_, cy_, g - 0.8), g + h + 2.5, 0.2, sides=8, mat=0)
        # Plattform (Bohlen) und Geländer
        for k in range(8):
            yy = y - s2 + (k + 0.5) * size / 8
            self._beam(bm, uvl, (x - s2 - 0.2, yy, g + h), (x + s2 + 0.2, yy, g + h), size / 8 - 0.02, 0.12, 1)
        for i in range(4):
            (ax, ay), (bx, by) = corners[i], corners[(i + 1) % 4]
            for z_ in (h + 0.55, h + 1.1):
                self._beam(bm, uvl, (ax, ay, g + z_), (bx, by, g + z_), 0.1, 0.12, 1)
            # Streben (Kreuzverband) unten
            self._beam(bm, uvl, (ax, ay, g + 0.4), (bx, by, g + h - 0.4), 0.12, 0.12, 1)
        # Dach: flache Pyramide aus Bohlen
        apex = Vector((x, y, g + h + 4.0))
        roof = [Vector((cx_ + (cx_ - x) * 0.25, cy_ + (cy_ - y) * 0.25, g + h + 2.5)) for cx_, cy_ in corners]
        for i in range(4):
            a, b = roof[i], roof[(i + 1) % 4]
            vs = [bm.verts.new(a), bm.verts.new(b), bm.verts.new(apex)]
            f = bm.faces.new(vs)
            f.material_index = 1
            for lp, uv in zip(f.loops, ((0, 0), (2.0, 0), (1.0, 1.4))):
                lp[uvl].uv = uv
        self.mark_rect(x, y, size + 1.0, size + 1.0, 0, WALL)
        self.kit.put("SM_Ladder01", x, y - s2 - 0.6, z=g, rot=0, sz=h / 2.5 * 1.05, rx=-14) if "SM_Ladder01" in self._have() else None

    # --- Wiederkehrende Bausteine einer Stadt ------------------------------------------------------------
    def market(self, x, y, r=16.0, rings=(8.5, 12.0), n=16, centerpiece=("SM_RoundOrn", 0.85), statue=("SM_Statue01", 1.1),
               wagons=True, lamps=True):
        """Marktplatz: gepflastert, Marktstände in zwei Ringen (Front zur Mitte), Karren, Laternen."""
        put = self.kit.put
        self.plaza(x, y, r)
        if centerpiece:
            put(centerpiece[0], x, y, s=centerpiece[1])
        if statue:
            put(statue[0], x, y, s=statue[1])
        for i in range(n):
            a = i * math.tau / n + self.rng.uniform(-0.05, 0.05)
            d = rings[i % len(rings)]
            px, py = x + math.cos(a) * d, y + math.sin(a) * d
            if wagons and i % 5 == 4:
                put(self.rng.choice(["SM_WoodenWagon01", "SM_WoodenWagon02"]), px, py,
                    rot=math.degrees(a) + 90 + self.rng.uniform(-25, 25))
                for _ in range(self.rng.randint(2, 4)):
                    q = self.rng.uniform(0, math.tau)
                    self.kit.ph(self.rng.choice(["wooden_crate_01", "wooden_crate_02", "wicker_basket_01", "wine_barrel_01"]),
                                px + math.cos(q) * 2.0, py + math.sin(q) * 2.0, rot=self.rng.uniform(0, 360))
            else:
                self.stall(px, py, math.degrees(a) - 90, w=self.rng.uniform(2.6, 3.4), d=self.rng.uniform(1.6, 2.0))
        if lamps:
            for k in range(4):
                a = math.radians(45 + k * 90)
                lx, ly = x + math.cos(a) * (r - 2.5), y + math.sin(a) * (r - 2.5)
                put("SM_StandLight", lx, ly)
                self.lamps.append((lx, ly, self.kit.ground_fn(lx, ly) + 2.6))

    def tavern(self, near, n_tables=3):
        """Wirtshaus: das Haus nahe `near` bekommt Tische, Hocker, Krüge und Fässer vor die Tür."""
        if not self.plots:
            return
        inn = min(self.plots, key=lambda p: math.hypot(p["x"] - near[0], p["y"] - near[1]))
        ix = inn["x"] + inn["fx"] * (inn["d"] / 2 + 2.6)
        iy = inn["y"] + inn["fy"] * (inn["d"] / 2 + 2.6)
        r = math.radians(inn["rot"])
        rng, kit = self.rng, self.kit
        for k in range(n_tables):
            tx, ty = ix + math.cos(r) * (k - (n_tables - 1) / 2) * 2.6, iy + math.sin(r) * (k - (n_tables - 1) / 2) * 2.6
            kit.ph(rng.choice(["WoodenTable_02", "WoodenTable_03", "round_wooden_table_01"]), tx, ty,
                   rot=inn["rot"] + rng.uniform(-8, 8))
            for sgn in (-1, 1):
                kit.ph(rng.choice(["wooden_stool_01", "wooden_stool_02", "WoodenChair_01"]),
                       tx - math.sin(r) * sgn * 0.85, ty + math.cos(r) * sgn * 0.85, rot=inn["rot"] + 90 * sgn + rng.uniform(-15, 15))
            kit.ph(rng.choice(["jug_01", "brass_goblets", "wooden_bowl_01"]), tx, ty, z=kit.ground_fn(tx, ty) + 0.78,
                   rot=rng.uniform(0, 360))
        kit.ph("wine_barrel_01", ix + math.cos(r) * 4.6, iy + math.sin(r) * 4.6, rot=30)
        kit.ph("wooden_barrels_01", ix - math.cos(r) * 4.8, iy - math.sin(r) * 4.8, rot=-20)
        if "SM_Sign01" in self._have():
            kit.put("SM_Sign01", inn["x"] + inn["fx"] * (inn["d"] / 2 + 0.6), inn["y"] + inn["fy"] * (inn["d"] / 2 + 0.6),
                    z=kit.ground_fn(inn["x"], inn["y"]) + 3.2, rot=inn["rot"] + 90, nocol=True)

    def outskirts(self, inside, farms=(), fields=(), trees=1400, tree_names=None, under=None, keep_clear=()):
        """Vor der Stadt: Gehöfte (Haus + Scheune + Hof), Getreidefelder, Baumgruppen und Waldränder."""
        from mathutils import Vector, noise
        put, kit, rng = self.kit.put, self.kit, self.rng
        have = self._have()
        for fx, fy, fr in farms:
            if self.rect_free(fx, fy, 30, 26, fr, (FREE,)):
                house = rng.choice([n for n in ("FV_house_01", "FV_house_04", "SM_HouseSet01") if n in have])
                self.place(house, 0.78 if house.startswith("FV") else 1.0, fx, fy, fr)
                if "SM_StorageSet" in have:
                    self.place("SM_StorageSet", 1.0, fx + math.cos(math.radians(fr)) * 16, fy + math.sin(math.radians(fr)) * 16, fr + 90)
                for p in self.plots[-2:]:
                    self.yard(p, 8.0)
        for (fx, fy, fw, fh, fr) in fields:
            r = math.radians(fr)
            for _ in range(int(fw * fh * 0.9)):
                u, v = rng.uniform(-fw / 2, fw / 2), rng.uniform(-fh / 2, fh / 2)
                x, y = fx + u * math.cos(r) - v * math.sin(r), fy + u * math.sin(r) + v * math.cos(r)
                if self.at(x, y) == FREE:
                    put(rng.choice(["SM_WheatGrass01", "SM_WheatGrass03"]), x, y, rot=rng.uniform(0, 360), nocol=True)
            self.mark_rect(fx, fy, fw, fh, fr, YARD, dirt=0.35)
            kit.occupy(fx, fy, max(fw, fh) * 0.6)
        big = tree_names or ["SM_Tree4", "SM_Tree10", "SM_Tree02", "SM_Tree09", "SM_Tree13", "SM_Spruce1", "SM_Tree03"]
        big = [b for b in big if b in have]
        under = [u for u in (under or ["SM_Bush07", "SM_Foliage_33", "SM_Foliage_56", "SM_Bush01", "SM_Foliage_22",
                                       "SM_Foliage_24"]) if u in have]
        pts = []
        for _ in range(trees):
            x, y = rng.uniform(-self.half + 4, self.half - 4), rng.uniform(-self.half + 4, self.half - 4)
            if inside(x, y) or self.at(x, y) != FREE or any(math.hypot(x - cx, y - cy) < cr for cx, cy, cr in keep_clear):
                continue
            if noise.noise(Vector((x * 0.03, y * 0.03, 1.7))) < -0.05:
                continue
            if any((x - px) ** 2 + (y - py) ** 2 < 20 for px, py in pts[-80:]):
                continue
            pts.append((x, y))
            put(rng.choice(big), x, y, rot=rng.uniform(0, 360), s=rng.uniform(0.9, 1.4), sink=0.2)
            self.mark_rect(x, y, 3, 3, 0, HOUSE)
            for _ in range(2 if under else 0):
                a, d = rng.uniform(0, math.tau), rng.uniform(1.0, 3.5)
                put(rng.choice(under), x + math.cos(a) * d, y + math.sin(a) * d, rot=rng.uniform(0, 360),
                    s=rng.uniform(0.8, 1.3), nocol=True, sink=0.05)

    def anchors(self, spawn, gate, board, keeper, slots_center, lines, inside, idle_center=None, slot_r=6.5):
        """Ankerpunkte für das Spiel: Start, Tor, Anschlagtafel, Wächter, NPC-Plätze, Laternen, Rauch, Wege."""
        empty, rng = self.kit.empty, self.rng
        empty("Spawn", spawn[0], spawn[1], rot=spawn[2] if len(spawn) > 2 else 0)
        empty("Gate", gate[0], gate[1])
        empty("Board", board[0], board[1])
        empty("Keeper", keeper[0], keeper[1], rot=keeper[2] if len(keeper) > 2 else 180)
        sx, sy = slots_center
        for i, a in enumerate([200, 235, 270, 305, 340, 20]):
            r = math.radians(a)
            empty("Slot%d" % (i + 1), sx + math.cos(r) * slot_r, sy + math.sin(r) * slot_r)
        for i, (x, y, z) in enumerate(self.lamps[:64]):
            empty("Lamp_%d" % (i + 1), x, y, z)
        for i, (x, y, z) in enumerate(self.smoke[:48]):
            empty("Smoke_%d" % (i + 1), x, y, z)
        n = 1
        for line, step in lines:
            for k in range(0, len(line), step):
                x, y = line[k]
                if inside(x, y) and self.at(x, y) in (ROAD, PLAZA):
                    empty("Walk_%d" % n, x, y)
                    n += 1
        cx, cy = idle_center or slots_center
        for i in range(12):
            a = i * math.tau / 12
            empty("Idle_%d" % (i + 1), cx + math.cos(a) * rng.uniform(4.0, 9.0), cy + math.sin(a) * rng.uniform(4.0, 9.0))
        print("OVERLORD häuser", len(self.plots), "walk", n - 1, "smoke", len(self.smoke), "lampen", len(self.lamps))
