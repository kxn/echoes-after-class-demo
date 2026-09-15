extends Node2D

const Actor = preload("res://scripts/actor.gd")
const Hud = preload("res://scripts/hud.gd")
const Story = preload("res://scripts/story.gd")
const WORLD_WIDTH := 3240.0
const BACK_LANE := 840.0
const FRONT_LANE := 960.0
const LEFT_END := 240.0
const RIGHT_END := 2460.0
const WALK_RIGHT_LIMIT := 2480.0
const RIGHT_TURN_START := 2440.0
const SPEED := 205.0
const SUN := Vector2(2450, 400)
const DESKS = preload("res://assets/art/desks_key.png")
const DESK_REGIONS = [Rect2(32, 101, 686, 570), Rect2(756, 100, 576, 571), Rect2(1370, 81, 688, 591)]

@onready var camera: Camera2D = $Camera
var actors: Array = []
var player: Node2D
var furniture: Node2D
var hud: Control
var effect: ShaderMaterial
var nearby: int = 0
var dialogue: Array = []
var line_index: int = 0
var revealed: float = 0
var current_npc: int = 0
var clues: Array[int] = []
var ending_complete: bool = false
var aftermath_active: bool = false
var radio_phase: String = "none"
var radio_caption: String = ""
var notes_open: bool = false
var debug_paths: bool = false
var flare_enabled: bool = true
var flare_strength: float = 0.0
var toast: String = "放学铃迟迟未响。先去问问沈禾。"
var toast_timer: float = 8.0
var waypoints: Array[Vector2] = []
var pending_interaction: int = 0
var elapsed: float = 0.0
var travel_distance: float = 0.0
var muted: bool = false
var footsteps: AudioStreamPlayer
var bell: AudioStreamPlayer
var route_overlay: Node2D
var footsteps_from_animation: bool=false

func _ready() -> void:
	setup_input()
	$Backdrop.scale = Vector2(3240.0 / $Backdrop.texture.get_width(), 1080.0 / $Backdrop.texture.get_height())
	furniture = Node2D.new()
	furniture.name = "DepthSortedActorsAndDesks"
	furniture.y_sort_enabled = true
	add_child(furniture)
	for i in range(7):
		add_desk(Vector2(625 + i * 350, 913), i % 3, 325.0, 0.80)
		add_desk(Vector2(600 + i * 365, 1150), (i + 2) % 3, 370.0, 0.63)
	var positions := [Vector2(480, BACK_LANE), Vector2(1025, BACK_LANE), Vector2(2270, BACK_LANE), Vector2(1505, BACK_LANE)]
	for i in range(4):
		var actor = Actor.new()
		actor.name = ["XuZhiqiu", "ShenHe", "ZhouHuaisheng", "TangXiaoman"][i]
		actor.character_index = i
		actor.display_name = Story.NAMES[i]
		actor.position = positions[i]
		actor.facing = -1 if i == 1 or i == 2 else 1
		furniture.add_child(actor)
		actors.append(actor)
	player = actors[0]
	var lighting := CanvasLayer.new()
	lighting.layer = 5
	add_child(lighting)
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect = ShaderMaterial.new()
	effect.shader = preload("res://shaders/sunset.gdshader")
	overlay.material = effect
	lighting.add_child(overlay)
	var interface := CanvasLayer.new()
	interface.layer = 10
	add_child(interface)
	hud = Hud.new()
	hud.game = self
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	interface.add_child(hud)
	setup_audio()
	if OS.get_cmdline_user_args().has("--test"):
		call_deferred("run_tests")
	elif OS.get_cmdline_user_args().has("--capture"):
		call_deferred("capture_views")

func setup_input() -> void:
	var bindings := {"walk_left": [KEY_A, KEY_LEFT], "walk_right": [KEY_D, KEY_RIGHT], "lane_up": [KEY_W, KEY_UP], "lane_down": [KEY_S, KEY_DOWN], "talk": [KEY_E, KEY_SPACE, KEY_ENTER], "notes": [KEY_TAB], "cancel_talk": [KEY_ESCAPE], "paths": [KEY_F1], "glare": [KEY_G], "mute": [KEY_M]}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
			var logical := InputEventKey.new()
			logical.keycode = key
			InputMap.action_add_event(action, logical)

