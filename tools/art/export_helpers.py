"""Export-only consolidation. Call after saving the editable Blender source."""
import bpy

def merge_static_children(parent, name):
    parts=[o for o in parent.children if o.type=='MESH']
    if len(parts)<2: return
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts: o.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]
    # Bake each object's modifiers before joining, preserving its evaluated surface.
    bpy.ops.object.convert(target='MESH')
    bpy.ops.object.join()
    bpy.context.object.name=name

def export_stats():
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    return {'mesh_objects':len(meshes),'material_slots':sum(len(o.data.materials) for o in meshes)}
