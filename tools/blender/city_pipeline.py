#!/usr/bin/env python3
"""
Procedural modular city GLB pack: roads, intersections, buildings, props.
Outputs game-ready low-poly GLBs (PBR materials, triangulated, decimated where needed).

  blender -b -P tools/blender/city_pipeline.py -- --processed assets/processed --public public/models
"""
from __future__ import annotations

import argparse
import math
import shutil
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Euler

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))
import pipeline_common as pc


def parse_args() -> argparse.Namespace:
    if "--" in sys.argv:
        raw = sys.argv[sys.argv.index("--") + 1 :]
    else:
        raw = []
    p = argparse.ArgumentParser(description="Kaden Racing modular city GLB pipeline")
    p.add_argument("--processed", type=Path, default=Path("assets/processed"))
    p.add_argument("--public", type=Path, default=Path("public/models"))
    return p.parse_args(raw)


def make_material(name: str, color: tuple[float, float, float, float], metallic: float, rough: float) -> bpy.types.Material:
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new(type="ShaderNodeOutputMaterial")
    pr = nt.nodes.new(type="ShaderNodeBsdfPrincipled")
    pr.inputs["Base Color"].default_value = color
    pr.inputs["Metallic"].default_value = metallic
    pr.inputs["Roughness"].default_value = rough
    nt.links.new(pr.outputs["BSDF"], out.inputs["Surface"])
    out.location = (300, 0)
    pr.location = (0, 0)
    return mat


def mesh_obj_from_bmesh(bm: bmesh.types.BMesh, name: str, mat: bpy.types.Material) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    if mat:
        mesh.materials.append(mat)
    return obj


def export_module(
    name: str, build, proc_city: Path, pub_city: Path
) -> None:
    pc.reset_scene()
    build()
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for m in meshes:
        pc.merge_vertices(m)
        pc.decimate_object(m, 0.92)
    pc.triangulate_mesh_objects(meshes)
    pc.normalize_principled_materials(meshes)
    out = proc_city / f"krc_{name}.glb"
    pc.export_glb(out, draco=True)
    shutil.copy2(out, pub_city / out.name)
    print(f"[city_pipeline] {out.name}")


def build_road_straight() -> None:
    mat_asphalt = make_material("Asphalt", (0.09, 0.09, 0.1, 1), 0.05, 0.92)
    bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 0, 0))
    plane = bpy.context.object
    plane.name = "Road_Straight"
    plane.scale = (12, 4, 1)
    bpy.ops.object.transform_apply(scale=True)
    mod = plane.modifiers.new("Solidify", type="SOLIDIFY")
    mod.thickness = 0.08
    bpy.ops.object.modifier_apply(modifier=mod.name)
    plane.data.materials.append(mat_asphalt)


def build_road_curve_90() -> None:
    mat = make_material("Asphalt", (0.1, 0.1, 0.11, 1), 0.06, 0.9)
    bm = bmesh.new()
    segments = 16
    inner_r, outer_r = 10.0, 14.0
    verts_inner = []
    verts_outer = []
    for i in range(segments + 1):
        a = (math.pi / 2) * (i / segments)
        verts_inner.append(bm.verts.new((inner_r * math.cos(a), inner_r * math.sin(a), 0)))
        verts_outer.append(bm.verts.new((outer_r * math.cos(a), outer_r * math.sin(a), 0)))
    for i in range(segments):
        f = bm.faces.new(
            (verts_inner[i], verts_inner[i + 1], verts_outer[i + 1], verts_outer[i])
        )
        f.smooth = False
    bm.normal_update()
    mesh = bpy.data.meshes.new("Road_Curve90")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("Road_Curve90", mesh)
    bpy.context.scene.collection.objects.link(obj)
    mesh.materials.append(mat)
    mod = obj.modifiers.new("Solidify", type="SOLIDIFY")
    mod.thickness = 0.08
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)


def build_intersection() -> None:
    mat = make_material("AsphaltInter", (0.09, 0.1, 0.11, 1), 0.05, 0.88)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0.04))
    c = bpy.context.object
    c.name = "Intersection_4way"
    c.scale = (14, 14, 0.12)
    bpy.ops.object.transform_apply(scale=True)
    c.data.materials.append(mat)


