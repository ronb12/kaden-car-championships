import bpy
import sys
import os

argv = sys.argv
argv = argv[argv.index("--") + 1:]
input_glb = argv[0]
output_usdz = argv[1]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=input_glb)
bpy.ops.wm.usd_export(filepath=output_usdz, export_textures=True, overwrite_textures=True)
print(f"Converted: {os.path.basename(input_glb)} -> {os.path.basename(output_usdz)}")
