extends SceneTree
var game: Node
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 game=load("res://scenes/classroom_painted.tscn").instantiate()
 root.add_child(game)
 game.player.position=Vector2(2030,game.BACK_LANE)
 game.review_camera_x=2140
 game.toast_timer=0
 await create_timer(0.5).timeout
 game.clues.assign([1,2,3])
 game.begin_talk(4)
 while not game.dialogue.is_empty():
  game.revealed=9999
  game.advance_talk()
 await create_timer(6.0).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://docs/broadcast/announcement.png")
 await create_timer(37.0).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://docs/broadcast/departure.png")
 while not game.actors[2].departed:
  game.review_camera_x=maxf(650,game.actors[2].position.x-40)
  await process_frame
 await create_timer(0.5).timeout
 game.player.position=Vector2(1370,game.BACK_LANE)
 game.review_camera_x=1490
 game.begin_talk(3)
 game.line_index=1
 game.revealed=999
 await create_timer(2.0).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://docs/broadcast/changed-dialogue.png")
 quit()
