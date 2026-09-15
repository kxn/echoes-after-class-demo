extends "res://scripts/classroom_25d.gd"

const PaintedStage=preload("res://scripts/stage_painted.gd")
var footfall_number: int=0
var footfall_log: Array[Dictionary]=[]
var footfall_samples: Array[AudioStream]=[]
var review_camera_x: float=-1.0
var radio: AudioStreamPlayer
var departure_steps: AudioStreamPlayer
var radio_clock: float=0.0
var radio_data: Dictionary

func create_stage() -> Node3D:
	return PaintedStage.new()

func _ready() -> void:
	super._ready()
	Engine.max_fps=60
	# On this Windows/OpenGL setup VSync presentation stalls alternate near 31 ms.
	# Use one explicit 60 Hz limiter instead of waiting on driver presentation.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# The inherited 2D actors are state holders; their old sprite animation is hidden.
	for actor in actors:
		actor.set_process(false)
	# Movement and sprite sampling share the render clock, avoiding 60 Hz proxy jitter.
	set_physics_process(false)
	footsteps_from_animation=true
	for i in range(3):
		footfall_samples.append(load("res://assets/audio/cloth_brick_%d.wav"%i))
	footsteps.volume_db=-11.5
	stage.actors[0].foot_planted.connect(play_footfall)
	radio=AudioStreamPlayer.new()
	radio.stream=preload("res://assets/audio/broadcast/school-outdoor.wav")
	radio.volume_db=-10.0
	add_child(radio)
	departure_steps=AudioStreamPlayer.new()
	add_child(departure_steps)
	stage.actors[2].foot_planted.connect(play_departure_step)
	radio_data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/broadcast/cues.json"))
	show_toast("夕阳留在画里。A/D 行走，E 交谈；L 对比人物动态受光。",7)
	if walk_demo:
		toast_timer=0
		muted=false
	if OS.get_cmdline_user_args().has("--revision-capture"):
		call_deferred("capture_revision")

func update_camera(delta: float) -> void:
	super.update_camera(delta)
	if review_camera_x>=0:
		camera.position.x=review_camera_x
		stage.set_camera(review_camera_x/100.0)

