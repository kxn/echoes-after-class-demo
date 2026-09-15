extends "res://scripts/stage_25d.gd"

const PaintedActor=preload("res://scripts/actor_painted.gd")
var painted_mode: bool=true
var shadow_materials: Array[ShaderMaterial]=[]
var shadows_enabled: bool=true
var idle_silhouettes: Array[Texture2D]=[]
var walk_silhouette: Texture2D
const WINDOW_BAYS=[Vector2(0.157,0.226),Vector2(0.285,0.356),Vector2(0.428,0.500),Vector2(0.586,0.656),Vector2(0.733,0.799)]

func _ready() -> void:
	name="PaintedSceneWithSelectiveCharacterLight"
	for i in range(4):
		idle_silhouettes.append(load("res://assets/painted/actor_%d_shadow.png"%i))
	walk_silhouette=load("res://assets/painted/walk_shadow.png")
	wood=StandardMaterial3D.new()
	var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("201d25")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_DISABLED
	env.ambient_light_energy=0.0
	env.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	environment=WorldEnvironment.new()
	environment.environment=env
	add_child(environment)
	var info: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/painted/layers.json"))
	var full:=load("res://assets/painted/classroom_composite.png") as Texture2D
	add_painted_card(full,Rect2(0,0,32.4,10.8),0.0,"CompletePainting")
	var factor:=32.4/float(info.width)
	for layer in info.layers:
		var rect:=Rect2(float(layer.x)*factor,float(layer.y)*factor,float(layer.w)*factor,float(layer.h)*factor)
		var card:=add_painted_card(load("res://assets/painted/"+layer.file),rect,4.2 if layer.row==0 else 8.0,layer.file.get_basename())
		desks.append(card)
		build_top_receiver(layer)
	build_window_occluders()
	sun=DirectionalLight3D.new()
	sun.name="ExteriorLightForSelectedCharacterRegionsOnly"
	sun.light_color=Color(1.0,0.75,0.39)
	sun.light_energy=1.6
	sun.light_cull_mask=1
	sun.shadow_caster_mask=1
	sun.shadow_enabled=true
	sun.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.shadow_bias=0.012
	sun.shadow_normal_bias=0.025
	add_child(sun)
	sun.look_at_from_position(Vector3(20,12,-16),Vector3(20,12,-16)+sun_direction,Vector3.UP)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
	camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=9.0
	camera.near=0.1
	camera.far=48.0
	add_child(camera)
	camera.make_current()
	set_camera(7.2)
	build_memory_dust()

func build_memory_dust() -> void:
	# Sparse, world-anchored flecks, behind characters and furniture, not screen noise.
	for i in range(18):
		var mote:=MeshInstance3D.new()
		var mesh:=QuadMesh.new()
		mesh.size=Vector2.ONE*(0.018+float(i%3)*0.005)
		mote.mesh=mesh
		mote.position=Vector3(5.1+fmod(float(i)*3.79,20.5),3.1+fmod(float(i)*0.71,3.6),1.5)
		var material:=ShaderMaterial.new()
		material.shader=preload("res://shaders/memory_dust.gdshader")
		material.set_shader_parameter("phase",float(i)*2.39)
		mote.material_override=material
		mote.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mote.name="QuietDust_%02d"%i
		add_child(mote)

