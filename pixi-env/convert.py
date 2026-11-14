"""Convert a .blend to USDZ using the bpy wheel. Usage: convert.py in.blend out.usdz

Animation export is enabled for exactly the current frame: with it off, the USD
exporter declares blendShapeWeights but writes no values, so every shape key
shows at 0 in the preview.
"""
import sys, bpy
src, out = sys.argv[1], sys.argv[2]
bpy.ops.wm.open_mainfile(filepath=src, load_ui=False)
sc = bpy.context.scene
sc.frame_start = sc.frame_end = sc.frame_current
bpy.ops.wm.usd_export(filepath=out, export_materials=True, export_animation=True,
                      export_shapekeys=True, export_armatures=True,
                      generate_preview_surface=True, evaluation_mode='VIEWPORT',
                      convert_orientation=True, export_global_up_selection='Y',
                      export_global_forward_selection='NEGATIVE_Z')
