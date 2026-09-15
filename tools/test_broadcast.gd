extends SceneTree
var game: Node
var checks:=0
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:
  push_error(message)
  quit(1)
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 game=load("res://scenes/classroom_painted.tscn").instantiate()
 root.add_child(game)
 game.set_process(false)
 game.muted=true
 game.clues.assign([1,2,3])
 game.begin_talk(4)
 while not game.dialogue.is_empty():
  game.revealed=9999
  game.advance_talk()
 check(game.radio_phase=="bell","ending must trigger bell wait")
 game.update_broadcast(2.0)
 check(game.radio_phase=="bell","broadcast must not overlap bell")
 game.on_ending_finished()
 check(game.radio_clock==2.0,"ending must trigger only once")
 game.update_broadcast(2.0)
 check(game.radio_phase=="broadcast","broadcast starts even when muted")
 game.update_broadcast(1.0)
 check(not game.radio_caption.is_empty(),"caption audible timing")
 game.begin_talk(1)
 check(game.dialogue.is_empty(),"broadcast must retain dialogue priority")
 game.update_broadcast(40.0)
 check(game.aftermath_active and game.actors[2].leaving,"aftermath starts after broadcast")
 check(game.stage.actors[2].walk_count==26,"NPC has independent walk cycle")
 game.begin_talk(2)
 check(game.dialogue.is_empty(),"departing NPC cannot talk")
 for i in 1100:
  game.update_broadcast(1.0/60.0)
  check(game.actors[2].position.y==game.BACK_LANE,"departure stays on back aisle")
 game.stage.actors[2].update_from_state()
 check(game.actors[2].departed and not game.stage.actors[2].visible,"NPC exits and hides")
 game.player.position=game.actors[2].position
 game.update_nearby()
 check(game.nearby!=2,"departed NPC interaction removed")
 for index in [1,3]:
  game.begin_talk(index)
  check(game.dialogue==game.Story.AFTER_BROADCAST[index],"remaining NPC changes dialogue")
  game.dialogue.clear()
 check(game.radio_phase=="aftermath" and game.radio_caption.is_empty(),"broadcast cleans up")
 print("BROADCAST_CHECKS_PASSED ",checks)
 game.queue_free()
 await process_frame
 await process_frame
 quit()
