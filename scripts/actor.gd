extends Node2D

const SHEET = preload("res://assets/art/students_key.png")
const WALK = preload("res://assets/art/hero_walk_key.png")
const KEY = preload("res://shaders/chroma.gdshader")
const REGIONS = [Rect2(45, 28, 335, 974), Rect2(455, 100, 275, 897), Rect2(815, 26, 324, 977), Rect2(1227, 125, 264, 872)]
const WALK_REGIONS = [Rect2(20, 30, 415, 910), Rect2(440, 30, 292, 910), Rect2(751, 30, 435, 910), Rect2(1200, 30, 282, 910)]
var character_index: int = 0
var display_name: String = "许知秋"
var facing: float = 1.0
var moving: bool = false
var leaving: bool = false
var departed: bool = false
var phase: float = 0.0
var sprite: Sprite2D
var height: float = 410.0
var key_material: ShaderMaterial
var idle_texture: AtlasTexture
var walk_textures: Array[AtlasTexture] = []

func _ready() -> void:
	phase = character_index * 1.7
	key_material = ShaderMaterial.new()
	key_material.shader = KEY
	idle_texture = AtlasTexture.new()
	idle_texture.atlas = SHEET
	idle_texture.region = REGIONS[character_index]
	for region in WALK_REGIONS:
		var atlas := AtlasTexture.new()
		atlas.atlas = WALK
		atlas.region = region
		walk_textures.append(atlas)
	sprite = Sprite2D.new()
	sprite.material = key_material
	add_child(sprite)
	_update_sprite()

func _process(delta: float) -> void:
	phase += delta * (7.5 if moving else 1.5)
	_update_sprite()
	queue_redraw()

func _update_sprite() -> void:
	var depth := clampf((position.y - 840.0) / 120.0, 0.0, 1.0)
	height = lerpf(395.0, 424.0, depth) * ([1.0, 0.94, 1.02, 0.92][character_index])
	sprite.texture = walk_textures[int(phase) % 4] if moving and character_index == 0 else idle_texture
	var rect_height := sprite.texture.get_height()
	var size_scale := height / float(rect_height)
	var breath := sin(phase) * 0.0018 if not moving else 0.0
	sprite.scale = Vector2(size_scale, size_scale * (1.0 + breath))
	# Shen He's atlas pose faces left; the other three face right.
	sprite.flip_h = facing > 0.0 if character_index == 1 else facing < 0.0
	sprite.position = Vector2(0, -height * 0.5 - (abs(sin(phase * PI)) * 1.4 if moving else 0.0))
	var window_light := 0.5 + 0.5 * sin((position.x - 480.0) / 140.0)
	key_material.set_shader_parameter("exposure", 0.77 + window_light * 0.15 + position.x / 3240.0 * 0.06)

func head_position() -> Vector2:
	return global_position - Vector2(0, height + 8)

func _draw() -> void:
	draw_set_transform(Vector2(0, -3), 0.0, Vector2(1, 0.22))
	draw_circle(Vector2.ZERO, 48.0, Color(0.09, 0.065, 0.06, 0.23))
	draw_circle(Vector2.ZERO, 32.0, Color(0.07, 0.05, 0.05, 0.18))
