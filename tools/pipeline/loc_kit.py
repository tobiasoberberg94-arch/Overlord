# Gemeinsamer Baukasten für Orte aus exportierten Unreal-Bauteilen (Blender).
# Verwendung in einem Ortsskript:
#   import sys, os; sys.path.insert(0, os.path.dirname(__file__)); from loc_kit import Kit
#   kit = Kit(export_dir, ziel_glb, tri_cap={...})
#   kit.put("SM_House", x, y, rot=90) / kit.empty("Spawn", ...) / kit.terrain(...) / kit.export()
# Koordinaten: Blender (X rechts, +Y = im Spiel -Z, Z oben). Instanzen teilen ihre Geometrie.
# Objekte mit Präfix "nocol_" bekommen im Spiel keine Kollision (Gras, Büsche, Blumen).
import json
import math
import os
import random

import bmesh
import bpy
import numpy
from mathutils import Matrix, Vector, noise


class Kit:
    def __init__(self, exp_dir, dst, tri_cap=None, max_tex=2048, seed=7):
        self.exp_dir, self.dst = exp_dir, dst
        self.tri_cap = tri_cap or {}
        self.max_tex = max_tex
        self.rng = random.Random(seed)
        self.info = json.load(open(os.path.join(exp_dir, "materials.json"), encoding="utf-8"))["materials"]
        self.tex_dir = os.path.join(exp_dir, "textures")
        self.small_dir = os.path.join(os.path.dirname(dst), "_%s_tex" % os.path.splitext(os.path.basename(dst))[0])
        os.makedirs(self.small_dir, exist_ok=True)
        bpy.ops.wm.read_factory_settings(use_empty=True)
        self.scene = bpy.context.scene
        self.lib = bpy.data.collections.new("lib")
        self.out = bpy.data.collections.new("out")
        self.scene.collection.children.link(self.out)
        self._tpl = {}
        self._img = {}
        self.ground_fn = lambda x, y: 0.0
        self.on_road = lambda x, y: 0.0
        self.occupied = []
        self._nocol = []
        self.lod_names = set()     # Bäume: instanziert mit Detailstufen (write_scatter / make_lod)

    # --- Bauteile ---------------------------------------------------------------
    def _load(self, name):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.fbx(filepath=os.path.join(self.exp_dir, "meshes", name + ".fbx"))
        new = [o for o in bpy.data.objects if o not in before]
        meshes = [o for o in new if o.type == "MESH"]
        for o in new:
            for c in o.users_collection:
                c.objects.unlink(o)
        for o in [o for o in new if o.type != "MESH"]:
            bpy.data.objects.remove(o)
        for o in meshes:
            self.scene.collection.objects.link(o)
            o.select_set(True)
        bpy.context.view_layer.objects.active = meshes[0]
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        if len(meshes) > 1:
            bpy.ops.object.join()
        o = bpy.context.view_layer.objects.active
        cap = self.tri_cap.get(name)
        tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
        if cap and tris > cap:
            mod = o.modifiers.new("dec", "DECIMATE")
            mod.ratio = cap / tris
            mod.use_collapse_triangulate = True
            bpy.ops.object.modifier_apply(modifier="dec")
            print("OVERLORD reduziert", name, tris, "->", sum(len(p.vertices) - 2 for p in o.data.polygons))
        o.select_set(False)
        self.scene.collection.objects.unlink(o)
        self.lib.objects.link(o)
        o.name = name
        return o

    def tpl(self, name):
        if name not in self._tpl:
            self._tpl[name] = self._load(name)
        return self._tpl[name]

    def size(self, name):
        return Vector(self.tpl(name).dimensions)

    def put(self, name, x, y, z=None, rot=0.0, s=1.0, sz=None, rx=0.0, anchor="bottom", nocol=False, sink=0.0,
            origin=False):
        """Instanz platzieren; Unterkante auf den Boden (z=None) bzw. auf z.
        nocol-Instanzen (Gras, Blumen, Kleinkram) werden nur vorgemerkt und beim Export je Kachel
        direkt zu einem Mesh zusammengesetzt – tausende Objekte wären in Blender quadratisch langsam."""
        t = self.tpl(name)
        m = (Matrix.Rotation(math.radians(rot), 4, "Z") @ Matrix.Rotation(math.radians(rx), 4, "X")
             @ Matrix.Diagonal((s, s, s if sz is None else sz, 1.0)))
        bb = [m @ Vector(c) for c in t.bound_box]
        lo = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
        hi = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
        if z is None:
            z = self.ground_fn(x, y) - sink
        ref = lo.z if anchor == "bottom" else hi.z
        loc = Vector((x - (lo.x + hi.x) / 2, y - (lo.y + hi.y) / 2, z - ref))
        if origin:                                   # Ursprung des Bauteils exakt auf (x, y, z) (zusammengesetzte Teile)
            loc = Vector((x, y, z))
        if nocol:
            self._nocol.append((name, Matrix.Translation(loc) @ m))
            return None
        if name in self.lod_names:
            self._nocol.append(("@lod:" + name, Matrix.Translation(loc) @ m))
            return None
        o = t.copy()
        o.name = name
        self.out.objects.link(o)
        o.matrix_world = Matrix.Translation(loc) @ m
        return o

    def empty(self, name, x, y, z=None, rot=0.0):
        e = bpy.data.objects.new(name, None)
        e.location = (x, y, self.ground_fn(x, y) if z is None else z)
        e.rotation_euler.z = math.radians(rot)
        self.out.objects.link(e)
        return e

    def scatter(self, names, n, area, avoid=(), nocol=True, s=(0.8, 1.3), min_d=0.0):
        """n zufällige Instanzen im Rechteck area=(x0, y0, x1, y1), nicht in avoid-Rechtecken."""
        placed, tries = 0, 0
        pts = []
        while placed < n and tries < n * 30:
            tries += 1
            x = self.rng.uniform(area[0], area[2])
            y = self.rng.uniform(area[1], area[3])
            if any(a[0] <= x <= a[2] and a[1] <= y <= a[3] for a in avoid):
                continue
            if min_d and any((x - px) ** 2 + (y - py) ** 2 < min_d * min_d for px, py in pts):
                continue
            pts.append((x, y))
            self.put(self.rng.choice(names), x, y, rot=self.rng.uniform(0, 360), s=self.rng.uniform(*s), nocol=nocol, sink=0.05)
            placed += 1
        return placed

    # --- Natürliche Layouts ---------------------------------------------------------------
    @staticmethod
    def spline(pts, step=1.0):
        """Catmull-Rom durch Kontrollpunkte -> dichte Polylinie [(x, y), ...]."""
        P = [pts[0]] + list(pts) + [pts[-1]]
        out = []
        for i in range(1, len(P) - 2):
            p0, p1, p2, p3 = (Vector((P[j][0], P[j][1], 0)) for j in (i - 1, i, i + 1, i + 2))
            n = max(2, int((p2 - p1).length / step))
            for k in range(n):
                t = k / n
                t2, t3 = t * t, t * t * t
                q = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
                out.append((q.x, q.y))
        out.append(tuple(pts[-1]))
        return out

    def roads_mask(self, roads, half, cell=0.5):
        """roads: [(polylinie, breite)] -> Funktion path_fn(x, y) über ein Raster (schnell)."""
        n = int(2 * half / cell)
        grid = numpy.zeros((n, n), dtype=numpy.float32)
        xs = (numpy.arange(n) + 0.5) * cell - half
        for line, width in roads:
            r = width / 2.0
            for (ax, ay), (bx, by) in zip(line[:-1], line[1:]):
                x0, x1 = min(ax, bx) - r - 1, max(ax, bx) + r + 1
                y0, y1 = min(ay, by) - r - 1, max(ay, by) + r + 1
                i0, i1 = max(0, int((x0 + half) / cell)), min(n, int((x1 + half) / cell) + 1)
                j0, j1 = max(0, int((y0 + half) / cell)), min(n, int((y1 + half) / cell) + 1)
                if i0 >= i1 or j0 >= j1:
                    continue
                X, Y = numpy.meshgrid(xs[i0:i1], xs[j0:j1], indexing="ij")
                dx, dy = bx - ax, by - ay
                L = dx * dx + dy * dy or 1e-6
                t = numpy.clip(((X - ax) * dx + (Y - ay) * dy) / L, 0, 1)
                d = numpy.hypot(X - (ax + t * dx), Y - (ay + t * dy))
                rr = r + (numpy.sin(X * 1.7) * numpy.cos(Y * 1.3)) * 0.35      # ausgefranste Ränder
                grid[i0:i1, j0:j1] = numpy.maximum(grid[i0:i1, j0:j1], (d < rr).astype(numpy.float32))

        def fn(x, y):
            i, j = int((x + half) / cell), int((y + half) / cell)
            if 0 <= i < n and 0 <= j < n:
                return float(grid[i, j])
            return 0.0
        self.on_road = fn
        return fn

    def free(self, x, y, r):
        """Platz frei? (keine Straße, keine belegte Fläche)."""
        if self.on_road(x, y) > 0.5:
            return False
        for k in range(8):
            a = k * math.pi / 4
            if self.on_road(x + math.cos(a) * r * 0.8, y + math.sin(a) * r * 0.8) > 0.5:
                return False
        return all((x - px) ** 2 + (y - py) ** 2 > (r + pr) ** 2 for px, py, pr in self.occupied)

    def occupy(self, x, y, r):
        self.occupied.append((x, y, r))

    def along(self, line, names, spacing=(12, 18), setback=(7, 10), sides=(-1, 1), s=(1.0, 1.0),
              jitter=10.0, radius=None, skip=0.15, on_place=None, start=0.0, end=None, gap=None):
        """Gebäude entlang einer Polylinie, Front (lokal -Y) zur Straße gedreht.
        names: Namen oder (name, skalierung); gap: Abstand Front–Straßenmitte (statt setback)."""
        cum = [0.0]
        for (ax, ay), (bx, by) in zip(line[:-1], line[1:]):
            cum.append(cum[-1] + math.hypot(bx - ax, by - ay))
        total = cum[-1] if end is None else min(end, cum[-1])
        placed = []
        for side in sides:
            d = start + self.rng.uniform(*spacing) * 0.5
            while d < total:
                i = next((k for k in range(len(cum) - 1) if cum[k + 1] >= d), len(line) - 2)
                t = (d - cum[i]) / max(1e-6, cum[i + 1] - cum[i])
                (ax, ay), (bx, by) = line[i], line[i + 1]
                px, py = ax + (bx - ax) * t, ay + (by - ay) * t
                tx, ty = (bx - ax), (by - ay)
                L = math.hypot(tx, ty) or 1
                nx, ny = -ty / L * side, tx / L * side
                name = self.rng.choice(names)
                sc = self.rng.uniform(*s)
                if isinstance(name, tuple):
                    name, sc = name[0], name[1] * sc
                sz = self.size(name)
                sb = self.rng.uniform(*setback) if gap is None else self.rng.uniform(*gap) + sz.y * sc * 0.5
                hx, hy = px + nx * sb, py + ny * sb
                rad = radius or max(sz.x, sz.y) * sc * 0.5
                if self.rng.random() > skip and self.free(hx, hy, rad):
                    # lokales -Y zeigt zur Straße: R(theta)*(0,-1) = (sin, -cos) = -n
                    rot = math.degrees(math.atan2(-nx, ny)) + self.rng.uniform(-jitter, jitter)
                    self.put(name, hx, hy, rot=rot, s=sc, sink=0.15)
                    self.occupy(hx, hy, rad)
                    placed.append((hx, hy, rot, rad, name))
                    if on_place:
                        on_place(hx, hy, rot, rad, name)
                d += self.rng.uniform(*spacing)
        return placed

    def forest(self, area, names, n, density_scale=0.04, threshold=0.05, s=(0.9, 1.4), min_d=3.0,
               avoid=(), under=None, under_n=2, nocol=False):
        """Wald mit natürlichen Gruppen: eine Rauschkarte entscheidet, wo Bäume dicht stehen."""
        pts = []
        tries = 0
        while len(pts) < n and tries < n * 40:
            tries += 1
            x = self.rng.uniform(area[0], area[2])
            y = self.rng.uniform(area[1], area[3])
            v = noise.noise(Vector((x * density_scale, y * density_scale, 1.7)))
            if v < threshold + self.rng.uniform(-0.25, 0.25):
                continue
            if any(a[0] <= x <= a[2] and a[1] <= y <= a[3] for a in avoid):
                continue
            if self.on_road(x, y) > 0.5 or not all((x - px) ** 2 + (y - py) ** 2 > min_d * min_d for px, py in pts):
                continue
            if not all((x - px) ** 2 + (y - py) ** 2 > (pr + 1.5) ** 2 for px, py, pr in self.occupied):
                continue
            pts.append((x, y))
            self.put(self.rng.choice(names), x, y, rot=self.rng.uniform(0, 360), s=self.rng.uniform(*s), sink=0.2, nocol=nocol)
            if under:
                for _ in range(under_n):
                    a = self.rng.uniform(0, math.tau)
                    r = self.rng.uniform(1.0, 3.5)
                    self.put(self.rng.choice(under), x + math.cos(a) * r, y + math.sin(a) * r,
                             rot=self.rng.uniform(0, 360), s=self.rng.uniform(0.8, 1.3), nocol=True, sink=0.05)
        return pts

    def clutter(self, x, y, names, n=(2, 5), r=(0.8, 2.5), s=(0.85, 1.15), nocol=False):
        """Kleine Gruppe von Gegenständen um einen Punkt (Fässer, Kisten, Holz ...)."""
        for _ in range(self.rng.randint(*n)):
            a = self.rng.uniform(0, math.tau)
            d = self.rng.uniform(*r)
            px, py = x + math.cos(a) * d, y + math.sin(a) * d
            if self.on_road(px, py) > 0.5:
                continue
            self.put(self.rng.choice(names), px, py, rot=self.rng.uniform(0, 360), s=self.rng.uniform(*s), nocol=nocol)

    def meadow(self, area, names, n, avoid=(), s=(0.8, 1.4), patch=None):
        """Bodenbewuchs ohne Kollision; patch=(namen, anzahl, radius) für Blumeninseln."""
        placed = 0
        tries = 0
        while placed < n and tries < n * 6:
            tries += 1
            x = self.rng.uniform(area[0], area[2])
            y = self.rng.uniform(area[1], area[3])
            if self.on_road(x, y) > 0.5 or any(a[0] <= x <= a[2] and a[1] <= y <= a[3] for a in avoid):
                continue
            if any((x - px) ** 2 + (y - py) ** 2 < (pr * 0.8) ** 2 for px, py, pr in self.occupied):
                continue
            self.put(self.rng.choice(names), x, y, rot=self.rng.uniform(0, 360), s=self.rng.uniform(*s), nocol=True, sink=0.03)
            placed += 1
        if patch:
            pn, count, rad = patch
            for _ in range(count):
                cx = self.rng.uniform(area[0], area[2])
                cy = self.rng.uniform(area[1], area[3])
                if self.on_road(cx, cy) > 0.5 or any(a[0] <= cx <= a[2] and a[1] <= cy <= a[3] for a in avoid):
                    continue
                for _ in range(self.rng.randint(6, 14)):
                    a = self.rng.uniform(0, math.tau)
                    d = self.rng.uniform(0, rad)
                    px, py = cx + math.cos(a) * d, cy + math.sin(a) * d
                    if self.on_road(px, py) < 0.5:
                        self.put(self.rng.choice(pn), px, py, rot=self.rng.uniform(0, 360), nocol=True, sink=0.03)

    def merge_nocol(self, chunk=40.0):
        """Vorgemerkte nocol-Instanzen je Vorlage und Kachel direkt zu einem Mesh zusammensetzen."""
        import bmesh
        groups = {}
        for name, mw in self._nocol:
            k = (name, int(mw.translation.x // chunk), int(mw.translation.y // chunk))
            groups.setdefault(k, []).append(mw)
        for (name, cx, cy), mats in groups.items():
            t = self._tpl[name]
            bm = bmesh.new()
            for mw in mats:
                start = len(bm.verts)
                bm.from_mesh(t.data)
                bm.verts.ensure_lookup_table()
                bmesh.ops.transform(bm, matrix=mw, verts=bm.verts[start:])
            me = bpy.data.meshes.new("nocol_%s_%d_%d" % (name, cx, cy))
            bm.to_mesh(me)
            bm.free()
            for mat in t.data.materials:
                me.materials.append(mat)
            o = bpy.data.objects.new(me.name, me)
            self.out.objects.link(o)
        print("OVERLORD zusammengefasst", len(self._nocol), "Kleinobjekte in", len(groups), "Gruppen")

    def terrain(self, half, flat_r, hill_h, tex, normal=None, tile=8.0, res=96, edge_rise=0.0,
                path_tex=None, path_fn=None, tint=None, path_normal=None, inner_h=0.0):
        """Gelände: innen (Radius flat_r) eben, nach außen sanfte Hügel bis hill_h, Rand steigt um edge_rise."""
        def h(x, y):
            r = math.hypot(x, y)
            t = min(1.0, max(0.0, (r - flat_r) / (half - flat_r)))
            t = t * t * (3 - 2 * t)
            n = noise.noise(Vector((x * 0.035, y * 0.035, 0.3))) * 0.5 + 0.5
            w = noise.noise(Vector((x * 0.06, y * 0.06, 4.1)))
            return t * (hill_h * n + edge_rise * t) + inner_h * w
        self.ground_fn = h
        me = bpy.data.meshes.new("ground")
        bm = bmesh.new()
        bmesh.ops.create_grid(bm, x_segments=res, y_segments=res, size=half)
        uv = bm.loops.layers.uv.new("UVMap")
        for v in bm.verts:
            v.co.z = h(v.co.x, v.co.y)
        for f in bm.faces:
            for l in f.loops:
                l[uv].uv = (l.vert.co.x / tile, l.vert.co.y / tile)
        bm.to_mesh(me)
        bm.free()
        for p in me.polygons:
            p.use_smooth = True
        o = bpy.data.objects.new("Ground", me)
        self.out.objects.link(o)
        mat = bpy.data.materials.new("Ground")
        mat.use_nodes = True
        nt = mat.node_tree
        b = nt.nodes["Principled BSDF"]
        b.inputs["Roughness"].default_value = 0.95
        img = self._small(tex, False)
        if img:
            t = nt.nodes.new("ShaderNodeTexImage")
            t.image = img[0]
            src = t.outputs["Color"]
            if tint:
                mul = nt.nodes.new("ShaderNodeMix")
                mul.data_type = "RGBA"
                mul.blend_type = "MULTIPLY"
                mul.inputs["Factor"].default_value = 1.0
                nt.links.new(src, mul.inputs[6])
                mul.inputs[7].default_value = (*tint, 1.0)
                src = mul.outputs[2]
            nt.links.new(src, b.inputs["Base Color"])
        nimg = self._small(normal, True) if normal else None
        if nimg:
            t = nt.nodes.new("ShaderNodeTexImage")
            t.image = nimg[0]
            nm = nt.nodes.new("ShaderNodeNormalMap")
            nt.links.new(t.outputs["Color"], nm.inputs["Color"])
            nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
        me.materials.append(mat)
        self._ground_mats = [mat]
        if path_tex and path_fn:
            pm = self._simple_mat("GroundPath", path_tex, path_normal, 0.9)
            me.materials.append(pm)
            self._ground_mats.append(pm)
            for poly in me.polygons:
                c = poly.center
                if path_fn(c.x, c.y) > 0.5:
                    poly.material_index = 1
            # Weiche Wegmaske je Eckpunkt (Farbattribut, im Spiel blendet ein Shader Gras -> Weg)
            col = me.color_attributes.new("PathMask", "FLOAT_COLOR", "POINT")
            ring = [(0, 0)] + [(math.cos(k * math.pi / 4) * 0.9, math.sin(k * math.pi / 4) * 0.9) for k in range(8)]
            for v in me.vertices:
                m = sum(path_fn(v.co.x + dx, v.co.y + dy) for dx, dy in ring) / len(ring)
                col.data[v.index].color = (m, m, m, 1.0)
            me.color_attributes.active_color = col
        return o

    def _simple_mat(self, name, tex, normal, rough):
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        nt = mat.node_tree
        b = nt.nodes["Principled BSDF"]
        b.inputs["Roughness"].default_value = rough
        img = self._small(tex, False)
        if img:
            t = nt.nodes.new("ShaderNodeTexImage")
            t.image = img[0]
            nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
        nimg = self._small(normal, True) if normal else None
        if nimg:
            t = nt.nodes.new("ShaderNodeTexImage")
            t.image = nimg[0]
            nm = nt.nodes.new("ShaderNodeNormalMap")
            nt.links.new(t.outputs["Color"], nm.inputs["Color"])
            nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
        return mat

    # --- Materialien ----------------------------------------------------------------
    def _small(self, fname, normal, opacity=None):
        """Textur verkleinern; opacity = Graubild (Transparenzmaske aus export_opacity.py) → Alphakanal."""
        if not fname:
            return None
        key = fname + "|" + (opacity or "")
        if key in self._img:
            return self._img[key]
        src = os.path.join(self.tex_dir, fname)
        if not os.path.exists(src):
            return None
        img = bpy.data.images.load(src)
        if opacity:
            img = img.copy()
        w, h = img.size
        m = self.max_tex
        if max(w, h) > m:
            img.scale(max(1, w * m // max(w, h)), max(1, h * m // max(w, h)))
        alpha = False
        osrc = os.path.join(self.tex_dir, opacity) if opacity else None
        if not normal and osrc and os.path.exists(osrc):
            mask = bpy.data.images.load(osrc)
            mask.scale(*img.size)
            mp = numpy.empty(len(mask.pixels), dtype=numpy.float32)
            mask.pixels.foreach_get(mp)
            px = numpy.empty(img.size[0] * img.size[1] * 4, dtype=numpy.float32)
            if img.channels == 4:
                img.pixels.foreach_get(px)
            else:
                rgb = numpy.empty(len(img.pixels), dtype=numpy.float32)
                img.pixels.foreach_get(rgb)
                px = px.reshape(-1, 4)
                px[:, :3] = rgb.reshape(-1, img.channels)[:, :3]
                px = px.reshape(-1)
            px = px.reshape(-1, 4)
            px[:, 3] = numpy.clip(mp.reshape(-1, mask.channels)[:, 0], 0.0, 1.0)
            if img.channels != 4:
                img = bpy.data.images.new(os.path.splitext(fname)[0] + "_rgba", img.size[0], img.size[1], alpha=True)
            img.pixels.foreach_set(px.reshape(-1))
            alpha = bool(px[:, 3].min() < 0.5)
            bpy.data.images.remove(mask)
        elif not normal and img.channels == 4:
            px = numpy.empty(len(img.pixels), dtype=numpy.float32)
            img.pixels.foreach_get(px)
            alpha = bool(px[3::4].min() < 0.5)
        out = os.path.join(self.small_dir, os.path.splitext(fname)[0] + ("_m" if opacity else "") + (".png" if alpha else ".jpg"))
        img.filepath_raw = out
        img.file_format = "PNG" if alpha else "JPEG"
        img.save()
        img.reload()
        if normal:
            img.colorspace_settings.name = "Non-Color"
        self._img[key] = (img, alpha)
        return self._img[key]

    def finish_materials(self, metal_keys=()):
        for mat in bpy.data.materials:
            if mat in getattr(self, "_ground_mats", []):
                continue
            e = self.info.get(mat.name.split(".")[0], {})
            mat.use_nodes = True
            mat.use_backface_culling = False
            nt = mat.node_tree
            nt.nodes.clear()
            out = nt.nodes.new("ShaderNodeOutputMaterial")
            b = nt.nodes.new("ShaderNodeBsdfPrincipled")
            nt.links.new(b.outputs["BSDF"], out.inputs["Surface"])
            b.inputs["Roughness"].default_value = 0.8
            bc = self._small(e.get("basecolor"), False, e.get("opacity"))
            if bc:
                t = nt.nodes.new("ShaderNodeTexImage")
                t.image = bc[0]
                nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
                if bc[1]:
                    r = nt.nodes.new("ShaderNodeMath")
                    r.operation = "ROUND"            # glTF: alphaMode MASK
                    nt.links.new(t.outputs["Alpha"], r.inputs[0])
                    nt.links.new(r.outputs[0], b.inputs["Alpha"])
            else:
                b.inputs["Base Color"].default_value = (0.25, 0.22, 0.2, 1)
            nm = self._small(e.get("normal"), True)
            if nm:
                t = nt.nodes.new("ShaderNodeTexImage")
                t.image = nm[0]
                n2 = nt.nodes.new("ShaderNodeNormalMap")
                nt.links.new(t.outputs["Color"], n2.inputs["Color"])
                nt.links.new(n2.outputs["Normal"], b.inputs["Normal"])
            if any(k in mat.name.lower() for k in metal_keys):
                b.inputs["Metallic"].default_value = 0.5
                b.inputs["Roughness"].default_value = 0.45
            if "glass" in mat.name.lower():
                b.inputs["Roughness"].default_value = 0.1

    # --- Export ---------------------------------------------------------------------
    def grass(self, area, n, kind="@grass", avoid=(), s=(0.8, 1.3), road_ok=False):
        """Prozedurales Gras/Wildblumen (im Spiel erzeugt, scripts/world3d/grass.gd): nur Positionen."""
        placed, tries = 0, 0
        while placed < n and tries < n * 4:
            tries += 1
            x = self.rng.uniform(area[0], area[2])
            y = self.rng.uniform(area[1], area[3])
            if (not road_ok and self.on_road(x, y) > 0.3) or any(a[0] <= x <= a[2] and a[1] <= y <= a[3] for a in avoid):
                continue
            if any((x - px) ** 2 + (y - py) ** 2 < (pr * 0.85) ** 2 for px, py, pr in self.occupied):
                continue
            sc = self.rng.uniform(*s)
            m = Matrix.Translation((x, y, self.ground_fn(x, y) - 0.03)) @ Matrix.Rotation(self.rng.uniform(0, math.tau), 4, "Z")                 @ Matrix.Diagonal((sc, sc, sc, 1.0))
            self._nocol.append((kind, m))
            placed += 1

    def make_lod(self, name, keep):
        """Detailstufe eines Baums: Blattkarten (Materialien mit Alphamaske) werden ausgedünnt und die
        verbleibenden etwas vergrößert – die Blattform bleibt erhalten. Stamm/Äste werden reduziert."""
        import bmesh
        t = self._tpl[name]
        o = t.copy()
        o.data = t.data.copy()
        if keep >= 1.0:
            return o
        me = o.data
        leafy = set()
        for i, mat in enumerate(me.materials):
            e = self.info.get(mat.name.split(".")[0], {}) if mat else {}
            if e.get("opacity") or (mat and any(k in mat.name.lower() for k in ("leaf", "leav", "foliage", "needle", "pine"))):
                leafy.add(i)
        bm = bmesh.new()
        bm.from_mesh(me)
        bm.faces.ensure_lookup_table()
        seen = set()
        kill, grow = [], []
        rng = random.Random(hash(name) & 0xffff)
        for f in bm.faces:
            if f.index in seen or f.material_index not in leafy:
                continue
            island, stack = [], [f]
            seen.add(f.index)
            while stack:                       # zusammenhängende Blattkarte
                g = stack.pop()
                island.append(g)
                for e in g.edges:
                    for h in e.link_faces:
                        if h.index not in seen and h.material_index == g.material_index:
                            seen.add(h.index)
                            stack.append(h)
            (grow if rng.random() < keep else kill).append(island)
        sc = min(1.0 / keep ** 0.5, 2.2)
        for island in grow:
            vs = {v for g in island for v in g.verts}
            c = sum((v.co for v in vs), Vector()) / len(vs)
            for v in vs:
                v.co = c + (v.co - c) * sc
        bmesh.ops.delete(bm, geom=list({g for isl in kill for g in isl}), context="FACES")
        bm.to_mesh(me)
        bm.free()
        trunk = {v for p_ in me.polygons if p_.material_index not in leafy for v in p_.vertices}
        if trunk:
            vg = o.vertex_groups.new(name="trunk")          # nur Stamm/Äste reduzieren, Blattkarten bleiben ganz
            vg.add(list(trunk), 1.0, "REPLACE")
            mod = o.modifiers.new("dec", "DECIMATE")
            mod.vertex_group = "trunk"
            mod.ratio = max(0.15, keep * 1.5)
            mod.use_collapse_triangulate = True
            self.scene.collection.objects.link(o)
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.modifier_apply(modifier="dec")
            self.scene.collection.objects.unlink(o)
        return o

    def write_scatter(self):
        """nocol-Instanzen als <ziel>_scatter.json (GPU-Instancing im Spiel, MultiMesh) + je Vorlage ein
        Mesh-Objekt nocol_mm_<name> im Modell. Transformationen in Blender-Koordinaten (Z oben)."""
        groups = {}
        for name, mw in self._nocol:
            # schwere Kleinpflanzen (Blumenbüschel, Sträucher) bekommen ebenfalls Detailstufen
            if not name.startswith("@") and sum(len(p.vertices) - 2 for p in self._tpl[name].data.polygons) > 1500:
                name = "@lod:" + name
            groups.setdefault(name, []).append([round(mw[r][c], 4) for r in range(3) for c in range(4)])
        for name in groups:
            if name.startswith("@lod:"):
                base = name[5:]
                for lvl, keep in ((0, 1.0), (1, 0.25), (2, 0.07)):
                    o = self.make_lod(base, keep)
                    o.name = "nocol_mm_lod%d_%s" % (lvl, base)
                    self.out.objects.link(o)
                    o.location = (0, 0, -200)
                continue
            if name.startswith("@"):
                continue
            o = self._tpl[name].copy()
            o.name = "nocol_mm_" + name
            self.out.objects.link(o)
            o.location = (0, 0, -200)
        path = os.path.splitext(self.dst)[0] + "_scatter.json"
        json.dump({"version": 1, "instances": groups}, open(path, "w"))
        tris = sum(len(v) * sum(len(p.vertices) - 2 for p in self._tpl[k].data.polygons) for k, v in groups.items()
                   if not k.startswith("@"))
        per = sorted(((k, len(v) * sum(len(p.vertices) - 2 for p in self._tpl[k].data.polygons)) for k, v in groups.items()
                      if not k.startswith("@")),
                     key=lambda kv: -kv[1])
        print("OVERLORD instanzen schwer", per[:8])
        print("OVERLORD instanzen", len(self._nocol), "vorlagen", len(groups), "dreiecke", tris, path)

    def export(self, merge=False):
        if merge:
            self.merge_nocol()
        else:
            self.write_scatter()
        tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in self.out.objects if o.type == "MESH")
        uniq = sum(sum(len(p.vertices) - 2 for p in t.data.polygons) for t in self._tpl.values())
        print("OVERLORD teile", len(self.out.objects), "dreiecke gesamt", tris, "einzigartig", uniq)
        per = {}
        for o in self.out.objects:
            if o.type == "MESH":
                k = o.name.split(".")[0]
                per[k] = per.get(k, 0) + sum(len(p.vertices) - 2 for p in o.data.polygons)
        print("OVERLORD schwer", sorted(per.items(), key=lambda kv: -kv[1])[:10])
        for o in list(self.scene.collection.objects):
            self.scene.collection.objects.unlink(o)
        for me in bpy.data.meshes:                  # nur das Gelände trägt Farbattribute (Wegmaske)
            if not me.color_attributes.get("PathMask"):
                for ca in list(me.color_attributes):
                    me.color_attributes.remove(ca)
        bpy.ops.export_scene.gltf(filepath=self.dst, export_format="GLB", export_yup=True, export_apply=True,
                                  export_lights=False, export_cameras=False, export_extras=False,
                                  export_vertex_color="ACTIVE", export_image_format="WEBP", export_image_quality=88)
        print("OVERLORD glb", self.dst, os.path.getsize(self.dst) // (1024 * 1024), "MB")
