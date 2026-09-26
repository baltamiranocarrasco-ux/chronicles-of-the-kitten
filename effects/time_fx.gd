extends Node2D
## Efectos visuales de las habilidades de tiempo (los controla TimePowers):
##   SLOW (Sandevistan): tinte lima, scanlines y estela de neón del gato.
##   STOP (detener el tiempo): destello en negativo y tinte azulado; el fondo
##        de la ciudad pasa a escala de grises.
## También ajusta los materiales del fondo (estela con Q, grises con R).
## Corre con el árbol pausado y sus animaciones ignoran Engine.time_scale.

const TRAIL_COLORS: Array[Color] = [
	Color(1.0, 0.25, 0.85),
	Color(0.3, 0.95, 1.0),
	Color(1.0, 0.92, 0.25),
	Color(0.65, 0.45, 1.0),
]
const TRAIL_INTERVAL := 0.045
const TRAIL_LIFETIME := 0.45
const TRAIL_ALPHA := 0.7
const TRAIL_MIN_DISTANCE := 3.0
const PLAYER_Z := 1 # mismo z_index que el Sprite2D del jugador
const AFTERIMAGE_MATERIAL := preload("res://effects/afterimage_material.tres")
## Materiales compartidos por las capas del fondo y sus elementos animados
const BG_MATERIALS := [preload("res://effects/bg_material.tres"), preload("res://effects/bg_fx_material.tres")]

const STYLES := {
	TimePowers.Mode.SLOW: {
		tint = Color(0.62, 1.0, 0.42),
		desaturation = 0.6,
		scanlines = 1.0,
		trail = true,
	},
	TimePowers.Mode.STOP: {
		tint = Color(0.6, 0.78, 1.0),
		desaturation = 0.55, # suave: el fondo ya pasa a grises por su cuenta
		scanlines = 0.0,
		trail = false,
	},
}

@export var sprite_path: NodePath = ^"../Sprite2D"

var mode := TimePowers.Mode.NONE

@onready var sprite: Sprite2D = get_node(sprite_path)

var _rect: ColorRect
var _material: ShaderMaterial
var _tween: Tween
var _trail := false
var _trail_timer := 0.0
var _trail_index := 0
var _last_trail_pos := Vector2.INF


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	# El filtro se dibuja en el mundo (no en un CanvasLayer) para que el gato
	# y su estela (z_index = PLAYER_Z) queden encima y conserven sus colores.
	_rect = ColorRect.new()
	_rect.top_level = true
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = preload("res://effects/time_fx.gdshader")
	_rect.material = _material
	_rect.visible = false
	add_child(_rect)


func set_mode(new_mode: TimePowers.Mode) -> void:
	if new_mode == mode:
		return
	var was_active := mode != TimePowers.Mode.NONE
	mode = new_mode
	_last_trail_pos = Vector2.INF
	_update_center()
	_rect.visible = true
	if _tween:
		_tween.kill()
	_tween = _new_tween().set_parallel()

	_update_background(mode)

	if mode == TimePowers.Mode.NONE:
		_trail = false
		_material.set_shader_parameter("wave_radius", 1.2)
		_tween_param("wave_radius", 0.0, 0.3) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_tween_param("intensity", 0.0, 0.35)
		_tween.chain().tween_callback(_on_deactivated)
		return

	var style: Dictionary = STYLES[mode]
	_trail = style.trail
	_material.set_shader_parameter("tint", style.tint)
	_material.set_shader_parameter("desaturation", style.desaturation)
	_material.set_shader_parameter("scanlines", style.scanlines)
	_material.set_shader_parameter("wave_radius", 0.0)
	_tween_param("wave_radius", 2.2, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween_param("intensity", 1.0, 0.25)
	if mode == TimePowers.Mode.STOP:
		_material.set_shader_parameter("invert", 1.0)
		_tween_param("invert", 0.0, 0.25).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	else:
		_material.set_shader_parameter("flash", 0.8)
		_tween_param("flash", 0.0, 0.3)
	if not was_active:
		_camera_punch()


# Q: estela horizontal en el fondo. R: el fondo pasa a grises al instante.
func _update_background(new_mode: TimePowers.Mode) -> void:
	var bg_tween := _new_tween().set_parallel()
	for m in BG_MATERIALS:
		var smear_to := 1.0 if new_mode == TimePowers.Mode.SLOW else 0.0
		bg_tween.tween_method(func(v: float): m.set_shader_parameter("smear", v),
				m.get_shader_parameter("smear"), smear_to, 0.2)
		if new_mode == TimePowers.Mode.STOP:
			m.set_shader_parameter("freeze", 1.0)
		else:
			bg_tween.tween_method(func(v: float): m.set_shader_parameter("freeze", v),
					m.get_shader_parameter("freeze"), 0.0, 0.3)


func _new_tween() -> Tween:
	return create_tween().set_ignore_time_scale(true)


func _tween_param(param: String, to: float, duration: float) -> MethodTweener:
	var current = _material.get_shader_parameter(param)
	var from: float = current if current != null else 0.0
	return _tween.tween_method(func(v: float): _material.set_shader_parameter(param, v), from, to, duration)


func _on_deactivated() -> void:
	_material.set_shader_parameter("wave_radius", -1.0)
	_rect.visible = mode != TimePowers.Mode.NONE


func _process(delta: float) -> void:
	if _rect.visible:
		_update_center()
	if not _trail:
		return
	_trail_timer -= delta / Engine.time_scale
	if _trail_timer <= 0.0:
		_trail_timer = TRAIL_INTERVAL
		if sprite.global_position.distance_to(_last_trail_pos) >= TRAIL_MIN_DISTANCE:
			_spawn_afterimage()


func _update_center() -> void:
	var size := get_viewport_rect().size
	var to_world := get_viewport().get_canvas_transform().affine_inverse()
	_rect.global_position = to_world.origin
	_rect.size = size * to_world.get_scale()
	var screen_pos := sprite.get_global_transform_with_canvas().origin
	_material.set_shader_parameter("center", screen_pos / size)
	_material.set_shader_parameter("aspect", size.x / size.y)


func _spawn_afterimage() -> void:
	_last_trail_pos = sprite.global_position
	var ghost := Sprite2D.new()
	ghost.texture = sprite.texture
	ghost.hframes = sprite.hframes
	ghost.vframes = sprite.vframes
	ghost.frame = sprite.frame
	ghost.flip_h = sprite.flip_h
	ghost.centered = sprite.centered
	ghost.offset = sprite.offset
	ghost.scale = sprite.scale
	ghost.texture_filter = sprite.texture_filter
	ghost.material = AFTERIMAGE_MATERIAL
	var color := TRAIL_COLORS[_trail_index % TRAIL_COLORS.size()]
	color.a = TRAIL_ALPHA
	ghost.modulate = color
	ghost.z_index = PLAYER_Z
	ghost.process_mode = PROCESS_MODE_ALWAYS
	_trail_index += 1
	# Justo antes del jugador en el árbol: se dibuja detrás del gato
	owner.add_sibling(ghost)
	owner.get_parent().move_child(ghost, owner.get_index())
	ghost.global_position = sprite.global_position
	var fade := ghost.create_tween().set_ignore_time_scale(true)
	fade.tween_property(ghost, "modulate:a", 0.0, TRAIL_LIFETIME)
	fade.tween_callback(ghost.queue_free)


func _camera_punch() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var punch := _new_tween()
	punch.tween_property(cam, "zoom", Vector2(1.08, 1.08), 0.08)
	punch.tween_property(cam, "zoom", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