func add_desk(pos: Vector2, variant: int, width: float, exposure: float) -> void:
	var prop := Node2D.new()
	prop.position = pos
	prop.name = "Desk_%d_%d" % [pos.x, pos.y]
	var sprite := Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = DESKS
	atlas.region = DESK_REGIONS[variant]
	sprite.texture = atlas
	# Normalize physical height, not atlas width: the satchel variant is narrower.
	var factor := width * 0.80 / atlas.region.size.y
	sprite.scale = Vector2.ONE * factor
	sprite.position.y = -atlas.region.size.y * factor * 0.5
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/chroma.gdshader")
	mat.set_shader_parameter("exposure", exposure)
	sprite.material = mat
	prop.add_child(sprite)
	furniture.add_child(prop)

func _process(delta: float) -> void:
	elapsed += delta
	toast_timer = maxf(0, toast_timer - delta)
	if not dialogue.is_empty():
		revealed = minf(revealed + delta * 26.0, str(dialogue[line_index][1]).length())
	update_nearby()
	update_camera(delta)
	update_lighting()
	queue_redraw()

func _physics_process(delta: float) -> void:
	if player == null:
		return
	player.moving = false
	if not dialogue.is_empty() or notes_open:
		return
	var direction := Input.get_axis("walk_left", "walk_right")
	var vertical := Input.get_axis("lane_up", "lane_down")
	if direction != 0 or vertical != 0:
		waypoints.clear()
		pending_interaction = 0
		move_manual(direction, vertical, delta)
	elif not waypoints.is_empty():
		move_route(delta)
	if not footsteps_from_animation and player.moving and travel_distance > 83.0:
		travel_distance = 0.0
		if not muted:
			footsteps.pitch_scale = 0.91 + randf() * 0.16
			footsteps.play()

func move_manual(horizontal: float, vertical: float, delta: float) -> void:
	var old: Vector2 = player.position
	var at_end: bool = player.position.x <= 340 or player.position.x >= RIGHT_TURN_START
	var between: bool = player.position.y > BACK_LANE + 1 and player.position.y < FRONT_LANE - 1
	if vertical != 0 and at_end:
		player.position.y = clampf(player.position.y + vertical * SPEED * 0.7 * delta, BACK_LANE, FRONT_LANE)
	elif between:
		var goal := BACK_LANE if player.position.y < 900 else FRONT_LANE
		player.position.y = move_toward(player.position.y, goal, SPEED * delta)
	elif horizontal != 0:
		player.position.x = clampf(player.position.x + horizontal * SPEED * delta, 190, WALK_RIGHT_LIMIT)
	if vertical != 0 and not at_end and (Input.is_action_just_pressed("lane_up") or Input.is_action_just_pressed("lane_down")):
		show_toast("桌椅挡着路。到教室左端或右端换一排。")
	apply_motion(old)

func apply_motion(old: Vector2) -> void:
	var motion: Vector2 = player.position - old
	player.moving = motion.length() > 0.01
	travel_distance += motion.length()
	if absf(motion.x) > 0.01:
		player.facing = signf(motion.x)

func build_route(destination: Vector2) -> Array[Vector2]:
	var route: Array[Vector2] = []
	destination.x = clampf(destination.x, 200, WALK_RIGHT_LIMIT)
	destination.y = BACK_LANE if destination.y < 900 else FRONT_LANE
	var lane := BACK_LANE if player.position.y < 900 else FRONT_LANE
	if absf(player.position.y - lane) > 1:
		route.append(Vector2(player.position.x, lane))
	if absf(lane - destination.y) > 1:
		var left_cost: float = absf(player.position.x - LEFT_END) + absf(destination.x - LEFT_END)
		var right_cost: float = absf(player.position.x - RIGHT_END) + absf(destination.x - RIGHT_END)
		var end := LEFT_END if left_cost < right_cost else RIGHT_END
		route.append(Vector2(end, lane))
		route.append(Vector2(end, destination.y))
	route.append(destination)
	return route

