class_name TimePowers
extends Node
## Habilidades de tiempo del jugador y su barra de energía.
##   Q (Sandevistan): el mundo va a SLOW_TIME_SCALE y el gato a velocidad normal.
##   R (detener el tiempo): pausa el árbol de escena; solo el gato sigue.
## Ambas gastan energía. Si se agota, la habilidad se corta y hay un
## enfriamiento (sobrecalentamiento) antes de empezar a recargar.

signal mode_changed(mode: Mode)
signal activation_denied

enum Mode { NONE, SLOW, STOP }

const SLOW_TIME_SCALE := 0.3
const MAX_ENERGY := 100.0
const DRAIN_SLOW := 20.0 ## por segundo real (~5 s de uso seguido)
const DRAIN_STOP := 35.0 ## por segundo real (~3 s de uso seguido)
const MIN_TO_ACTIVATE := 15.0 ## energía mínima para activar una habilidad
const REGEN := 18.0 ## por segundo real
const REGEN_DELAY := 0.6 ## espera tras soltar una habilidad antes de recargar
const OVERHEAT_COOLDOWN := 3.0 ## enfriamiento al agotar la energía

@export var fx_path: NodePath = ^"../TimeFX"

var mode := Mode.NONE
var energy := MAX_ENERGY
var cooldown := 0.0 ## > 0 mientras se enfría tras agotar la energía

var _regen_wait := 0.0

@onready var _fx = get_node(fx_path)


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	# Con la cámara lenta el delta viene escalado; la energía se mide en tiempo real
	var real_delta := delta / Engine.time_scale
	if Input.is_action_just_pressed("stop_time"):
		_toggle(Mode.STOP)
	elif Input.is_action_just_pressed("slow_time"):
		_toggle(Mode.SLOW)
	_update_energy(real_delta)


func can_activate() -> bool:
	if cooldown > 0.0:
		return false
	# Cambiar de una habilidad a otra no exige el mínimo, solo tener energía
	return energy > 0.0 if mode != Mode.NONE else energy >= MIN_TO_ACTIVATE


func set_mode(new_mode: Mode) -> void:
	if new_mode == mode:
		return
	mode = new_mode
	get_tree().paused = mode == Mode.STOP
	Engine.time_scale = SLOW_TIME_SCALE if mode == Mode.SLOW else 1.0
	if mode == Mode.NONE:
		_regen_wait = REGEN_DELAY
	_fx.set_mode(mode)
	mode_changed.emit(mode)


func _toggle(target: Mode) -> void:
	if mode == target:
		set_mode(Mode.NONE)
	elif can_activate():
		set_mode(target)
	else:
		activation_denied.emit()


func _update_energy(real_delta: float) -> void:
	match mode:
		Mode.SLOW:
			energy -= DRAIN_SLOW * real_delta
		Mode.STOP:
			energy -= DRAIN_STOP * real_delta
		_:
			if cooldown > 0.0:
				cooldown = maxf(cooldown - real_delta, 0.0)
			elif _regen_wait > 0.0:
				_regen_wait -= real_delta
			else:
				energy = minf(energy + REGEN * real_delta, MAX_ENERGY)
	if mode != Mode.NONE and energy <= 0.0:
		energy = 0.0
		set_mode(Mode.NONE)
		cooldown = OVERHEAT_COOLDOWN
