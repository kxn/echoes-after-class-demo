extends "res://scripts/actor_25d.gd"

var idle_response: Texture2D
var walk_response: Texture2D
var response_frame: int=-999
var stop_albedo: Texture2D
var stop_normal: Texture2D
var stop_response: Texture2D
var stop_shadow: Texture2D
var stop_frames: int=0
var stop_rows: int=1
var stop_elapsed: float=-1.0
const STOP_DURATION:=0.24
const START_DURATION:=0.14
var transition_starting: bool=false
var current_silhouette: Texture2D
var idle_silhouette: Texture2D
var walk_silhouette: Texture2D
var blink_wait: float=4.0
var blink_elapsed: float=-1.0
var blink_rng:=RandomNumberGenerator.new()
var blink_count: int=0

func _ready() -> void:
	super._ready()
	paint.shader=preload("res://shaders/actor_painted.gdshader")
	paint.set_shader_parameter("albedo_tex",idle_albedo)
	paint.set_shader_parameter("normals_tex",idle_normal)
	paint.set_shader_parameter("uv_region",Vector4(0,0,1,1))
	idle_response=load("res://assets/painted/actor_%d_response.png"%actor_index)
	if walk_count>0:
		walk_response=load("res://assets/painted/"+walk_prefix+"_response.png")
	paint.set_shader_parameter("response_tex",idle_response)
	paint.set_shader_parameter("breath_phase",float(actor_index)*1.73)
	paint.set_shader_parameter("blink_tex",load("res://assets/relit/actor_%d_blink.png"%actor_index) if ResourceLoader.exists("res://assets/relit/actor_%d_blink.png"%actor_index) else idle_albedo)
	blink_rng.seed=19720916+actor_index*7919
	blink_wait=2.3+float(actor_index)*1.17
	idle_silhouette=load("res://assets/painted/actor_%d_shadow.png"%actor_index)
	current_silhouette=idle_silhouette
	if walk_count>0:
		walk_silhouette=load("res://assets/painted/"+walk_prefix+"_shadow.png")
	if actor_index==0:
		if FileAccess.file_exists("res://assets/relit/stop.json"):
			var info: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/relit/stop.json"))
			stop_frames=int(info.frames)
			stop_rows=ceili(float(stop_frames)/8.0)
			stop_albedo=load("res://assets/relit/stop_albedo.png")
			stop_normal=load("res://assets/relit/stop_normal.png")
			stop_response=load("res://assets/painted/stop_response.png")
			stop_shadow=load("res://assets/painted/stop_shadow.png")
	quad.layers=3
	quad.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED

func position_from_state() -> Vector3:
	return Vector3(state.position.x/100.0,10.8-state.position.y/100.0,3.0+(state.position.y-840.0)/120.0*3.5)

func update_from_state() -> void:
	var was_moving:=was_walking
	super.update_from_state()
	paint.set_shader_parameter("idle_amount",0.0 if state.moving else 1.0)
	# Facing is a semantic world direction, independent of the source atlas pose.
	paint.set_shader_parameter("faces_sun",state.facing>0)
	# Broad room value only; no window-periodic brightness for a backlit figure.
	var room_exposure:=lerpf(0.91,1.03,smoothstep(300.0,2700.0,state.position.x))
	paint.set_shader_parameter("global_exposure",room_exposure)
	if response_frame!=active_frame:
		response_frame=active_frame
		paint.set_shader_parameter("response_tex",walk_response if active_frame>=0 else idle_response)
	current_silhouette=walk_silhouette if active_frame>=0 else idle_silhouette
	if state.moving:
		if not was_moving and stop_frames>0:
			stop_elapsed=0.0
			transition_starting=true
		elif not transition_starting:
			stop_elapsed=-1.0
	elif was_moving and stop_frames>0:
		stop_elapsed=0.0
		transition_starting=false
	if stop_elapsed>=0.0:
		stop_elapsed+=get_process_delta_time()
		var duration:=START_DURATION if transition_starting else STOP_DURATION
		if stop_elapsed<duration:
			var frame:=mini(int(stop_elapsed/duration*stop_frames),stop_frames-1)
			if transition_starting: frame=stop_frames-1-frame
			paint.set_shader_parameter("albedo_tex",stop_albedo)
			paint.set_shader_parameter("normals_tex",stop_normal)
			paint.set_shader_parameter("response_tex",stop_response)
			paint.set_shader_parameter("uv_region",Vector4(float(frame%8)/8.0,float(frame/8)/float(stop_rows),1.0/8.0,1.0/float(stop_rows)))
			current_silhouette=stop_shadow
			paint.set_shader_parameter("idle_amount",0.0)
		else:
			stop_elapsed=-1.0
			if state.moving:
				paint.set_shader_parameter("albedo_tex",walk_albedo)
				paint.set_shader_parameter("normals_tex",walk_normal)
				paint.set_shader_parameter("response_tex",walk_response)
				paint.set_shader_parameter("uv_region",Vector4(float(active_frame%8)/8.0,float(active_frame/8)/float(walk_rows),1.0/8.0,1.0/float(walk_rows)))
			else:
				paint.set_shader_parameter("albedo_tex",idle_albedo)
				paint.set_shader_parameter("normals_tex",idle_normal)
				paint.set_shader_parameter("response_tex",idle_response)
				paint.set_shader_parameter("uv_region",Vector4(0,0,1,1))
	update_blink(get_process_delta_time())

func update_blink(delta: float) -> void:
	var amount:=0.0
	if state.moving or stop_elapsed>=0.0:
		blink_elapsed=-1.0
		blink_wait=maxf(blink_wait,0.8)
	else:
		blink_wait-=delta
		if blink_wait<=0.0 and blink_elapsed<0.0:
			blink_elapsed=0.0
			blink_count+=1
		if blink_elapsed>=0.0:
			blink_elapsed+=delta
			if blink_elapsed<0.045: amount=blink_elapsed/0.045
			elif blink_elapsed<0.085: amount=1.0
			elif blink_elapsed<0.17: amount=1.0-(blink_elapsed-0.085)/0.085
			else:
				blink_elapsed=-1.0
				blink_wait=blink_rng.randf_range(3.5,6.8)
	paint.set_shader_parameter("blink_amount",amount)