func move_route(delta: float) -> void:
	var old: Vector2 = player.position
	player.position = player.position.move_toward(waypoints[0], SPEED * delta)
	if player.position.distance_to(waypoints[0]) < 0.2:
		waypoints.pop_front()
		if waypoints.is_empty() and pending_interaction > 0:
			update_nearby()
			if nearby == pending_interaction:
				begin_talk(pending_interaction)
			pending_interaction = 0
	apply_motion(old)

func update_nearby() -> void:
	nearby = 0
	var best := 158.0
	for i in range(1, 4):
		var actor = actors[i]
		if actor.leaving or actor.departed:
			continue
		if absf(actor.position.y - player.position.y) > 28:
			continue
		var distance: float = absf(actor.position.x - player.position.x)
		if distance < best:
			best = distance
			nearby = i
	if clues.size() == 3 and not ending_complete and absf(player.position.x - SUN.x) < 115 and absf(player.position.y - BACK_LANE) < 25:
		nearby = 4

func update_camera(delta: float) -> void:
	var target_x: float = clampf(player.position.x + player.facing * 70.0, 720, WORLD_WIDTH - 720)
	if not dialogue.is_empty():
		var speaker = actors[int(dialogue[line_index][0])]
		target_x = clampf((player.position.x + speaker.position.x) * 0.5, 720, WORLD_WIDTH - 720)
	camera.position.x = lerpf(camera.position.x, target_x, 1.0 - exp(-delta * 4.0))
	camera.position.y = 540

