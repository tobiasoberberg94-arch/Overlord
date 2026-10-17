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
from mathutils import Vector, noise


class Kit:
    def __init__(self, exp_dir, dst, tri_cap=None, max_tex=1024, seed=7):
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

    def put(self, name, x, y, z=None, rot=0.0, s=1.0, sz=None, rx=0.0, anchor="bottom", nocol=False, sink=0.0):
        """Instanz platzieren; Unterkante auf den Boden (z=None) bzw. auf z."""
        t = self.tpl(name)
        o = t.copy()
        o.name = ("nocol_" if nocol else "") + name
        self.out.objects.link(o)
        o.rotation_euler = (math.radians(rx), 0, math.radians(rot))
        o.scale = (s, s, s if sz is None else sz)
        o.location = (0, 0, 0)
        bpy.context.view_layer.update()
        bb = [o.matrix_world @ Vector(c) for c in o.bound_box]
        lo = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
        hi = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
        if z is None:
            z = self.ground_fn(x, y) - sink
        ref = lo.z if anchor == "bottom" else hi.z
        o.location = Vector((x - (lo.x + hi.x) / 2, y - (lo.y + hi.y) / 2, z - ref))
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

    # --- Gelände ------------------------------------------------------------------
    def terrain(self, half, flat_r, hill_h, tex, normal=None, tile=8.0, res=96, edge_rise=0.0,
                path_tex=None, path_fn=None, tint=None, path_normal=None):
        """Gelände: innen (Radius flat_r) eben, nach außen sanfte Hügel bis hill_h, Rand steigt um edge_rise."""
        def h(x, y):
            r = math.hypot(x, y)
            t = min(1.0, max(0.0, (r - flat_r) / (half - flat_r)))
            t = t * t * (3 - 2 * t)
            n = noise.noise(Vector((x * 0.035, y * 0.035, 0.3))) * 0.5 + 0.5
            return t * (hill_h * n + edge_rise * t)
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
    def _small(self, fname, normal):
        if not fname:
            return None
        if fname in self._img:
            return self._img[fname]
        src = os.path.join(self.tex_dir, fname)
        if not os.path.exists(src):
            return None
        img = bpy.data.images.load(src)
        w, h = img.size
        m = self.max_tex
        if max(w, h) > m:
            img.scale(max(1, w * m // max(w, h)), max(1, h * m // max(w, h)))
        alpha = False
        if not normal and img.channels == 4:
            px = numpy.empty(len(img.pixels), dtype=numpy.float32)
            img.pixels.foreach_get(px)
            alpha = bool(px[3::4].min() < 0.5)
        out = os.path.join(self.small_dir, os.path.splitext(fname)[0] + (".png" if alpha else ".jpg"))
        img.filepath_raw = out
        img.file_format = "PNG" if alpha else "JPEG"
        img.save()
        img.reload()
        if normal:
            img.colorspace_settings.name = "Non-Color"
        self._img[fname] = (img, alpha)
        return self._img[fname]

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
            bc = self._small(e.get("basecolor"), False)
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
    def export(self):
        tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in self.out.objects if o.type == "MESH")
        uniq = sum(sum(len(p.vertices) - 2 for p in t.data.polygons) for t in self._tpl.values())
        print("OVERLORD teile", len(self.out.objects), "dreiecke gesamt", tris, "einzigartig", uniq)
        for o in list(self.scene.collection.objects):
            self.scene.collection.objects.unlink(o)
        bpy.ops.export_scene.gltf(filepath=self.dst, export_format="GLB", export_yup=True, export_apply=True,
                                  export_lights=False, export_cameras=False, export_extras=False)
        print("OVERLORD glb", self.dst, os.path.getsize(self.dst) // (1024 * 1024), "MB")
