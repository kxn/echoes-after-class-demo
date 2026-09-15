extends Node3D

const WIDTH:=32.4
const WALL_H:=7.16
const WALL_V:=0.709
const OPENINGS=[Vector2(0.169,0.242),Vector2(0.289,0.360),Vector2(0.416,0.493),Vector2(0.607,0.682),Vector2(0.733,0.806),Vector2(0.850,0.914)]
const Actor25D=preload("res://scripts/actor_25d.gd")
var camera: Camera3D
var sun: DirectionalLight3D
var environment: WorldEnvironment
var actors: Array[Node3D]=[]
var desks: Array[Node3D]=[]
var wood: StandardMaterial3D
var paper: StandardMaterial3D
var blockers: Array[AABB]=[]
var sun_direction:=Vector3(-0.45,-0.52,1.0).normalized()
var normals_enabled: bool=true
var mesh_cache: Dictionary={}

func _ready() -> void:
	name="LitStage3D"
	wood=StandardMaterial3D.new()
	wood.albedo_texture=preload("res://assets/relit/wood_albedo.png")
	wood.albedo_color=Color(0.73,0.77,0.79)
	wood.roughness=0.87
	wood.metallic_specular=0.13
	wood.uv1_triplanar=false
	wood.uv1_scale=Vector3.ONE
	wood.cull_mode=BaseMaterial3D.CULL_BACK
	paper=StandardMaterial3D.new()
	paper.albedo_color=Color("a99b7d")
	paper.roughness=0.95
	build_room()
	for i in range(7):
		build_desk(Vector3(6.1+i*3.48,0,4.65),i)
		build_desk(Vector3(5.8+i*3.60,0,10.9),i+7)
	build_lights()
	camera=Camera3D.new()
	camera.name="OrthographicStoryCamera"
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=9.0
	camera.near=0.1
	camera.far=48.0
	add_child(camera)
	camera.make_current()
	set_camera(7.2)

func flat_quad(points: PackedVector3Array, uvs: PackedVector2Array, normal: Vector3, material: Material, parent: Node3D=null) -> MeshInstance3D:
	if parent==null:
		parent=self
	var arrays:=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=points
	arrays[Mesh.ARRAY_NORMAL]=PackedVector3Array([normal,normal,normal,normal])
	arrays[Mesh.ARRAY_TEX_UV]=uvs
	arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,2,1,0,3,2])
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var instance:=MeshInstance3D.new()
	instance.mesh=mesh
	instance.material_override=material
	parent.add_child(instance)
	return instance

func box(pos: Vector3,size: Vector3,material: Material,parent: Node3D=null, shadow_only: bool=false) -> MeshInstance3D:
	if parent==null:
		parent=self
	var instance:=MeshInstance3D.new()
	if shadow_only:
		var mesh:=BoxMesh.new()
		mesh.size=size
		instance.mesh=mesh
	else:
		instance.mesh=beveled_box(size)
	instance.position=pos
	instance.material_override=material
	if shadow_only:
		instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		blockers.append(AABB(pos-size/2,size))
	parent.add_child(instance)
	return instance

func beveled_box(size: Vector3) -> ArrayMesh:
	var key:=str(size)
	if mesh_cache.has(key):
		return mesh_cache[key]
	var half:=size/2.0
	var bevel:=minf(0.042,minf(size.x,minf(size.y,size.z))*0.20)
	var inner:=half-Vector3.ONE*bevel
	var vertices:=PackedVector3Array()
	var normals:=PackedVector3Array()
	var uvs:=PackedVector2Array()
	var indices:=PackedInt32Array()
	var axes=[Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.BACK,Vector3.FORWARD]
	for n in axes:
		var u: Vector3=Vector3.RIGHT if absf(n.y)>0.5 or absf(n.z)>0.5 else Vector3.BACK
		var v: Vector3=n.cross(u)
		var hu: float=absf(u.dot(half))
		var hv: float=absf(v.dot(half))
		var hn: float=absf(n.dot(half))
		var us=[-hu,-hu+bevel,hu-bevel,hu]
		var vs=[-hv,-hv+bevel,hv-bevel,hv]
		var base:=vertices.size()
		for iy in range(4):
			for ix in range(4):
				var cube: Vector3=n*hn+u*us[ix]+v*vs[iy]
				var core:=cube.clamp(-inner,inner)
				var normal: Vector3=(cube-core).normalized()
				vertices.append(core+normal*bevel)
				normals.append(normal)
				# Keep grain at one physical scale; turn it along narrow legs.
				var tex_u: float=vs[iy] if hv>hu else us[ix]
				var tex_v: float=us[ix] if hv>hu else vs[iy]
				uvs.append(Vector2(tex_u,tex_v)*0.22+Vector2(0.51,0.43))
		for iy in range(3):
			for ix in range(3):
				var a:=base+iy*4+ix
				indices.append_array(PackedInt32Array([a,a+5,a+1,a,a+4,a+5]))
	var arrays:=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_TEX_UV]=uvs
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh_cache[key]=mesh
	return mesh

