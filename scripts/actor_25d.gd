extends Node3D
signal foot_planted(frame_index: int)

var actor_index: int = 0
var state: Node2D
var quad: MeshInstance3D
var paint: ShaderMaterial
var idle_albedo: Texture2D
var idle_normal: Texture2D
var walk_albedo: Texture2D
var walk_normal: Texture2D
var walk_count: int = 0
var walk_columns: int = 8
var walk_rows: int = 1
var distance_phase: float = 0.0
var previous_position := Vector3.ZERO
var body_height: float = 4.0
var active_frame: int = -1
var walk_contacts: Array[int]=[]
var stride_length: float=2.30
var was_walking: bool=false
var walk_prefix: String=""

func _ready() -> void:
	body_height=4.0*[1.0,0.94,1.02,0.92][actor_index]
	idle_albedo=load("res://assets/relit/actor_%d_albedo.png"%actor_index)
	idle_normal=load("res://assets/relit/actor_%d_normal.png"%actor_index)
	walk_prefix="walk" if actor_index==0 else ("npc_2_walk" if actor_index==2 else "")
	if not walk_prefix.is_empty() and FileAccess.file_exists("res://assets/relit/"+walk_prefix+".json"):
		var info: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/relit/"+walk_prefix+".json"))
		walk_count=int(info.frames)
		stride_length=float(info.get("stride_world_units",2.30))
		for contact in info.get("contact_frames",[]):
			walk_contacts.append(int(contact))
		walk_rows=ceili(float(walk_count)/8.0)
		walk_albedo=load("res://assets/relit/"+walk_prefix+"_albedo.png")
		walk_normal=load("res://assets/relit/"+walk_prefix+"_normal.png")
	paint=ShaderMaterial.new()
	paint.shader=preload("res://shaders/actor_lit.gdshader")
	paint.set_shader_parameter("albedo_tex",idle_albedo)
	paint.set_shader_parameter("normals_tex",idle_normal)
	quad=MeshInstance3D.new()
	quad.name="PaintedCharacterReceivingShadows"
	var mesh:=QuadMesh.new()
	var h:=body_height*640.0/560.0
	mesh.size=Vector2(h*384.0/640.0,h)
	quad.mesh=mesh
	quad.position.y=h*(610.0/640.0-0.5)
	quad.material_override=paint
	quad.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	add_child(quad)

func position_from_state() -> Vector3:
	return Vector3(state.position.x/100.0,0.012,3.0+(state.position.y-840.0)/120.0*3.5)

func update_from_state() -> void:
	position=position_from_state()
	visible=not state.departed
	# Depth is stretched for occlusion. Undo that stretch for gait distance;
	# including the proxy's Y/Z distance makes lane changes triple the cadence.
	var displacement:=position-previous_position
	var distance:=Vector2(displacement.x,displacement.z*120.0/350.0).length()
	var is_walk: bool=state.moving and walk_count>0
	var old_phase:=distance_phase
	if is_walk and not was_walking:
		distance_phase=0.0
		old_phase=0.0
	if distance<0.5 and is_walk:
		distance_phase+=distance/stride_length
	previous_position=position
	var frame:=int(distance_phase*walk_count)%maxi(walk_count,1) if is_walk else -1
	if frame!=active_frame:
		active_frame=frame
		paint.set_shader_parameter("albedo_tex",walk_albedo if is_walk else idle_albedo)
		paint.set_shader_parameter("normals_tex",walk_normal if is_walk else idle_normal)
		if is_walk:
			paint.set_shader_parameter("uv_region",Vector4(float(frame%8)/8.0,float(frame/8)/float(walk_rows),1.0/8.0,1.0/float(walk_rows)))
		else:
			paint.set_shader_parameter("uv_region",Vector4(0,0,1,1))
	paint.set_shader_parameter("flipped",state.facing>0 if actor_index in [1,3] else state.facing<0)
	if is_walk and was_walking and distance>0.0 and distance<0.5:
		for crossed in range(int(floor(old_phase*walk_count))+1,int(floor(distance_phase*walk_count))+1):
			if crossed%walk_count in walk_contacts:
				foot_planted.emit(crossed%walk_count)
	was_walking=is_walk

func head_world() -> Vector3:
	return global_position+Vector3(0,body_height+0.12,0)
