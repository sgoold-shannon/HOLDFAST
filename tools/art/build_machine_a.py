"""Rebuild the editable Machine A candidate and baked GLB using Blender 5.2.
Run: Blender --background --python tools/art/build_machine_a.py
Blender coordinates: Z up, front -Y. Export converts to Godot Y up/front +Z.
No textures, animation, collision, or mission code is authored here.
"""
import bpy, math, json
from pathlib import Path
from mathutils import Vector
ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'art-source/machine-a'
OUT = ROOT / 'holdfast/assets/machine_a'
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for data in list(bpy.data.materials): bpy.data.materials.remove(data)

def material(name, color, metal=0.0, rough=.65, emission=0):
    m=bpy.data.materials.new(name); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=rough
    if emission:
        p.inputs['Emission Color'].default_value=(*color,1)
        p.inputs['Emission Strength'].default_value=emission
    m.diffuse_color=(*color,1)
    return m
stone=material('Shell_stone',(.24,.26,.20),.18,.78)
olive=material('Shell_olive',(.105,.14,.095),.22,.72)
repair=material('Shell_replacement',(.37,.33,.25),.35,.58)
frame=material('Frame_dark',(.085,.105,.085),.55,.48)
edge=material('Edges_and_tool',(.24,.27,.22),.65,.42)
rubber=material('Contact_pads',(.045,.052,.043),.05,.95)
lamps=material('Work_lamps',(.95,.49,.105),.05,.35,.7)
emitter=material('Emitter_unpowered',(.09,.095,.075),.3,.38)
cargo_mat=material('Cargo_metal',(.31,.34,.28),.65,.55)

def empty(name,parent=None,at=(0,0,0)):
    o=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(o)
    o.parent=parent; o.location=at; return o
root=empty('MachineA')
shell=empty('Shell',root); base=empty('Base',root)
tool=empty('ToolShoulder',root,(-.22,-.22,.51))
cargo=empty('CargoSocket',root)
lights=empty('WorkLights',root)

def finish(o,name,mat,parent,bevel=0):
    o.name=name; o.data.materials.append(mat); o.parent=parent
    if bevel:
        mod=o.modifiers.new('Manufactured_edges','BEVEL'); mod.width=bevel; mod.segments=2
        mod=o.modifiers.new('Weighted_corner_normals','WEIGHTED_NORMAL')
    return o

def box(name,at,size,mat,parent=root,bevel=.008):
    bpy.ops.mesh.primitive_cube_add(size=1,location=at); o=bpy.context.object
    o.dimensions=size; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,mat,parent,bevel)

def cylinder(name,at,radius,depth,mat,parent=root,axis=(0,0,1),vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=at)
    o=bpy.context.object; o.rotation_euler=Vector(axis).to_track_quat('Z','Y').to_euler()
    return finish(o,name,mat,parent,.003)

def rod(name,a,b,r,mat,parent):
    a,b=Vector(a),Vector(b)
    return cylinder(name,(a+b)/2,r,(b-a).length,mat,parent,b-a)

# Narrow chamfered chassis and independent contact pads; no locomotion claims.
box('Chassis',(0,0,.14),(.78,.73,.18),frame,base,.035)
box('Cargo_floor',(0,-.22,.235),(.40,.43,.045),edge,base)
for x in [-.335,.335]:
    for y in [-.30,.30]:
        box('Contact_pad', (x,y,.045),(.22,.25,.09),rubber,base,.025)
        box('Pad_mount',(x,y,.11),(.15,.18,.055),edge,base)
for x in [-.18,.18]:
    box('Cargo_rail',(x,-.25,.274),(.025,.35,.035),frame,base,.005)

# Curved panels have closed thickness; underlying contiguous shell keeps seams dark.
def patch(name,t0,t1,p0,p1,mat,inset=0,thick=.014):
    nu,nv=6,4; verts=[]; faces=[]
    for layer in [0,1]:
        r=.46-inset-layer*thick; h=.76-inset-layer*thick
        for j in range(nv+1):
            p=p0+(p1-p0)*j/nv
            for i in range(nu+1):
                t=t0+(t1-t0)*i/nu
                verts.append((r*math.cos(p)*math.sin(t),-r*math.cos(p)*math.cos(t),.20+h*math.sin(p)))
    n=(nu+1)*(nv+1)
    for j in range(nv):
        for i in range(nu):
            a=j*(nu+1)+i; q=(a,a+1,a+nu+2,a+nu+1)
            faces.append(q); faces.append(tuple(v+n for v in reversed(q)))
    border=list(range(nu+1))+[j*(nu+1)+nu for j in range(1,nv+1)]+[nv*(nu+1)+i for i in range(nu-1,-1,-1)]+[j*(nu+1) for j in range(nv-1,0,-1)]
    for i,a in enumerate(border):
        b=border[(i+1)%len(border)]; faces.append((b,a,a+n,b+n))
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(verts,[],faces); mesh.update()
    o=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(o)
    finish(o,name,mat,shell)
    for p in mesh.polygons: p.use_smooth=len(p.vertices)==4
    split=o.modifiers.new("Hard_panel_rims","EDGE_SPLIT"); split.split_angle=0.6
    return o