func build_room() -> void:
	var wall_material:=ShaderMaterial.new()
	wall_material.shader=preload("res://shaders/room_lit.gdshader")
	wall_material.set_shader_parameter("room_tex",preload("res://assets/relit/room_albedo.png"))
	var wall:=flat_quad(PackedVector3Array([Vector3(0,0,0),Vector3(WIDTH,0,0),Vector3(WIDTH,WALL_H,0),Vector3(0,WALL_H,0)]),PackedVector2Array([Vector2(0,WALL_V),Vector2(1,WALL_V),Vector2(1,0),Vector2(0,0)]),Vector3.BACK,wall_material)
	wall.name="PaintedWallWithEmissiveWindowInserts"
	wall.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var floor_material:=wall_material.duplicate() as ShaderMaterial
	floor_material.set_shader_parameter("is_floor",true)
	floor_material.set_shader_parameter("pigment",Vector3(0.76,0.73,0.72))
	var floor_mesh:=flat_quad(PackedVector3Array([Vector3(0,0,0),Vector3(0,0,13),Vector3(WIDTH,0,13),Vector3(WIDTH,0,0)]),PackedVector2Array([Vector2(0,0),Vector2(0,1),Vector2(1,1),Vector2(1,0)]),Vector3.UP,floor_material)
	floor_mesh.name="FloorReceivingWindowDeskAndActorShadows"
	var lower:=WALL_H*(1.0-0.515/WALL_V)
	var upper:=WALL_H*(1.0-0.120/WALL_V)
	box(Vector3(WIDTH/2,lower/2,-0.08),Vector3(WIDTH,lower,0.22),wood,self,true)
	box(Vector3(WIDTH/2,(upper+WALL_H)/2,-0.08),Vector3(WIDTH,WALL_H-upper,0.22),wood,self,true)
	var previous:=0.0
	for opening in OPENINGS:
		var left: float=opening.x*WIDTH
		var right: float=opening.y*WIDTH
		box(Vector3((previous+left)/2,(lower+upper)/2,-0.08),Vector3(left-previous,upper-lower,0.22),wood,self,true)
		var mid: float=(left+right)/2
		# Real mullions in the aperture; their shadows travel across bodies and desks.
		box(Vector3(mid,(lower+upper)/2,-0.10),Vector3(0.085,upper-lower,0.16),wood,self,true)
		var divider_y:=WALL_H*(1.0-0.225/WALL_V)
		box(Vector3(mid,divider_y,-0.10),Vector3(right-left,0.18,0.16),wood,self,true)
		previous=right
	box(Vector3((previous+WIDTH)/2,(lower+upper)/2,-0.08),Vector3(WIDTH-previous,upper-lower,0.22),wood,self,true)
	box(Vector3(-0.1,4,6),Vector3(0.2,8,12),wood,self,true)
	box(Vector3(WIDTH+0.1,4,6),Vector3(0.2,8,12),wood,self,true)

func build_desk(pos: Vector3,index: int) -> void:
	var desk:=Node3D.new()
	desk.name="Desk_%02d"%index
	desk.position=pos
	add_child(desk)
	desks.append(desk)
	var w:=2.82
	var d:=1.28
	var h:=2.22
	for plank in range(4):
		var top:=box(Vector3(0,h+sin(index*4.7+plank)*0.011,(plank-1.5)*d/4),Vector3(w,0.13,d/4-0.012),wood,desk)
		top.name="TopPlank_%d"%plank
	box(Vector3(0,1.76,d/2-0.10),Vector3(w-0.16,0.78,0.12),wood,desk)
	for x in [-w/2+0.13,w/2-0.13]:
		for z in [-d/2+0.14,d/2-0.14]:
			box(Vector3(x,h/2,z),Vector3(0.15,h,0.16),wood,desk)
		box(Vector3(x,0.55,0),Vector3(0.12,0.11,d-0.20),wood,desk)
	# A plain wooden stool behind the desk, with genuine legs and cast shadow.
	box(Vector3(0,1.15,-1.08),Vector3(1.12,0.12,0.82),wood,desk)
	for x in [-0.43,0.43]:
		for z in [-1.38,-0.78]:
			box(Vector3(x,0.57,z),Vector3(0.11,1.14,0.11),wood,desk)
	for book in range(1+index%3):
		var notebook:=box(Vector3(-0.51,2.325+book*0.054,0.05),Vector3(0.65,0.045,0.46),paper,desk)
		notebook.rotation.y=-0.08+index*0.023

func build_lights() -> void:
	environment=WorldEnvironment.new()
	var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("302c32")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color(0.60,0.62,0.68)
	env.ambient_light_energy=0.75
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	environment.environment=env
	add_child(environment)
	sun=DirectionalLight3D.new()
	sun.name="SingleSunThroughRealWindowApertures"
	sun.light_color=Color(1.0,0.81,0.57)
	sun.light_energy=1.8
	sun.shadow_enabled=true
	sun.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.shadow_bias=0.015
	sun.shadow_normal_bias=0.045
	sun.shadow_blur=1.4
	add_child(sun)
	sun.look_at_from_position(Vector3(20,12,-16),Vector3(20,12,-16)+sun_direction,Vector3.UP)
	# Very restrained room bounce, not a second sun or a camera-attached key light.
	var bounce:=OmniLight3D.new()
	bounce.name="LowWarmFloorBounce"
	bounce.position=Vector3(18,2.5,8)
	bounce.light_color=Color(0.84,0.67,0.48)
	bounce.light_energy=0.13
	bounce.omni_range=21
	add_child(bounce)

func attach_actors(states: Array) -> void:
	for index in range(4):
		var actor:=Actor25D.new()
		actor.actor_index=index
		actor.state=states[index]
		add_child(actor)
		actor.update_from_state()
		actors.append(actor)

func set_camera(x: float) -> void:
	var target:=Vector3(x,2.60,0)
	camera.position=target+Vector3(0,tan(deg_to_rad(15.0))*24,24)
	camera.look_at(target,Vector3.UP)

func sun_visibility(point: Vector3) -> float:
	# Used ONLY for optical flare; surface lighting uses Godot shadow maps.
	var toward_light:=-sun_direction
	for blocker in blockers:
		if blocker.intersects_ray(point,toward_light)!=null:
			return 0.0
	return 1.0
