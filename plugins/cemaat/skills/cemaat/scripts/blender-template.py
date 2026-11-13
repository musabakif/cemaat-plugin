# Template for worker-written Blender scripts (run via make-3d.ps1).
# Rules:
# - The scene is already empty. Only create meshes and materials. No export, no render, no file I/O.
# - Build with bpy primitives + modifiers (bevel, subdivision, array, mirror, solidify).
# - Every mesh gets a Principled BSDF material with a base color (exported to GLB).
# - Units: meters. Model stands on the ground (min Z = 0), centered at X=0, Y=0. Front faces -Y.
# - Low-poly game style unless told otherwise. Keep under ~20k triangles.
import bpy


def material(name, rgb, roughness=0.6, metallic=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    return m


def assign(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)


# Example: simple low-poly tree.
bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.12, depth=1.0, location=(0, 0, 0.5))
trunk = bpy.context.active_object
trunk.name = "Trunk"
assign(trunk, material("Bark", (0.35, 0.22, 0.12)))

bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.6, location=(0, 0, 1.3))
leaves = bpy.context.active_object
leaves.name = "Leaves"
assign(leaves, material("Leaves", (0.2, 0.55, 0.25)))