for band in range(3):
    for sector in range(12):
        t0=-math.pi+sector*math.tau/12; t1=t0+math.tau/12
        # Four lower front sectors open to the tray. Upper band forms a brow.
        if band<2 and abs((t0+t1)/2)<1.05: continue
        p0=band*math.pi/6; p1=(band+1)*math.pi/6
        patch('Backing_%d_%02d'%(band,sector),t0,t1,p0,p1,frame,.022,.012)
        patch('Plate_%d_%02d'%(band,sector),t0+.012,t1-.012,p0+.008,min(p1-.008,math.pi/2-.006),[stone,stone,olive,repair][(sector+band)%4])
# Crown bridges polar ends; low-profile service strip and rear vent bank.
cylinder('Crown_cap',(0,0,.953),.055,.017,olive,shell)
box('Rear_service_panel',(0,.448,.37),(.22,.035,.25),olive,shell,.012)
for z in [.30,.34,.38,.42]: box('Rear_vent',(0,.471,z),(.16,.012,.012),frame,shell,.002)
# Tool chain uses local pivots, with a deliberately folded open gripper.
cylinder('Shoulder_joint',(0,0,0),.048,.09,edge,tool,(1,0,0))
rod('Upper_link',(0,0,0),(.03,-.12,-.13),.028,edge,tool)
elbow=empty('ToolElbow',tool,(.03,-.12,-.13))
cylinder('Elbow_joint',(0,0,0),.038,.07,frame,elbow,(1,0,0))
rod('Forearm',(0,0,0),(.09,-.02,-.08),.022,edge,elbow)
wrist=empty('ToolWrist',elbow,(.09,-.02,-.08))
cylinder('Wrist_joint',(0,0,0),.028,.045,frame,wrist,(1,0,0))
for x in [-.035,.035]:
    box('Gripper_finger',(x,-.032,0),(.018,.07,.025),edge,wrist,.004)
    box('Gripper_tip',(x*.65,-.061,0),(.035,.015,.025),edge,wrist,.003)
# Lamps flank the opening, not paired eyes; separate dark defensive aperture.
for x in [-.27,.27]:
    housing=box('Lamp_housing',(x,-.255,.665),(.11,.055,.055),frame,lights,.01)
    box('WorkLamp',(x,-.286,.665),(.075,.012,.022),lamps,lights,.003)
box('EmitterHousing',(.12,-.23,.62),(.065,.07,.07),frame)
box('DefensiveEmitter',(.12,-.27,.62),(.038,.012,.035),emitter)
# Removable neutral cargo sample. Hidden by benchmark on instantiation, not baked in shell.
box('CargoSkid',(0,-.12,.30),(.29,.25,.035),edge,cargo)
cylinder('CargoComponent',(0,-.10,.395),.085,.21,cargo_mat,cargo,(1,0,0))
for x in [-.09,.09]: cylinder('CargoBand',(x,-.10,.395),.092,.022,edge,cargo,(1,0,0))
box('CargoConnector',(0,-.10,.49),(.08,.07,.05),cargo_mat,cargo)

# Alternate recovered component: a compact rectangular finned module, distinct from pump/skid.
# Its exact identity is still an art proposal; runtime selection will follow mission data later.
alternate=empty('CargoAlternate',root)
box('Alternate_tray',(0,-.12,.30),(.29,.25,.035),edge,alternate)
box('Alternate_module',(0,-.10,.39),(.24,.18,.145),olive,alternate,.012)
for x in [-.085,-.042,0,.042,.085]:
    box('Alternate_fin',(x,-.10,.48),(.014,.16,.045),edge,alternate,.003)
box('Alternate_socket',(0,-.205,.395),(.075,.025,.055),frame,alternate,.004)
# Restrained rear repair fasteners; no insignia or invented glyphs.
for x in [-.075,.075]:
    for z in [.285,.455]:
        cylinder('Service_fastener',(x,.473,z),.008,.008,edge,shell,(0,1,0),8)

# Validate evaluated geometry and publish counts and actual envelope, including hidden cargo.
bpy.context.view_layer.update()
points=[]; triangles=0; meshes=0
for o in bpy.context.scene.objects:
    if o.type!='MESH': continue
    ev=o.evaluated_get(bpy.context.evaluated_depsgraph_get()); me=ev.to_mesh()
    me.calc_loop_triangles(); triangles+=len(me.loop_triangles); meshes+=1
    points.extend(o.matrix_world @ v.co for v in me.vertices); ev.to_mesh_clear()
lo=[min(v[i] for v in points) for i in range(3)]; hi=[max(v[i] for v in points) for i in range(3)]
assert hi[0]-lo[0]<=.95 and hi[1]-lo[1]<=.95, (lo,hi)
assert abs(lo[2])<.001, lo
report={'candidate':'Machine A static 01','tool':'Blender '+bpy.app.version_string,'blender_bounds_min':lo,'blender_bounds_max':hi,'dimensions_cells':[hi[i]-lo[i] for i in range(3)],'evaluated_triangles':triangles,'mesh_objects':meshes,'materials':len(bpy.data.materials),'texture_bytes':0,'animation':False,'collision':False,'performance':'Frame timing and representative PC budget not yet measured.'}
(SOURCE/'metrics.json').write_text(json.dumps(report,indent=2)+'\n')
# Save only asset data; no review lights/cameras in editable model or game export.
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'machine_a_01.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'machine_a_01.glb'),export_format='GLB',export_apply=True,export_animations=False,export_cameras=False,export_lights=False)
print('MACHINE_A_METRICS',json.dumps(report))
