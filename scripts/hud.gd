extends Control

const FONT = preload("res://assets/fonts/classroom.ttf")
const INK = Color("302b2b")
const PAPER = Color("f0d7a1")
const GOLD = Color("dba761")
var game: Node2D
var clock: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func text_at(p: Vector2, words: String, size_px: int = 24, color: Color = PAPER) -> void:
	draw_string_outline(FONT, p + Vector2(0, 2), words, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 5, Color(0.12, 0.09, 0.08, 0.65))
	draw_string_outline(FONT, p, words, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 3, INK)
	draw_string(FONT, p, words, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)

func paper_panel(rect: Rect2, opacity: float = 0.94) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.14, 0.13, opacity)
	style.border_color = Color(0.69, 0.51, 0.31, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.shadow_color = Color(0.06, 0.04, 0.04, 0.35)
	style.shadow_size = 12
	draw_style_box(style, rect)
	for i in range(7):
		var y := rect.position.y + 13 + i * (rect.size.y - 20) / 7
		draw_line(Vector2(rect.position.x + 9, y), Vector2(rect.end.x - 8, y + 1), Color(0.79, 0.66, 0.44, 0.025), 1)

func diamond(p: Vector2, active: bool, done: bool = false) -> void:
	var bob := sin(clock * 2.3 + p.x * 0.01) * 3.0
	p.y += bob
	var radius := 17.0 if active else 13.0
	var points := PackedVector2Array([p + Vector2(0, -radius), p + Vector2(radius, 0), p + Vector2(0, radius), p + Vector2(-radius, 0)])
	draw_colored_polygon(points, Color(0.22, 0.16, 0.13, 0.92))
	points.append(points[0])
	draw_polyline(points, PAPER if active else GOLD, 1.5, true)
	if done:
		draw_polyline(PackedVector2Array([p + Vector2(-5, 0), p + Vector2(-1, 4), p + Vector2(6, -5)]), GOLD, 2, true)
	else:
		for x in [-5, 0, 5]:
			draw_circle(p + Vector2(x, 0), 1.5, PAPER)
	if active:
		text_at(p + Vector2(25, 8), "E", 24)

func _draw() -> void:
	if game == null:
		return
	var screen_size := get_viewport_rect().size
	text_at(Vector2(38, 53), "未响的晚钟", 36)
	draw_line(Vector2(40, 68), Vector2(232, 68), Color(0.77, 0.57, 0.33, 0.65), 1)
	text_at(Vector2(40, 98), "一九七二 · 放学以后", 18, Color("c3b393"))
	var clue_text := "旧事  %d / 3   [Tab]" % game.clues.size()
	text_at(Vector2(screen_size.x - 265, 52), clue_text, 24)
	text_at(Vector2(screen_size.x - 265, 82), "靠窗通道" if game.player.position.y < 900 else "后排通道", 18, Color("c3b393"))
	for index in range(1, 4):
		var actor = game.actors[index]
		if actor.leaving or actor.departed or game.radio_phase in ["bell","broadcast"]:
			continue
		var pos: Vector2 = game.screen_point(actor.head_position()) - Vector2(0, 25)
		if pos.x < 20 or pos.x > screen_size.x - 20:
			continue
		if game.dialogue.is_empty():
			var active: bool = game.nearby == index
			diamond(pos, active, game.clues.has(index))
			if active:
				text_at(pos + Vector2(-32, -35), actor.display_name, 24)
	if game.clues.size() == 3 and not game.ending_complete and game.dialogue.is_empty():
		var p: Vector2 = game.screen_point(Vector2(2450, 450))
		if p.x > 30 and p.x < screen_size.x - 30:
			diamond(p, game.nearby == 4)
			text_at(p + Vector2(-48, -27), "窗中人", 24)
	if not game.dialogue.is_empty():
		draw_dialogue(screen_size)
	var footer := "A D / ← →  行走     W S / ↑ ↓  两端换排     E / 空格  交谈     Tab  旧事"
	if not game.dialogue.is_empty():
		footer = "E / 空格 / 点击  继续     Esc  暂停交谈"
	var fw := FONT.get_string_size(footer, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_rect(Rect2(0, screen_size.y - 48, screen_size.x, 48), Color(0.11, 0.10, 0.10, 0.77))
	text_at(Vector2((screen_size.x - fw) * 0.5, screen_size.y - 18), footer, 18, Color("cfc1a7"))
	if game.toast_timer > 0 and game.dialogue.is_empty():
		var tw := FONT.get_string_size(game.toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		text_at(Vector2((screen_size.x - tw) / 2, screen_size.y - 75), game.toast, 24)
	if game.notes_open:
		draw_notebook(screen_size)
	if not game.radio_caption.is_empty():
		var rw := FONT.get_string_size(game.radio_caption,HORIZONTAL_ALIGNMENT_LEFT,-1,24).x
		var rp := Vector2((screen_size.x-rw-56)/2,screen_size.y-159)
		paper_panel(Rect2(rp,Vector2(rw+56,88)),0.84)
		text_at(rp+Vector2(28,28),"操场广播",18,GOLD)
		text_at(rp+Vector2(28,64),game.radio_caption,24)
	if game.debug_paths:
		text_at(Vector2(40, 130), "F1 通道显示  /  G 眩光开关  /  M 静音", 18)
		text_at(Vector2(40, 158), "镜头 %.0f   光强 %.2f" % [game.camera.position.x, game.flare_strength], 18)

func draw_dialogue(screen_size: Vector2) -> void:
	var line: Array = game.dialogue[game.line_index]
	var actor = game.actors[int(line[0])]
	var anchor: Vector2 = game.screen_point(actor.head_position())
	var words: String = str(line[1])
	var lines := words.split("\n")
	var width := 280.0
	for s in lines:
		width = maxf(width, FONT.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 52)
	var height := 63.0 + lines.size() * 35
	var origin := Vector2(clampf(anchor.x - width * 0.5, 28, screen_size.x - width - 28), clampf(anchor.y - height - 45, 145, screen_size.y - height - 110))
	paper_panel(Rect2(origin, Vector2(width, height)), 0.90)
	var tail := clampf(anchor.x, origin.x + 22, origin.x + width - 22)
	draw_colored_polygon(PackedVector2Array([Vector2(tail - 8, origin.y + height), Vector2(tail + 8, origin.y + height), Vector2(tail, origin.y + height + 13)]), Color("9d784e"))
	draw_rect(Rect2(origin + Vector2(16, -14), Vector2(105, 29)), Color("703c31"))
	text_at(origin + Vector2(25, 8), actor.display_name, 24)
	var displayed := words.substr(0, int(game.revealed))
	var visible_lines := displayed.split("\n")
	for i in visible_lines.size():
		text_at(origin + Vector2(25, 48 + i * 35), visible_lines[i], 24)
	if int(game.revealed) >= words.length():
		var alpha := 0.65 + sin(clock * 3) * 0.25
		text_at(origin + Vector2(width - 89, height - 13), "续  ›", 18, Color(0.85, 0.68, 0.41, alpha))
	text_at(origin + Vector2(22, height - 13), "%02d / %02d" % [game.line_index + 1, game.dialogue.size()], 12, Color("ab9676"))

func draw_notebook(screen_size: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, screen_size), Color(0.07, 0.06, 0.07, 0.65))
	var p := (screen_size - Vector2(710, 470)) * 0.5
	paper_panel(Rect2(p, Vector2(710, 470)), 0.99)
	text_at(p + Vector2(42, 59), "夹在课本里的旧事", 36)
	text_at(p + Vector2(43, 104), "许知秋的随记", 24, GOLD)
	var descriptions := ["点名簿上，有两个许知秋。", "铃声在路上，太阳却没有动。", "借书条上的日期，比今天晚一天。"]
	for i in range(1, 4):
		var y := 158 + (i - 1) * 79
		text_at(p + Vector2(44, y), "%02d   %s" % [i, game.Story.CLUES[i] if game.clues.has(i) else "尚未拾起"], 24, GOLD)
		text_at(p + Vector2(95, y + 32), descriptions[i - 1] if game.clues.has(i) else "再和留在教室的人说说话。", 24)
	var goal := "去靠窗通道的夕阳下，看看玻璃。" if game.clues.size() == 3 else "沈禾、周槐生、唐小满，都还没有回家。"
	if game.ending_complete:
		goal = "声音终于到了。是谁替我答应了那一声？"
	text_at(p + Vector2(43, 414), goal, 24)
	text_at(p + Vector2(43, 451), "Tab / Esc  合上课本", 18, Color("ab9676"))
