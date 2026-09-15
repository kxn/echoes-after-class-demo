extends "res://scripts/classroom.gd"

const Stage=preload("res://scripts/stage_25d.gd")
var stage: Node3D
var alternate_sun: bool=false
var walk_demo: bool=false
var demo_time: float=0.0
var displayed_flare: float=0.0

func _ready() -> void:
	super._ready()
	$Backdrop.hide()
	furniture.hide()
	stage=create_stage()
	add_child(stage)
	stage.attach_actors(actors)
	show_toast("夕阳穿过窗框。A/D 行走，E 交谈；L 关太阳，N 关法线。",8)
	if OS.get_cmdline_user_args().has("--walk-demo"):
		walk_demo=true
		muted=true
		set_physics_process(false)
		player.position=Vector2(950,FRONT_LANE)
		camera.position.x=1020
		toast_timer=0

func create_stage() -> Node3D:
	return Stage.new()

func _process(delta: float) -> void:
	if stage==null:
		return
	if walk_demo:
		demo_time+=delta
		if demo_time>10.5:
			get_tree().quit()
		player.moving=false
		move_manual(1 if demo_time<9.5 else 0,0,delta)
	for actor in stage.actors:
		actor.update_from_state()
	super._process(delta)

func screen_point(world: Vector2) -> Vector2:
	if stage==null:
		return super.screen_point(world)
	for i in actors.size():
		if absf(world.x-actors[i].position.x)<0.01 and absf(world.y-actors[i].head_position().y)<0.02:
			return stage.camera.unproject_position(stage.actors[i].head_world())
	if world.x==2450:
		return stage.camera.unproject_position(Vector3(24.5,3.8 if world.y==400 else 3.3,-0.01))
	return stage.camera.unproject_position(Vector3(world.x/100.0,0,3+(world.y-840)/120*3.5))

func update_camera(delta: float) -> void:
	super.update_camera(delta)
	if stage!=null:
		stage.set_camera(camera.position.x/100.0)

func update_lighting() -> void:
	if stage==null:
		return
	var uv:=screen_point(SUN)/get_viewport_rect().size
	var alignment:=exp(-pow((camera.position.x-SUN.x)/720.0,2))
	var eye:=Vector3(player.position.x/100.0,3.412,3.0+(player.position.y-BACK_LANE)/120.0*3.5)
	var visible_sun: float=stage.sun_visibility(eye)
	flare_strength=(0.035+alignment*0.90)*visible_sun if stage.sun.visible else 0.0
	displayed_flare=lerpf(displayed_flare,flare_strength,1.0-exp(-get_process_delta_time()*12.0))
	effect.set_shader_parameter("light_uv",uv)
	effect.set_shader_parameter("strength",displayed_flare)
	effect.set_shader_parameter("enabled",flare_enabled)

func _input(event: InputEvent) -> void:
	if stage==null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if code==KEY_L:
			stage.sun.visible=not stage.sun.visible
			show_toast("真实太阳光：开" if stage.sun.visible else "真实太阳光：关（保留室内散射光）")
			return
		if code==KEY_N:
			stage.normals_enabled=not stage.normals_enabled
			for actor in stage.actors:
				actor.paint.set_shader_parameter("use_normals",stage.normals_enabled)
			show_toast("人物辅助法线：开" if stage.normals_enabled else "人物辅助法线：关")
			return
		if code==KEY_T:
			alternate_sun=not alternate_sun
			stage.sun_direction=Vector3(0.45 if alternate_sun else -0.45,-0.52,1).normalized()
			stage.sun.look_at_from_position(Vector3(20,12,-16),Vector3(20,12,-16)+stage.sun_direction,Vector3.UP)
			show_toast("光照检查：另一侧入射" if alternate_sun else "恢复夕阳入射方向")
			return
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		if notes_open:
			return
		if not dialogue.is_empty():
			advance_talk()
			return
		var mouse:=get_viewport().get_mouse_position()
		pending_interaction=0
		for i in range(1,4):
			var body=stage.actors[i]
			var top: Vector2=stage.camera.unproject_position(body.head_world())
			var foot: Vector2=stage.camera.unproject_position(body.global_position)
			if mouse.x>top.x-75 and mouse.x<top.x+75 and mouse.y>top.y-75 and mouse.y<foot.y+15:
				pending_interaction=i
				waypoints=build_route(actors[i].position+Vector2(-110 if player.position.x<=actors[i].position.x else 110,0))
				return
		if clues.size()==3 and mouse.distance_to(screen_point(Vector2(2450,450)))<85:
			pending_interaction=4
			waypoints=build_route(Vector2(2450,BACK_LANE))
			return
		var ray_start: Vector3=stage.camera.project_ray_origin(mouse)
		var ray_direction: Vector3=stage.camera.project_ray_normal(mouse)
		var hit=Plane(Vector3.UP,0).intersects_ray(ray_start,ray_direction)
		if hit!=null and hit.z>1.8 and hit.z<12:
			waypoints=build_route(Vector2(hit.x*100,BACK_LANE if hit.z<4.9 else FRONT_LANE))
		return
	super._input(event)

func _draw() -> void:
	if stage==null or not debug_paths:
		return
	var inverse:=get_canvas_transform().affine_inverse()
	for lane in [BACK_LANE,FRONT_LANE]:
		var a: Vector2=inverse*screen_point(Vector2(190,lane))
		var b: Vector2=inverse*screen_point(Vector2(WALK_RIGHT_LIMIT,lane))
		draw_line(a,b,Color(0.85,0.74,0.42,0.65),2)

func capture_views() -> void:
	await get_tree().create_timer(1.0).timeout
	player.position=Vector2(915,BACK_LANE)
	camera.position.x=940
	begin_talk(1)
	revealed=999
	await save_view("01-dialogue")
	dialogue.clear()
	player.position=Vector2(2260,BACK_LANE)
	camera.position.x=2330
	toast_timer=0
	await save_view("02-sun-on")
	stage.sun.hide()
	await save_view("03-sun-off")
	stage.sun.show()
	stage.sun_direction=Vector3(0.45,-0.52,1).normalized()
	stage.sun.look_at_from_position(Vector3(20,12,-16),Vector3(20,12,-16)+stage.sun_direction,Vector3.UP)
	await save_view("04-sun-reversed")
	stage.sun_direction=Vector3(-0.45,-0.52,1).normalized()
	stage.sun.look_at_from_position(Vector3(20,12,-16),Vector3(20,12,-16)+stage.sun_direction,Vector3.UP)
	player.position=Vector2(1720,FRONT_LANE)
	begin_talk(3)
	revealed=999
	await save_view("05-front-lane")
	print("RELIT_CAPTURES_SAVED")
	get_tree().quit()

func save_view(label: String) -> void:
	await get_tree().create_timer(1.1).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/relighting/"+label+".png")
