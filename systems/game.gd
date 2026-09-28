extends Node
## Flujo del juego (autoload "Game"): cambiar entre el menú y los niveles.
## ESC en un nivel vuelve al menú de inicio.

const MENU := "res://scenes/main_menu.tscn"
const LEVELS := ["res://scenes/test_level.tscn"] ## en orden; el selector de niveles vendrá después


func _ready() -> void:
	# ESC tiene que funcionar también con el tiempo detenido (R pausa el árbol)
	process_mode = PROCESS_MODE_ALWAYS


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
	var scene := get_tree().current_scene
	if event.is_action_pressed("ui_cancel") and scene and scene.scene_file_path != MENU:
		get_viewport().set_input_as_handled()
		go_to_menu()