func _exit_tree() -> void:
	if walk_demo:
		var file:=FileAccess.open("res://docs/layout-v3/footfall-timeline.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(footfall_log,"\t"))

func capture_revision() -> void:
	toast_timer=0
	player.position=Vector2(2420,BACK_LANE)
	review_camera_x=2450
	flare_enabled=false
	stage.shadows_enabled=false
	for facing in [1,-1]:
		player.facing=facing
		for lit in [true,false]:
			stage.sun.visible=lit
			await get_tree().create_timer(0.35).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://docs/revision2/face_%s_%s.png"%["right" if facing>0 else "left","lit" if lit else "base"])
	print("FACING_REVIEW_SAVED")
	get_tree().quit()

func play_footfall(frame_index: int) -> void:
	footfall_log.append({"frame":frame_index,"time":elapsed,"phase":stage.actors[0].distance_phase})
	if muted:
		return
	footsteps.stream=footfall_samples[footfall_number%footfall_samples.size()]
	footsteps.pitch_scale=1.0
	footsteps.play()
	footfall_number+=1

func _process(delta: float) -> void:
	update_broadcast(delta)
	if not walk_demo and not OS.get_cmdline_user_args().has("--test") and not OS.get_cmdline_user_args().has("--capture"):
		super._physics_process(delta)
	super._process(delta)

func on_ending_finished() -> void:
	if radio_phase!="none":
		return
	radio_phase="bell"
	radio_clock=0.0
	toast_timer=0

func update_nearby() -> void:
	super.update_nearby()
	if radio_phase in ["bell","broadcast"]:
		nearby=0

func begin_talk(index: int) -> void:
	if radio_phase in ["bell","broadcast"]:
		return
	super.begin_talk(index)

func update_broadcast(delta: float) -> void:
	if radio==null:
		return
	radio.volume_db=-80.0 if muted else -10.0
	if radio_phase=="bell":
		radio_clock+=delta
		if radio_clock>=bell.stream.get_length():
			radio_clock=0.0
			radio_phase="broadcast"
			radio.play()
	elif radio_phase=="broadcast":
		radio_clock+=delta
		radio_caption=""
		for cue in radio_data.cues:
			if radio_clock>=float(cue.start) and radio_clock<float(cue.end):
				radio_caption=str(cue.text)
				break
		if radio_clock>=float(radio_data.duration):
			radio.stop()
			radio_caption=""
			radio_phase="aftermath"
			aftermath_active=true
			actors[2].leaving=true
			show_toast("广播停了。周槐生抱起书，向后门走去。",4)
	elif radio_phase=="aftermath" and actors[2].leaving:
		var actor=actors[2]
		actor.facing=-1
		actor.moving=true
		actor.position=actor.position.move_toward(Vector2(115,BACK_LANE),135.0*delta)
		if actor.position.distance_to(Vector2(115,BACK_LANE))<1.0:
			actor.departed=true
			actor.leaving=false
			actor.moving=false

func play_departure_step(_frame: int) -> void:
	if muted or not actors[2].leaving:
		return
	departure_steps.stream=footfall_samples[footfall_number%3]
	departure_steps.volume_db=-18.0-minf(absf(player.position.x-actors[2].position.x)/100.0,24.0)
	departure_steps.play()
	footfall_number+=1

func screen_point(world: Vector2) -> Vector2:
	if stage!=null:
		for i in actors.size():
			if absf(world.x-actors[i].position.x)<0.01 and absf(world.y-actors[i].head_position().y)<0.02:
				return stage.camera.unproject_position(stage.actors[i].head_world())
	return get_viewport().get_canvas_transform()*world

func update_lighting() -> void:
	if stage==null:
		return
	var eye:=Vector3(player.position.x/100.0,10.8-player.position.y/100.0+3.4,3.0+(player.position.y-BACK_LANE)/120.0*3.5)
	var alignment:=exp(-pow((camera.position.x-SUN.x)/720.0,2))
	flare_strength=(0.02+alignment*0.56)*stage.sun_visibility(eye) if stage.sun.visible else 0.0
	displayed_flare=lerpf(displayed_flare,flare_strength,1.0-exp(-get_process_delta_time()*12.0))
	effect.set_shader_parameter("light_uv",screen_point(SUN)/get_viewport_rect().size)
	effect.set_shader_parameter("strength",displayed_flare)
	effect.set_shader_parameter("enabled",flare_enabled)

func _input(event: InputEvent) -> void:
	if stage==null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if code==KEY_L:
			stage.sun.visible=not stage.sun.visible
			show_toast("人物动态增亮：开" if stage.sun.visible else "人物动态增亮：关；保留整景与人物底图明暗")
			return
		if code==KEY_R:
			stage.shadows_enabled=not stage.shadows_enabled
			show_toast("桌面人物投影：开" if stage.shadows_enabled else "桌面人物投影：关")
			return
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		if notes_open:
			return
		if not dialogue.is_empty():
			advance_talk()
			return
		var world:=get_global_mouse_position()
		pending_interaction=0
		for i in range(1,4):
			if actors[i].leaving or actors[i].departed or radio_phase in ["bell","broadcast"]:
				continue
			if absf(world.x-actors[i].position.x)<85 and world.y>actors[i].position.y-430 and world.y<actors[i].position.y+20:
				pending_interaction=i
				world=actors[i].position+Vector2(-110 if player.position.x<=actors[i].position.x else 110,0)
				break
		if clues.size()==3 and world.distance_to(Vector2(2450,450))<90:
			pending_interaction=4
			world=Vector2(2450,BACK_LANE)
		if world.y>710 or pending_interaction>0:
			waypoints=build_route(world)
		return
	super._input(event)

func capture_views() -> void:
	await get_tree().create_timer(0.6).timeout
	toast_timer=0
	player.position=Vector2(915,BACK_LANE)
	begin_talk(1)
	revealed=999
	await save_view("01-dialogue")
	dialogue.clear()
	player.position=Vector2(2410,FRONT_LANE)
	camera.position.x=2480
	flare_enabled=false
	await save_view("02-character-light-on")
	stage.sun.hide()
	await save_view("03-character-light-off")
	stage.sun.show()
	flare_enabled=true
	player.position=actors[3].position+Vector2(-135,0)
	begin_talk(3)
	revealed=999
	await save_view("04-tang-placement")
	dialogue.clear()
	player.position=Vector2(2200,BACK_LANE)
	camera.position.x=2270
	flare_enabled=false
	await save_view("05-desk-shadow-on")
	stage.shadows_enabled=false
	await save_view("06-desk-shadow-off")
	print("PAINTED_CAPTURES_SAVED")
	get_tree().quit()

func save_view(label: String) -> void:
	await get_tree().create_timer(1.1).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/painted/"+label+".png")
