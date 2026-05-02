#!/usr/bin/env python3
"""
Blender background batch: import raw car FBX/OBJ, normalize scale, decimate, fix materials,
mark wheel objects for animation, export game-ready GLB to processed/ + public/models/.

Run:
  blender -b -P tools/blender/car_pipeline.py -- --raw assets/raw --processed assets/processed --public public/models
"""
from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

import bpy
from mathutils import Vector

# Local shared utils
SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))
import pipeline_common as pc


def parse_args() -> argparse.Namespace:
    if "--" in sys.argv:
        raw = sys.argv[sys.argv.index("--") + 1 :]
    else:
        raw = []
    p = argparse.ArgumentParser(description="Kaden Racing car GLB pipeline")
    p.add_argument("--raw", type=Path, default=Path("assets/raw"), help="Root with cars/ subfolder")
    p.add_argument("--processed", type=Path, default=Path("assets/processed"))
    p.add_argument("--public", type=Path, default=Path("public/models"))
    p.add_argument("--max-dim", type=float, default=4.6, help="Target max world dimension (meters)")
    p.add_argument("--decimate", type=float, default=0.45, help="Decimate ratio (lower = fewer polys)")
    return p.parse_args(raw)


def import_model(path: Path) -> list[bpy.types.Object]:
    ext = path.suffix.lower()
    if ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=str(path), use_anim=True)
    elif ext == ".obj":
        try:
            bpy.ops.wm.obj_import(filepath=str(path))
        except AttributeError:
            bpy.ops.import_scene.obj(filepath=str(path))
    else:
        raise ValueError(f"Unsupported format: {ext}")
    return [o for o in bpy.context.view_layer.objects if o.type in {"MESH", "EMPTY", "ARMATURE"}]


def bounds_world(objects: list[bpy.types.Object]) -> tuple[Vector, Vector]:
    min_c = Vector((1e9, 1e9, 1e9))
    max_c = Vector((-1e9, -1e9, -1e9))
    for o in objects:
        if o.type != "MESH" or not o.data:
            continue
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            min_c = Vector((min(min_c.x, w.x), min(min_c.y, w.y), min(min_c.z, w.z)))
            max_c = Vector((max(max_c.x, w.x), max(max_c.y, w.y), max(max_c.z, w.z)))
    return min_c, max_c


def scale_objects_to_max_dim(mesh_objects: list[bpy.types.Object], max_dim: float) -> None:
    mn, mx = bounds_world(mesh_objects)
    size = mx - mn
    cur = max(size.x, size.y, size.z) or 1.0
    s = max_dim / cur
    roots = [
        o
        for o in bpy.context.scene.objects
        if o.parent is None and o.type in {"MESH", "ARMATURE", "EMPTY"}
    ]
    if not roots:
        roots = mesh_objects
    for o in roots:
        o.scale = (o.scale[0] * s, o.scale[1] * s, o.scale[2] * s)
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.context.scene.objects:
        if o.type in {"MESH", "ARMATURE"}:
            o.select_set(True)
    root = mesh_objects[0] if mesh_objects else None
    if root:
        bpy.context.view_layer.objects.active = root
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)


def mark_wheels_for_animation() -> None:
    """
    Parent wheel-like meshes to pivot empties (rotate pivot for roll in engine).
    Heuristic: name contains 'wheel', 'rim', or 'tire' (case-insensitive).
    """
    for o in list(bpy.data.objects):
        if o.type != "MESH":
            continue
        n = o.name.lower()
        if "wheel" not in n and "rim" not in n and "tire" not in n:
            continue
        loc = o.matrix_world.translation
        bpy.ops.object.empty_add(type="PLAIN_AXES", radius=0.12, location=loc)
        pivot = bpy.context.object
        pivot.name = f"{o.name}_pivot"
        pivot["krc_component"] = "wheel_pivot"
        o["krc_component"] = "wheel_mesh"
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        pivot.select_set(True)
        bpy.context.view_layer.objects.active = pivot
        bpy.ops.object.parent_set(type="OBJECT", keep_transform=True)


def process_one(src: Path, out_dir: Path, pub_dir: Path, max_dim: float, decimate_ratio: float) -> Path:
    pc.reset_scene()
    imported = import_model(src)
    meshes = [o for o in imported if o.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"No mesh imported from {src}")

    # Normalize scale to consistent author scale (mobile-friendly bounds)
    scale_objects_to_max_dim(meshes, max_dim)

    for m in meshes:
        pc.apply_transforms(m)
        pc.merge_vertices(m)
        pc.decimate_object(m, decimate_ratio)
    pc.triangulate_mesh_objects(meshes)
    pc.normalize_principled_materials(meshes)

    mark_wheels_for_animation()

    out_path = out_dir / f"{src.stem}.glb"
    pc.export_glb(out_path, draco=True)
    pub_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(out_path, pub_dir / out_path.name)
    return out_path


def main() -> None:
    args = parse_args()
    raw_cars = args.raw / "cars"
    proc_cars = args.processed / "cars"
    pub_cars = args.public / "cars"
    proc_cars.mkdir(parents=True, exist_ok=True)
    pub_cars.mkdir(parents=True, exist_ok=True)

    exts = {".fbx", ".obj", ".FBX", ".OBJ"}
    sources = sorted([p for p in raw_cars.iterdir() if p.is_file() and p.suffix in exts])
    if not sources:
        print(f"[car_pipeline] No FBX/OBJ in {raw_cars} — nothing to import.")
        return

    for src in sources:
        try:
            outp = process_one(src, proc_cars, pub_cars, args.max_dim, args.decimate)
            print(f"[car_pipeline] OK {src.name} -> {outp}")
        except Exception as e:
            print(f"[car_pipeline] FAIL {src.name}: {e}")
            raise


if __name__ == "__main__":
    main()
