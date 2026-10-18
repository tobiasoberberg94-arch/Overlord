# Zusatz für build_scene.py (Lavahöhle): Lavarinnen ins Gelände graben + Lavafläche „Lava“ (Shader im Spiel).
import bmesh
import bpy
from mathutils import noise

g = next(o for o in kit.out.objects if o.name.startswith("Ground"))
keep = [Vector(p) for p in opt.get("lava_keep", [])]          # freie Plätze (Spawn, Arena …)
L = opt.get("lava_level", 0.55)
me = g.data
cut = 0
for v in me.vertices:
    p = v.co
    if any((Vector((p.x, p.y, 0)) - Vector((k.x, k.y, 0))).length < k.z for k in keep):
        continue
    n = abs(noise.noise(Vector((p.x * 0.018, p.y * 0.018, 0.7))))           # 0 an den „Flussläufen“
    w = abs(noise.noise(Vector((p.x * 0.05, p.y * 0.05, 3.1)))) * 0.04
    if n < 0.075 + w:
        d = (0.075 + w - n) / 0.075
        v.co.z -= min(1.6, 0.6 + d * 1.4)
        cut += 1
me.update()
print("OVERLORD lavarinnen punkte", cut)
# Lavafläche über dem ganzen Gelände (sichtbar nur in den Rinnen), eigenes Material „Lava“
xs = [v.co.x for v in me.vertices]; ys = [v.co.y for v in me.vertices]
bm = bmesh.new()
bmesh.ops.create_grid(bm, x_segments=40, y_segments=40, size=0.5)
pl = bpy.data.meshes.new("Lava"); bm.to_mesh(pl); bm.free()
lo = bpy.data.objects.new("nocol_Lava", pl)
lo.scale = (max(xs) - min(xs), max(ys) - min(ys), 1)
zs = sorted(v.co.z for v in me.vertices)
base = zs[len(zs) // 2]                                   # typische Bodenhöhe (Median)
lo.location = ((max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2, base - (1.0 - L))
print("OVERLORD lava hoehe", round(base - (1.0 - L), 2), "boden", round(base, 2))
lm = bpy.data.materials.new("Lava")
lm.use_nodes = True
b = lm.node_tree.nodes["Principled BSDF"]
b.inputs["Base Color"].default_value = (1.0, 0.25, 0.02, 1)
b.inputs["Emission Color"].default_value = (1.0, 0.3, 0.02, 1)
b.inputs["Emission Strength"].default_value = 3.0
pl.materials.append(lm)
kit.out.objects.link(lo)
kit._ground_mats = getattr(kit, "_ground_mats", []) + [lm]
