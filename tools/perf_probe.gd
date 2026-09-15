extends SceneTree

var game: Node
var samples: Array[float]=[]
var age:=0.0
var label:="baseline"
var previous_us:=0

func _initialize() -> void:
	call_deferred("start")

func start() -> void:
	game=load("res://scenes/classroom_painted.tscn").instantiate()
	root.add_child(game)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="): label=arg.trim_prefix("--label=")
		if arg=="--no-shadow": game.stage.sun.shadow_enabled=false
		if arg=="--no-desktop": game.stage.shadows_enabled=false
		if arg=="--no-msaa": root.msaa_3d=Viewport.MSAA_DISABLED
		if arg=="--paced":
			Engine.max_fps=60
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		if arg=="--cap-only": Engine.max_fps=60
		if arg=="--vsync-only": DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	if OS.get_cmdline_user_args().has("--broadcast"):
		game.on_ending_finished()
		game.update_broadcast(4.0)
	previous_us=Time.get_ticks_usec()
	process_frame.connect(sample)

func sample() -> void:
	var now:=Time.get_ticks_usec()
	var dt:=float(now-previous_us)/1000000.0
	previous_us=now
	age+=dt
	game.player.position=Vector2(1500+sin(age)*650,game.FRONT_LANE)
	game.player.moving=true
	if age>2.0: samples.append(dt*1000.0)
	if age<7.0: return
	samples.sort()
	var sum:=0.0
	for value in samples: sum+=value
	var report:={"label":label,"resolution":str(root.size),"frames":samples.size(),"mean_ms":sum/samples.size(),"p50_ms":samples[int(samples.size()*0.5)],"p95_ms":samples[int(samples.size()*0.95)],"p99_ms":samples[int(samples.size()*0.99)]}
	DirAccess.make_dir_recursive_absolute("res://docs/performance")
	FileAccess.open("res://docs/performance/"+label+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("PERF_RESULT ",JSON.stringify(report))
	process_frame.disconnect(sample)
	game.queue_free()
	await process_frame
	await process_frame
	quit()