def build_building_low() -> None:
    wall = make_material("Facade", (0.42, 0.4, 0.38, 1), 0.0, 0.78)
    glass = make_material("Glass", (0.25, 0.35, 0.45, 1), 0.55, 0.12)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 6))
    b = bpy.context.object
    b.name = "Building_Low"
    b.scale = (10, 8, 12)
    bpy.ops.object.transform_apply(scale=True)
    b.data.materials.append(wall)
    # Simple glow strip as inset plane would need loop cuts — use second object for “windows”
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 4.05, 8))
    w = bpy.context.object
    w.name = "Building_Low_Windows"
    w.scale = (8, 0.08, 5)
    w.data.materials.append(glass)


def build_building_tower() -> None:
    wall = make_material("TowerWall", (0.32, 0.33, 0.38, 1), 0.15, 0.42)
    neon = make_material("NeonTrim", (0.2, 0.85, 0.95, 1), 0.2, 0.25)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 18))
    t = bpy.context.object
    t.name = "Building_Tower"
    t.scale = (7, 7, 36)
    bpy.ops.object.transform_apply(scale=True)
    t.data.materials.append(wall)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 3.55, 28))
    band = bpy.context.object
    band.name = "Tower_Band"
    band.scale = (7.2, 0.12, 3)
    band.data.materials.append(neon)


def build_prop_streetlight() -> None:
    pole_m = make_material("PoleMetal", (0.22, 0.22, 0.24, 1), 0.55, 0.35)
    lamp_m = make_material("LampEmissive", (1.0, 0.95, 0.75, 1), 0.0, 0.25)
    for n in lamp_m.node_tree.nodes:
        if n.type == "BSDF_PRINCIPLED":
            if "Emission Color" in n.inputs:
                n.inputs["Emission Color"].default_value = (1.0, 0.92, 0.55, 1.0)
            if "Emission Strength" in n.inputs:
                n.inputs["Emission Strength"].default_value = 3.2
            break
    bpy.ops.mesh.primitive_cylinder_add(radius=0.14, depth=7, location=(0, 0, 3.5))
    pole = bpy.context.object
    pole.name = "Prop_Streetlight_Pole"
    pole.data.materials.append(pole_m)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.32, location=(0, 0, 7.1))
    bulb = bpy.context.object
    bulb.name = "Prop_Streetlight_Bulb"
    bulb.data.materials.append(lamp_m)


def build_prop_barrier() -> None:
    mat = make_material("BarrierStrip", (0.95, 0.35, 0.08, 1), 0.1, 0.55)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0.45))
    b = bpy.context.object
    b.name = "Prop_Barrier"
    b.scale = (2.4, 0.35, 0.9)
    bpy.ops.object.transform_apply(scale=True)
    b.data.materials.append(mat)


def build_prop_palm() -> None:
    trunk = make_material("Trunk", (0.35, 0.22, 0.12, 1), 0.0, 0.85)
    leaf = make_material("Leaf", (0.12, 0.55, 0.22, 1), 0.0, 0.65)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.35, depth=5, location=(0, 0, 2.5))
    tr = bpy.context.object
    tr.name = "Palm_Trunk"
    tr.data.materials.append(trunk)
    for i in range(6):
        a = (math.tau / 6) * i
        bpy.ops.mesh.primitive_uv_sphere_add(radius=1.2, location=(1.1 * math.cos(a), 1.1 * math.sin(a), 5.2))
        lf = bpy.context.object
        lf.name = f"Palm_Leaf_{i}"
        lf.scale = (1.6, 0.35, 0.5)
        lf.rotation_euler = Euler((0.85, 0, a))
        lf.data.materials.append(leaf)


def main() -> None:
    args = parse_args()
    proc_city = args.processed / "city"
    pub_city = args.public / "city"
    proc_city.mkdir(parents=True, exist_ok=True)
    pub_city.mkdir(parents=True, exist_ok=True)

    modules = [
        ("mod_road_straight", build_road_straight),
        ("mod_road_curve90", build_road_curve_90),
        ("mod_intersection_4way", build_intersection),
        ("mod_building_low", build_building_low),
        ("mod_building_tower", build_building_tower),
        ("mod_prop_streetlight", build_prop_streetlight),
        ("mod_prop_barrier", build_prop_barrier),
        ("mod_prop_palm", build_prop_palm),
    ]

    for name, builder in modules:
        export_module(name, builder, proc_city, pub_city)

    print("[city_pipeline] Done — modular GLBs in city/")


if __name__ == "__main__":
    main()
