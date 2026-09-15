extends Node

var failures: Array[String] = []
var checks: int = 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func finish_conversation(game: Node) -> void:
	var guard := 0
	while not game.dialogue.is_empty() and guard < 50:
		game.revealed = 999
		game.advance_talk()
		guard += 1
	check(guard < 50, "dialogue terminates")

func run(game: Node) -> void:
	game.set_physics_process(false)
	game.muted = true
	check(game.actors.size() == 4, "one protagonist and three NPCs")
	check(game.WORLD_WIDTH > game.get_viewport_rect().size.x * 2, "classroom exceeds two screens")
	game.player.position = Vector2(1000, game.BACK_LANE)
	game.move_manual(0, 1, 0.3)
	check(game.player.position.y == game.BACK_LANE, "middle desks block lane crossing")
	game.player.position = Vector2(240, game.BACK_LANE)
	for i in range(20):
		game.move_manual(0, 1, 0.1)
	check(game.player.position.y == game.FRONT_LANE, "left end connects lanes")
	game.player.position = Vector2(game.RIGHT_END, game.FRONT_LANE)
	for i in range(20):
		game.move_manual(0, -1, 0.1)
	check(game.player.position.y == game.BACK_LANE, "right end connects lanes")
	game.move_manual(1,0,10.0)
	check(game.player.position.x<=game.WALK_RIGHT_LIMIT,"rightward walking stops before the raised teaching platform")
	check(game.build_route(Vector2(3200,game.FRONT_LANE)).back().x<=game.WALK_RIGHT_LIMIT,"click routing cannot enter the teaching platform")
	game.player.position = Vector2(480, game.BACK_LANE)
	game.waypoints = game.build_route(Vector2(1720, game.FRONT_LANE))
	check(game.waypoints.size() == 3 and game.waypoints[0].x == game.LEFT_END, "click path chooses shorter connected route")
	for i in range(2000):
		if game.waypoints.is_empty():
			break
		game.move_route(0.02)
		check(game.player.position.y == game.BACK_LANE or game.player.position.y == game.FRONT_LANE or game.player.position.x <= 340 or game.player.position.x >= game.RIGHT_TURN_START, "route never crosses desks")
	check(game.player.position.distance_to(Vector2(1720, game.FRONT_LANE)) < 1, "click path arrives")
	game.player.position = Vector2(game.actors[1].position.x - 100, game.FRONT_LANE)
	game.update_nearby()
	check(game.nearby == 0, "cannot talk through desk row")
	game.player.position.y = game.BACK_LANE
	game.update_nearby()
	check(game.nearby == 1, "nearby icon matches accessible NPC")
	game.begin_talk(1)
	game.advance_talk()
	check(game.line_index == 0 and game.revealed > 0, "first advance completes typewriter without skipping")
	game.dialogue.clear()
	check(game.clues.is_empty(), "interrupted conversation grants no clue")
	game.begin_talk(1)
	game.revealed = 999
	var logical_key := InputEventKey.new()
	logical_key.keycode = KEY_E
	logical_key.pressed = true
	game.get_viewport().push_input(logical_key)
	await get_tree().process_frame
	check(game.line_index == 1, "logical E key reaches live dialogue input")
	var logical_release: InputEventKey = logical_key.duplicate()
	logical_release.pressed = false
	game.get_viewport().push_input(logical_release)
	game.revealed = 999
	var physical_key := InputEventKey.new()
	physical_key.physical_keycode = KEY_SPACE
	physical_key.pressed = true
	game.get_viewport().push_input(physical_key)
	await get_tree().process_frame
	check(game.line_index == 2, "physical Space key reaches live dialogue input")
	var physical_release: InputEventKey = physical_key.duplicate()
	physical_release.pressed = false
	game.get_viewport().push_input(physical_release)
	game.dialogue.clear()
	for index in [3, 1, 2]:
		game.begin_talk(index)
		finish_conversation(game)
	check(game.clues.size() == 3, "all three conversations award independent clues")
	game.begin_talk(1)
	finish_conversation(game)
	check(game.clues.size() == 3, "repeat conversation cannot duplicate clue")
	game.player.position = Vector2(2450, game.BACK_LANE)
	game.update_nearby()
	check(game.nearby == 4, "three clues unlock window interaction")
	game.begin_talk(4)
	finish_conversation(game)
	check(game.ending_complete, "mystery ending completes")
	game.player.position.x = 250
	game.camera.position.x = 720
	game.update_lighting()
	var dim: float = game.flare_strength
	game.player.position.x = 2420
	game.camera.position.x = 2470
	game.update_lighting()
	check(game.flare_strength > dim * 3, "walking toward sun changes glare intensity")
	if game.get("stage")!=null:
		var stage=game.stage
		check(stage.camera.projection==Camera3D.PROJECTION_ORTHOGONAL,"orthographic 3D stage")
		check(stage.desks.size()==10 and stage.sun.shadow_enabled,"ten correctly oriented painted desk-chair units and sun shadows")
		var eye_y: float=5.8 if stage.get("painted_mode")==true else 3.412
		check(stage.sun_visibility(Vector3(24.2,eye_y,3.0))>0,"sun reaches open aperture")
		check(stage.sun_visibility(Vector3(22.0,eye_y,3.0))==0,"wall occludes sunlight")
		if stage.get("painted_mode")==true:
			check(stage.environment.environment.ambient_light_energy==0,"no uniform interior fill light")
			check(stage.shadow_materials.size()==10,"each painted tabletop receives character shadows")
			check(stage.get_node("CompletePainting").material_override.shading_mode==BaseMaterial3D.SHADING_MODE_UNSHADED,"finished painting retains its light")
		stage.sun.hide()
		game.update_lighting()
		check(game.flare_strength==0,"no flare with real sun off")
		stage.sun.show()
		var hero=stage.actors[0]
		check(hero.walk_count==27,"replacement video-derived 27-frame cycle loaded")
		game.player.moving=true
		for frame in range(hero.walk_count):
			hero.distance_phase=(frame+0.1)/float(hero.walk_count)
			hero.previous_position=Vector3(100,0,0)
			hero.update_from_state()
			var uv: Vector4=hero.paint.get_shader_parameter("uv_region")
			check(hero.active_frame==frame and uv.x+uv.z<=1.001 and uv.y+uv.w<=1.001,"atlas frame %d is valid"%frame)
		game.player.moving=false
		hero.update_from_state()
		check(hero.active_frame==-1,"standing restores idle texture")
		if stage.get("painted_mode")==true:
			game.player.facing=-1
			hero.update_from_state()
			check(hero.paint.get_shader_parameter("faces_sun")==false,"left-facing body has no window highlights")
			game.player.facing=1
			hero.update_from_state()
			check(hero.paint.get_shader_parameter("faces_sun")==true,"right-facing body receives window highlights")
			check(game.footsteps_from_animation,"old distance-driven sound disabled")
			check(hero.walk_contacts==[0,13],"heel contact frames match reviewed video")
			game.footfall_log.clear()
			game.player.position=Vector2(1500,game.BACK_LANE)
			game.player.moving=true
			hero.was_walking=false
			hero.update_from_state()
			for step in range(301):
				game.player.position.x+=2.3
				hero.update_from_state()
			check(game.footfall_log.size()==6,"three strides produce six footfalls")
			for event in game.footfall_log:
				check(int(floor(float(event.phase)*hero.walk_count))%hero.walk_count==int(event.frame),"footfall emitted on displayed landing frame")
			game.player.moving=false
			for stop_frame in range(20):
				hero.update_from_state()
			check(game.footfall_log.size()==6,"standing produces no footfall")
			var advances: Array[float]=[]
			for axis in [Vector2.RIGHT,Vector2.DOWN]:
				game.player.position=Vector2(240,game.BACK_LANE)
				game.player.moving=false
				hero.update_from_state()
				game.player.moving=true
				hero.update_from_state()
				var start_phase: float=hero.distance_phase
				for step in range(60):
					game.player.position+=axis*2.0
					hero.update_from_state()
				advances.append(hero.distance_phase-start_phase)
			check(absf(advances[0]-advances[1])<0.001,"equal logical distance gives equal gait cadence in both axes")
			check(advances[1]<0.6,"one lane crossing does not race through multiple steps")
			game.player.moving=true
			hero.update_from_state()
			game.player.moving=false
			hero.update_from_state()
			check(hero.stop_elapsed>=0.0 and hero.paint.get_shader_parameter("albedo_tex")==hero.stop_albedo,"release enters settling animation")
			check(hero.current_silhouette==hero.stop_shadow,"settling pose casts its matching silhouette")
			game.player.moving=true
			hero.update_from_state()
			check(hero.transition_starting and hero.was_walking,"walking input immediately reverses settling into startup")
			game.player.moving=false
			hero.update_from_state()
			hero.stop_elapsed=hero.STOP_DURATION
			hero.update_from_state()
			check(hero.paint.get_shader_parameter("albedo_tex")==hero.idle_albedo,"settling ends on exact original idle texture")
			hero.blink_wait=0.0
			hero.blink_elapsed=-1.0
			hero.update_blink(0.06)
			check(hero.paint.get_shader_parameter("blink_amount")==1.0,"blink fully closes eyelids")
			hero.update_blink(0.2)
			check(hero.paint.get_shader_parameter("blink_amount")==0.0 and hero.blink_wait>=3.5 and hero.blink_wait<=6.8,"blink reopens and schedules varied interval")
	for index in [1,2,3]:
		check(game.Story.TALKS[index][0][1].begins_with("毛主席教导我们"),"first encounter opens with quotation")
		check(game.Story.REPEATS[index][0][1].begins_with("毛主席教导我们"),"repeat encounter opens with quotation")
	check(game.Story.ENDING[0][1].begins_with("毛主席教导我们"),"ending opens with quotation")
	game.player.position.x = 9999
	game.update_camera(100)
	check(game.camera.position.x <= game.WORLD_WIDTH - 720, "camera stays within panorama")
	var result := {"checks": checks, "failures": failures, "success": failures.is_empty(), "engine": Engine.get_version_info().string}
	var file := FileAccess.open("res://docs/test-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("SMOKE_RESULT ", JSON.stringify(result))
	game.get_tree().quit(0 if failures.is_empty() else 1)