func screen_point(world: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world

func update_lighting() -> void:
	var sun_screen := screen_point(SUN) / get_viewport_rect().size
	var alignment := exp(-pow((camera.position.x - SUN.x) / 720.0, 2))
	# World-space plaster/window bands modulate visibility as the actor crosses them.
	var aperture := 0.55 + 0.45 * smoothstep(-0.4, 0.65, sin((player.position.x - 480.0) / 142.0))
	flare_strength = (0.07 + alignment * 1.55) * aperture
	effect.set_shader_parameter("light_uv", sun_screen)
	effect.set_shader_parameter("strength", flare_strength)
	effect.set_shader_parameter("enabled", flare_enabled)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("notes"):
		notes_open = not notes_open
		return
	if event.is_action_pressed("cancel_talk"):
		if notes_open:
			notes_open = false
		elif not dialogue.is_empty():
			dialogue.clear()
			show_toast("话还没说完。再按 E，可以重新问起。")
		return
	if event.is_action_pressed("paths"):
		debug_paths = not debug_paths
	if event.is_action_pressed("glare"):
		flare_enabled = not flare_enabled
		show_toast("眩光：开" if flare_enabled else "眩光：关")
	if event.is_action_pressed("mute"):
		muted = not muted
		show_toast("声音：关" if muted else "声音：开")
	if notes_open:
		return
	if event.is_action_pressed("talk"):
		if not dialogue.is_empty():
			advance_talk()
		elif nearby > 0:
			begin_talk(nearby)
		else:
			show_toast("走近头顶有菱形提示的同学，再按 E。")
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not dialogue.is_empty():
			advance_talk()
			return
		var world := get_global_mouse_position()
		pending_interaction = 0
		for i in range(1, 4):
			var actor = actors[i]
			if absf(world.x - actor.position.x) < 85 and world.y < actor.position.y + 20 and world.y > actor.position.y - actor.height - 90:
				world = actor.position + Vector2(-110 if player.position.x <= actor.position.x else 110, 0)
				pending_interaction = i
				break
		if world.y > 710 or pending_interaction > 0:
			waypoints = build_route(world)

func begin_talk(index: int) -> void:
	if index<4 and (actors[index].leaving or actors[index].departed):
		return
	waypoints.clear()
	player.moving = false
	current_npc = index
	if index == 4:
		dialogue = Story.ENDING.duplicate(true)
	elif aftermath_active and Story.AFTER_BROADCAST.has(index):
		dialogue = Story.AFTER_BROADCAST[index].duplicate(true)
	elif clues.has(index):
		dialogue = Story.REPEATS[index].duplicate(true)
	else:
		dialogue = Story.TALKS[index].duplicate(true)
	line_index = 0
	revealed = 0
	if index < 4:
		player.facing = signf(actors[index].position.x - player.position.x)
		actors[index].facing = -player.facing

func advance_talk() -> void:
	if dialogue.is_empty():
		return
	if int(revealed) < str(dialogue[line_index][1]).length():
		revealed = str(dialogue[line_index][1]).length()
		return
	line_index += 1
	if line_index >= dialogue.size():
		dialogue.clear()
		if current_npc == 4:
			ending_complete = true
			show_toast("—— 声音终于到了。未完 ——", 10)
			if not muted:
				bell.play()
			on_ending_finished()
		elif not clues.has(current_npc):
			clues.append(current_npc)
			show_toast("拾起旧事：" + Story.CLUES[current_npc])
			if clues.size() == 3:
				show_toast("三件旧事，指向同一扇窗。去夕阳下看看。", 9)
	else:
		revealed = 0

func show_toast(message: String, seconds: float = 4.0) -> void:
	toast = message
	toast_timer = seconds

func on_ending_finished() -> void:
	pass

func _draw() -> void:
	# Sparse world-anchored motes; their parallax comes from the camera transform.
	for i in range(72):
		var x := fmod(i * 137.7 + sin(elapsed * 0.11 + i) * 18, 2960.0) + 160.0
		var y := 290 + fmod(i * 71.3 + elapsed * (1.0 + (i % 3)), 470.0)
		var warmth := 0.5 + sin(x / 150.0) * 0.5
		draw_circle(Vector2(x, y), 0.8 + (i % 3) * 0.3, Color(1.0, 0.75, 0.37, 0.08 + warmth * 0.15))
	if debug_paths:
		for y in [BACK_LANE, FRONT_LANE]:
			draw_line(Vector2(190, y), Vector2(3090, y), Color(0.9, 0.72, 0.3, 0.7), 2)
		for x in [LEFT_END, RIGHT_END]:
			draw_line(Vector2(x, BACK_LANE), Vector2(x, FRONT_LANE), Color(0.9, 0.72, 0.3, 0.7), 3)

func setup_audio() -> void:
	footsteps = AudioStreamPlayer.new()
	footsteps.stream = make_sound(false)
	footsteps.volume_db = -22
	add_child(footsteps)
	bell = AudioStreamPlayer.new()
	bell.stream = make_sound(true)
	bell.volume_db = -18
	add_child(bell)

func make_sound(is_bell: bool) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var duration := 3.7 if is_bell else 0.11
	var count := int(22050 * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 72
	var filtered := 0.0
	for i in range(count):
		var t := float(i) / 22050
		var value: float
		if is_bell:
			value = (sin(TAU * 440 * t) * 0.4 + sin(TAU * 691 * t) * 0.23 + sin(TAU * 1097 * t) * 0.12) * exp(-t * 1.6) * minf(t * 160, 1)
		else:
			filtered = filtered * 0.7 + rng.randf_range(-1, 1) * 0.3
			value = filtered * exp(-t * 45) * 0.8
		data.encode_s16(i * 2, int(clampf(value, -1, 1) * 32760))
	wav.data = data
	return wav

func run_tests() -> void:
	var runner = load("res://tests/smoke.gd").new()
	add_child(runner)
	await runner.run(self)

func capture_views() -> void:
	await get_tree().create_timer(1.0).timeout
	player.position = Vector2(915, BACK_LANE)
	camera.position.x = 850
	begin_talk(1)
	revealed = 99
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/screenshot-dialogue.png")
	dialogue.clear()
	player.position = Vector2(2470, BACK_LANE)
	camera.position.x = 2500
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/screenshot-sunset.png")
	flare_enabled = false
	await get_tree().create_timer(0.15).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/screenshot-sunset-no-glare.png")
	flare_enabled = true
	player.position = Vector2(1720, FRONT_LANE)
	camera.position.x = 1770
	begin_talk(3)
	revealed = 99
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/screenshot-front-lane.png")
	print("CAPTURES_SAVED")
	get_tree().quit()
