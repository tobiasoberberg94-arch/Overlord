# Zusatz für build_scene.py (Schatzkammer): Goldberge, Münzteppiche und Schätze an den angegebenen Stellen.
#   opt["gold"] = [[x, y, z_boden, radius, höhe], …]   opt["treasure_area"] = [[x0, x1, y0, y1, z], …]
import bmesh
import bpy
from mathutils import noise

rng = kit.rng
gm = bpy.data.materials.new("GoldPile")
gm.use_nodes = True
b = gm.node_tree.nodes["Principled BSDF"]
b.inputs["Base Color"].default_value = (1.0, 0.72, 0.22, 1)
b.inputs["Metallic"].default_value = 1.0
b.inputs["Roughness"].default_value = 0.28
kit._ground_mats = getattr(kit, "_ground_mats", []) + [gm]

# Münze als Vorlage für GPU-Instancing
bm = bmesh.new()
bmesh.ops.create_cone(bm, cap_ends=True, segments=12, radius1=0.035, radius2=0.035, depth=0.006)
cm = bpy.data.meshes.new("GoldCoin"); bm.to_mesh(cm); bm.free()
cm.materials.append(gm)
coin = bpy.data.objects.new("GoldCoin", cm)
kit.lib.objects.link(coin)
kit._tpl["GoldCoin"] = coin

for (x, y, z0, r, h) in opt.get("gold", []):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=48, v_segments=24, radius=1.0)
    for v in bm.verts:
        if v.co.z < 0:
            v.co.z = 0.0
        n = noise.noise(v.co * 3.1 + Vector((x, y, 0))) * 0.12 + noise.noise(v.co * 9.0) * 0.03
        v.co = Vector((v.co.x * r * (1 + n), v.co.y * r * (1 + n), v.co.z * h * (1 + n * 0.5)))
    me = bpy.data.meshes.new("GoldPile"); bm.to_mesh(me); bm.free()
    for p in me.polygons:
        p.use_smooth = True
    me.materials.append(gm)
    o = bpy.data.objects.new("GoldPile", me)
    o.location = (x, y, z0 - 0.05)
    kit.out.objects.link(o)
    # verstreute Münzen am Fuß des Bergs und darauf
    for _ in range(int(r * r * 60)):
        a = rng.uniform(0, math.tau); d = rng.uniform(0.2, r * 1.35)
        px, py = x + math.cos(a) * d, y + math.sin(a) * d
        t = max(0.0, 1 - (d / r) ** 2)
        pz = z0 + (h * math.sqrt(t) if d < r else 0.0) + 0.004
        m = Matrix.Translation((px, py, pz)) @ Matrix.Rotation(rng.uniform(0, math.tau), 4, "Z") @ \
            Matrix.Rotation(rng.uniform(-0.5, 0.5), 4, "X")
        kit._nocol.append(("GoldCoin", m))
    # Schätze: Schalen, Vasen, Kerzenleuchter, Truhen ringsum
    for k in range(int(r * 2.5)):
        a = rng.uniform(0, math.tau); d = r * rng.uniform(0.95, 1.4)
        kit.put(rng.choice(["SM_Vase01", "SM_Vase02", "SM_Dish01", "SM_Dish02", "SM_CandleStick01", "SM_WoodenBox01", "SM_Bottle01"]),
                x + math.cos(a) * d, y + math.sin(a) * d, z=z0, rot=rng.uniform(0, 360), s=rng.uniform(0.5, 0.9))

for (x0, x1, y0, y1, z) in opt.get("treasure_area", []):
    for _ in range(int((x1 - x0) * (y1 - y0) * 8)):
        px, py = rng.uniform(x0, x1), rng.uniform(y0, y1)
        m = Matrix.Translation((px, py, z + 0.004)) @ Matrix.Rotation(rng.uniform(0, math.tau), 4, "Z")
        kit._nocol.append(("GoldCoin", m))
print("OVERLORD goldberge", len(opt.get("gold", [])))