func _process(_delta: float) -> void:
	if actors.size()!=4:
		return
	var bounds:=PackedVector4Array()
	var regions:=PackedVector4Array()
	var depths:=Vector4()
	var flips:=Vector4()
	for i in range(4):
		var actor=actors[i]
		var size: Vector2=actor.quad.mesh.size
		var bottom: float=actor.position.y+actor.quad.position.y-size.y/2.0
		bounds.append(Vector4(10000,10000,1,1) if actor.state.departed else Vector4(actor.position.x-size.x/2.0,bottom,size.x,size.y))
		regions.append(actor.paint.get_shader_parameter("uv_region"))
		depths[i]=actor.position.z
		flips[i]=1.0 if actor.paint.get_shader_parameter("flipped") else 0.0
	for material in shadow_materials:
		material.set_shader_parameter("sun_enabled",sun.visible and shadows_enabled)
		material.set_shader_parameter("sun_ray",sun_direction)
		material.set_shader_parameter("card_bounds",bounds)
		material.set_shader_parameter("regions",regions)
		material.set_shader_parameter("depths",depths)
		material.set_shader_parameter("flips",flips)
		for i in range(4):
			material.set_shader_parameter("silhouette_%d"%i,actors[i].current_silhouette)

func build_top_receiver(layer: Dictionary) -> void:
	var points:=PackedVector3Array()
	var uvs:=PackedVector2Array()
	var far_depth:=3.5 if layer.row==0 else 7.6
	for i in range(4):
		var p: Array=layer.top_review_coordinates[i]
		points.append(Vector3(float(p[0])/2048.0*32.4,10.8-float(p[1])/683.0*10.8,far_depth+(0.0 if i<2 else 2.2)))
		uvs.append(Vector2(float(p[0])/2048.0,float(p[1])/683.0))
	var normal: Vector3=(points[1]-points[0]).cross(points[2]-points[0]).normalized()
	var material:=ShaderMaterial.new()
	material.shader=preload("res://shaders/painted_shadow_receiver.gdshader")
	material.set_shader_parameter("painting",load("res://assets/painted/classroom_composite.png"))
	var receiver:=flat_quad(points,uvs,normal,material)
	receiver.layers=4
	receiver.name="SoftShadowReceiver_"+layer.file.get_basename()
	receiver.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow_materials.append(material)

func add_painted_card(texture: Texture2D,rect: Rect2,depth: float,label: String) -> MeshInstance3D:
	var mat:=StandardMaterial3D.new()
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture=texture
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold=0.48
	mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
	var mesh:=QuadMesh.new()
	mesh.size=rect.size
	var card:=MeshInstance3D.new()
	card.name=label
	card.mesh=mesh
	card.material_override=mat
	card.position=Vector3(rect.get_center().x,10.8-rect.get_center().y,depth)
	card.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(card)
	return card

func build_window_occluders() -> void:
	var lower:=10.8*(1.0-0.555)
	var upper:=10.8*(1.0-0.170)
	box(Vector3(WIDTH/2,lower/2,-0.08),Vector3(WIDTH,lower,0.22),wood,self,true)
	box(Vector3(WIDTH/2,(upper+10.8)/2,-0.08),Vector3(WIDTH,10.8-upper,0.22),wood,self,true)
	var previous:=0.0
	for opening in WINDOW_BAYS:
		var left: float=opening.x*WIDTH
		var right: float=opening.y*WIDTH
		box(Vector3((previous+left)/2,(lower+upper)/2,-0.08),Vector3(left-previous,upper-lower,0.22),wood,self,true)
		var mid: float=(left+right)/2
		box(Vector3(mid,(lower+upper)/2,-0.10),Vector3(0.14,upper-lower,0.16),wood,self,true)
		for crossbar in [0.255,0.339,0.412,0.486]:
			box(Vector3(mid,10.8*(1.0-crossbar),-0.10),Vector3(right-left,0.10,0.16),wood,self,true)
		previous=right
	box(Vector3((previous+WIDTH)/2,(lower+upper)/2,-0.08),Vector3(WIDTH-previous,upper-lower,0.22),wood,self,true)

func attach_actors(states: Array) -> void:
	for index in range(4):
		var actor:=PaintedActor.new()
		actor.actor_index=index
		actor.state=states[index]
		add_child(actor)
		actor.update_from_state()
		actors.append(actor)

func set_camera(x: float) -> void:
	camera.position=Vector3(x,5.4,24)
	camera.look_at(Vector3(x,5.4,0),Vector3.UP)
