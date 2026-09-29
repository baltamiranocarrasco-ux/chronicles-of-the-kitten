extends Node
## Flujo del juego (autoload "Game"): cambiar entre el menú y los niveles.
## ESC en un nivel vuelve al menú de inicio. F3 muestra los FPS.

const MENU := "res://scenes/main_menu.tscn"
const LEVELS := ["res://scenes/test_level.tscn"] ## en orden; el selector de niveles vendrá después


var _fps_label: Label


func _ready() -> void:
	# ESC tiene que funcionar también con el tiempo detenido (R pausa el árbol)
	process_mode = PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fps_label = Label.new()
	_fps_label.position = Vector2(4, 2)
	_fps_label.add_theme_font_size_override("font_size", 8)
	_fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_fps_label.add_theme_constant_override("outline_size", 2)
	_fps_label.visible = false
	layer.add_child(_fps_label)


func _process(_delta: float) -> void:
	if _fps_label.visible:
		_fps_label.text = "%d FPS" % Engine.get_frames_per_second()


func start_level(index := 0) -> void:
	change_scene(LEVELS[index])


func go_to_menu() -> void:
	change_scene(MENU)


func change_scene(path: String) -> void:
	# Deja el mundo como estaba: sin pausa, sin cámara lenta, cursor normal
	get_tree().paused = false
	Engine.time_scale = 1.0
	Input.set_custom_mouse_cursor(null)
	get_tree().change_scene_to_file(path)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		_fps_label.visible = not _fps_label.visible
		return
	var scene := get_tree().current_scene
	if event.is_action_pressed("ui_cancel") and scene and scene.scene_file_path != MENU:
		get_viewport().set_input_as_handled()
		go_to_menu()
