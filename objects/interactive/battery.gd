@tool
extends Area2D
## Batería corporativa caída: al tocarla, el gato absorbe su carga
## (CHARGE de energía para las habilidades). Se usa una sola vez.

const CHARGE := 45.0
const GLOW := Color(0.4, 1.0, 0.6)

var _t := 0.0
var _taken := false


func _ready() -> void:
	collision_layer = 16
	collision_mask = 0
	monitoring = false
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(12, 14)
	cs.shape = r
	cs.position = Vector2(0, -5)
	add_child(cs)


func touch(player: Node2D, _real_delta: float) -> void:
	if _taken:
		return
	_taken = true
	player.time_powers.recharge(CHARGE)
	var fx := Node2D.new()
	fx.set_script(preload("res://objects/interactive/pickup_flash.gd"))
	get_parent().add_child(fx)
	fx.global_position = global_position + Vector2(0, -4)
	fx.reset_physics_interpolation()
	queue_free()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	# Batería volcada en el suelo, con celdas de carga que laten
	var y := -0.5
	draw_rect(Rect2(-6, y - 5, 12, 5), Color(0.14, 0.15, 0.2))
	draw_rect(Rect2(-6, y - 5, 12, 0.8), Color(0.5, 0.55, 0.68))
	draw_rect(Rect2(6, y - 3.5, 1.2, 2), Color(0.5, 0.55, 0.68))
	for i in 3:
		var lit := 0.55 + 0.45 * sin(_t * 4.0 - i * 0.8)
		draw_rect(Rect2(-4.6 + i * 3.4, y - 3.6, 2.6, 2.4), Color(GLOW, lit))
	draw_circle(Vector2(0, y - 3), 9.0, Color(GLOW, 0.08 + 0.04 * sin(_t * 4.0)), true, -1.0, true)
	draw_line(Vector2(-6, y - 5), Vector2(-6, y), Color(0.95, 0.75, 0.2), 0.6)
