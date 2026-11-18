"""Build a separate, editable collapsed-shell study from the intact candidate.
Run with Blender --background --python tools/art/build_machine_a_wreck.py.
No collision, particles, lights, cargo, animation or gameplay are exported.
"""
import bpy, math, json, sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(Path(__file__).resolve().parent))
from export_helpers import merge_static_children, export_stats
SOURCE=ROOT/'art-source/machine-a'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE/'machine_a_01.blend'))
bpy.context.view_layer.update()
# Bake only chassis and a broken subset of shell plates into independent fragments.
original=list(bpy.context.scene.objects)
parts=[]
for obj in original:
    if obj.type!='MESH': continue
    base=obj.parent and obj.parent.name=='Base'
    plate=obj.name.startswith('Plate_')
    if not base and not plate: continue
    if plate:
        band,sector=map(int,obj.name.split('_')[1:])
        if band==2 or (band==1 and sector%3==0): continue
    ev=obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh=bpy.data.meshes.new_from_object(ev)
    for v in mesh.vertices: v.co=obj.matrix_world@v.co
    if plate:
        # Uneven inward collapse, with different slopes per independent fragment.
        for v in mesh.vertices:
            x,y,z=v.co
            v.co=Vector((x*.91,y*.91,.19+(z-.20)*.27+.035*math.sin(sector*2.3)+(x*.08 if sector%2 else y*-.08)))
    part=bpy.data.objects.new(('Broken_' if plate else 'Wreck_')+obj.name,mesh)
    parts.append(part)
for obj in original: bpy.data.objects.remove(obj,do_unlink=True)
root=bpy.data.objects.new('MachineAWreck',None); bpy.context.collection.objects.link(root)
for part in parts:
    bpy.context.collection.objects.link(part); part.parent=root
# Muted materials indicate damaged exposed structure without implying ongoing fire.
for m in bpy.data.materials:
    if not m.use_nodes: continue
    p=m.node_tree.nodes.get('Principled BSDF')
    if p:
        c=p.inputs['Base Color'].default_value
        p.inputs['Base Color'].default_value=(c[0]*.58,c[1]*.58,c[2]*.58,1)
        p.inputs['Roughness'].default_value=.9
        p.inputs['Emission Strength'].default_value=0
metal=bpy.data.materials.get('Edges_and_tool')
for i in range(3):
    bpy.ops.mesh.primitive_cube_add(size=1,location=(-.13+i*.13,.09,.29+i*.025))
    o=bpy.context.object; o.name='Exposed_broken_support_%d'%i; o.parent=root
    o.dimensions=(.035,.40,.035); o.rotation_euler=(0,.15*(i-1),.22*(i-1))
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.data.materials.append(metal)
# Detached crown shard rests at an angle on the collapsed body, all within one cell.
bpy.ops.mesh.primitive_cube_add(size=1,location=(.10,.10,.34))
o=bpy.context.object; o.name='Detached_crown_fragment'; o.parent=root
o.dimensions=(.24,.22,.018); o.rotation_euler=(.3,-.22,.25)
bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
o.data.materials.append(bpy.data.materials['Shell_olive'])
bpy.context.view_layer.update()
points=[]; triangles=0; count=0
for o in bpy.context.scene.objects:
    if o.type!='MESH': continue
    points.extend(o.matrix_world@v.co for v in o.data.vertices)
    o.data.calc_loop_triangles(); triangles+=len(o.data.loop_triangles); count+=1
lo=[min(v[i] for v in points) for i in range(3)]; hi=[max(v[i] for v in points) for i in range(3)]
assert hi[0]-lo[0]<.95 and hi[1]-lo[1]<.95 and lo[2]>=0 and hi[2]<.5
(SOURCE/'wreck_metrics.json').write_text(json.dumps({'bounds_min':lo,'bounds_max':hi,'triangles':triangles,'mesh_objects':count,'collision':False,'animation':False},indent=2)+'\n')
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'machine_a_wreck_01.blend'))
merge_static_children(root,'WreckGeometry')
(SOURCE/'wreck_export_metrics.json').write_text(json.dumps(export_stats(),indent=2)+'\n')
bpy.ops.export_scene.gltf(filepath=str(ROOT/'holdfast/assets/machine_a/machine_a_wreck_01.glb'),export_format='GLB',export_apply=True,export_animations=False,export_cameras=False,export_lights=False)
