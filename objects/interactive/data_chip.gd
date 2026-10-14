@tool
extends Area2D
## Chip de memoria escondido en una zona secreta. Al tocarlo muestra un
## mensaje en pantalla.

@export var title := "SECRETO ENCONTRADO"
@export var subtitle := "CHIP DE MEMORIA K-7"

const COLOR := Color(1.0, 0.62, 0.78)

var _t := 0.0
var _taken := false


func _ready() -> void:
	collision_layer = 16
	collision_mask = 0
	monitoring = false
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 8.0
	cs.shape = c
	add_child(cs)


func touch(player: Node2D, _real_delta: float) -> void:
	if _taken:
		return
	_taken = true
	player.hud.toast(title, 3.0, COLOR, subtitle)
	var fx := Node2D.new()
	fx.set_script(preload("res://objects/interactive/pickup_flash.gd"))
	fx.color = COLOR
	get_parent().add_child(fx)
	fx.global_position = global_position
	fx.reset_physics_interpolation()
	queue_free()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var y := sin(_t * 2.5) * 2.0
	var spin := absf(cos(_t * 1.5))
	var w := 7.0 * maxf(spin, 0.15)
	draw_circle(Vector2(0, y), 10.0, Color(COLOR, 0.1), true, -1.0, true)
	draw_rect(Rect2(-w / 2.0, y - 5, w, 10), Color(0.1, 0.08, 0.14))
	draw_rect(Rect2(-w / 2.0, y - 5, w, 10), COLOR, false, 0.6)
	for i in 3:
		draw_line(Vector2(-w / 2.0 + 1, y - 2.5 + i * 2.5), Vector2(w / 2.0 - 1, y - 2.5 + i * 2.5),
				Color(COLOR, 0.6), 0.4)
