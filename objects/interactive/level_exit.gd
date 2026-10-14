@tool
extends Area2D
## Meta del nivel: una antena de transmisión en la azotea más alta. Al
## llegar muestra NIVEL COMPLETADO y vuelve al menú.

const COLOR := Color(0.4, 1.0, 0.75)

var _t := 0.0
var _done := false


func _ready() -> void:
	collision_layer = 16
	collision_mask = 0
	monitoring = false
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(20, 48)
	cs.shape = r
	cs.position = Vector2(0, -24)
	add_child(cs)
	if not Engine.is_editor_hint():
		process_mode = PROCESS_MODE_ALWAYS


func touch(player: Node2D, _real_delta: float) -> void:
	if _done:
		return
	_done = true
	player.hud.toast("NIVEL COMPLETADO", 4.0, COLOR, "SUJETO K-7 SIGUE LIBRE")
	get_tree().create_timer(3.6, true, false, true).timeout.connect(func(): Game.go_to_menu())


func _process(delta: float) -> void:
	_t += delta / maxf(Engine.time_scale, 0.01)
	queue_redraw()


func _draw() -> void:
	# Mástil con antena y ondas de transmisión
	draw_rect(Rect2(-6, -3, 12, 3), Color(0.14, 0.15, 0.2))
	draw_line(Vector2(0, -3), Vector2(0, -44), Color(0.35, 0.38, 0.48), 1.4, true)
	for k in 5:
		var y := -10.0 - k * 7.0
		draw_line(Vector2(-3, y), Vector2(0, y - 3), Color(0.35, 0.38, 0.48), 0.5, true)
		draw_line(Vector2(3, y), Vector2(0, y - 3), Color(0.35, 0.38, 0.48), 0.5, true)
	var c := Color(COLOR, 1.0 if _done else 0.8)
	draw_circle(Vector2(0, -45), 2.0, c, true, -1.0, true)
	for k in 3:
		var r := fposmod(_t * 14.0 + k * 9.0, 27.0)
		draw_arc(Vector2(0, -45), r, -2.6, -0.54, 16, Color(COLOR, 0.7 * (1.0 - r / 27.0)), 0.7, true)
