# Run by make-3d.ps1 inside Blender: clear scene, run user script, export GLB, render preview.
import sys, math, runpy, traceback
import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
script, out_glb, preview, res = argv[0], argv[1], argv[2], int(argv[3])

bpy.ops.wm.read_factory_settings(use_empty=True)

try:
    runpy.run_path(script, run_name="__main__")
except Exception:
    traceback.print_exc()
    print("CEMAAT: script failed")
    sys.exit(1)

meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
if not meshes:
    print("CEMAAT: script created no mesh objects")
    sys.exit(1)

# Export only meshes (plus their materials) to GLB.
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=out_glb, export_format="GLB", use_selection=True, export_apply=True)
print("CEMAAT: exported", out_glb, "meshes:", len(meshes))

# Preview: frame the bounding box with a camera and simple lights.
pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
center = (lo + hi) / 2
size = max((hi - lo).length, 0.001)

scene = bpy.context.scene
if not scene.camera:
    cam = bpy.data.objects.new("PreviewCam", bpy.data.cameras.new("PreviewCam"))
    scene.collection.objects.link(cam)
    direction = Vector((1.0, -1.2, 0.8)).normalized()
    cam.location = center + direction * size * 1.6
    cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
if not any(o.type == "LIGHT" for o in scene.objects):
    for loc, energy in (((1, -1, 1.5), 3.0), ((-1.2, 0.5, 1.0), 1.2)):
        sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
        sun.data.energy = energy
        sun.location = center + Vector(loc) * size
        sun.rotation_euler = (center - sun.location).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(sun)
if scene.world is None:
    scene.world = bpy.data.worlds.new("World")
scene.world.color = (0.18, 0.18, 0.2)

scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
scene.render.resolution_x = res
scene.render.resolution_y = res
scene.render.filepath = preview
try:
    bpy.ops.render.render(write_still=True)
    print("CEMAAT: preview", preview)
except Exception:
    traceback.print_exc()
    print("CEMAAT: preview render failed (model still exported)")
