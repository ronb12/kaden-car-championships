"""
Shared helpers for Blender batch pipelines (car + city).
Compatible with Blender 3.4+ / 4.x background mode.
"""
from __future__ import annotations

import os

import bpy
from pathlib import Path


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def triangulate_mesh_objects(objects: list[bpy.types.Object]) -> None:
    for obj in objects:
        if obj.type != "MESH":
            continue
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        mod = obj.modifiers.new(name="Triangulate", type="TRIANGULATE")
        mod.keep_custom_normals = True
        bpy.ops.object.modifier_apply(modifier=mod.name)


def decimate_object(obj: bpy.types.Object, ratio: float) -> None:
    if obj.type != "MESH":
        return
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new(name="Decimate", type="DECIMATE")
    mod.ratio = max(0.05, min(1.0, ratio))
    bpy.ops.object.modifier_apply(modifier=mod.name)


def merge_vertices(obj: bpy.types.Object, merge_distance: float = 0.0005) -> None:
    if obj.type != "MESH":
        return
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=merge_distance)
    bpy.ops.object.mode_set(mode="OBJECT")


def apply_transforms(obj: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def normalize_principled_materials(objects: list[bpy.types.Object]) -> None:
    """Stabilize PBR values for glTF / mobile (no broken shader graphs)."""
    for obj in objects:
        if obj.type != "MESH":
            continue
        for slot in obj.material_slots:
            mat = slot.material
            if not mat or not mat.use_nodes:
                continue
            for n in mat.node_tree.nodes:
                if n.type == "BSDF_PRINCIPLED":
                    n.inputs["Roughness"].default_value = max(
                        0.12, min(1.0, n.inputs["Roughness"].default_value)
                    )
                    n.inputs["Metallic"].default_value = min(1.0, max(0.0, n.inputs["Metallic"].default_value))


def parent_keep_transform(child: bpy.types.Object, parent: bpy.types.Object | None) -> None:
    if parent is None:
        child.parent = None
        return
    child.parent = parent
    child.matrix_parent_inverse = parent.matrix_world.inverted()


def export_glb(filepath: Path, *, draco: bool | None = None) -> None:
    if draco is None:
        draco = os.environ.get("KRC_GLTF_DRACO", "1").strip().lower() not in ("0", "false", "no")
    filepath.parent.mkdir(parents=True, exist_ok=True)
    base = dict(
        filepath=str(filepath),
        export_format="GLB",
        export_materials="EXPORT",
        export_colors=True,
        export_texcoords=True,
        export_normals=True,
        export_apply=True,
        export_yup=True,
        use_visible_objects=True,
        use_renderable_objects=True,
        export_animations=True,
    )
    if draco:
        try:
            bpy.ops.export_scene.gltf(**base, export_draco_mesh_compression_enable=True)
            return
        except TypeError:
            pass
    bpy.ops.export_scene.gltf(**base)
