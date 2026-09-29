class_name TimePowers
extends Node
## Habilidades de tiempo del jugador y su energía (se muestra en el lomo del
## gato, ver effects/spine_meter.gd).
##   Q (Sandevistan): el mundo va a SLOW_TIME_SCALE y el gato a velocidad normal.
##      Gasto continuo: se puede usar un instante y cortarlo.
##   R (Za Warudo): pausa el árbol de escena durante STOP_DURATION exactos.
##      Cuota fija que se descuenta de golpe al activarlo; no se puede cancelar.
## Si la energía llega a 0 hay una sobrecarga: sin habilidades durante
## OVERLOAD_TIME y el gato se mueve más lento.

signal mode_changed(mode: Mode)
signal activation_denied
signal stop_cost_paid(energy_before: float, energy_after: float)
signal overload_changed(overloaded: bool)

enum Mode { NONE, SLOW, STOP }

const SLOW_TIME_SCALE := 0.3
const MAX_ENERGY := 100.0
const DRAIN_SLOW := 20.0 ## por segundo real: ~1 s de uso = 20 % de la barra
const MIN_TO_SLOW := 15.0 ## energía mínima para activar el Sandevistan
const STOP_COST := 50.0 ## cuota fija del Za Warudo (y mínimo para activarlo)
const STOP_DURATION := 3.0 ## segundos exactos de tiempo detenido
const REGEN := 18.0 ## por segundo real
const REGEN_DELAY := 0.6 ## espera tras usar una habilidad antes de recargar
const OVERLOAD_TIME := 3.5 ## sin habilidades tras agotar la energía
const OVERLOAD_SPEED := 0.8 ## multiplicador de velocidad del gato durante la sobrecarga

@export var fx_path: NodePath = ^"../TimeFX"

var mode := Mode.NONE
var energy := MAX_ENERGY
var cooldown := 0.0 ## > 0 mientras dura la sobrecarga
var stop_left := 0.0 ## tiempo detenido restante

var _regen_wait := 0.0

@onready var _fx = get_node(fx_path)


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	# Con la cámara lenta el delta viene escalado; la energía se mide en tiempo real
	var real_delta := delta / Engine.time_scale
	if Input.is_action_just_pressed("stop_time"):
		_try_stop()
	elif Input.is_action_just_pressed("slow_time"):
		_toggle_slow()
	_update_energy(real_delta)


func is_overloaded() -> bool:
	return cooldown > 0.0


func can_slow() -> bool:
	return not is_overloaded() and mode == Mode.NONE and energy >= MIN_TO_SLOW


func can_stop() -> bool:
	return not is_overloaded() and mode != Mode.STOP and energy >= STOP_COST


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


func _toggle_slow() -> void:
	if mode == Mode.SLOW:
		set_mode(Mode.NONE)
	elif can_slow():
		set_mode(Mode.SLOW)
	else:
		activation_denied.emit()


func _try_stop() -> void:
	# Durante el Za Warudo no se puede cancelar ni cambiar a Sandevistan
	if not can_stop():
		if mode != Mode.STOP:
			activation_denied.emit()
		return
	var before := energy
	energy -= STOP_COST
	stop_left = STOP_DURATION
	set_mode(Mode.STOP)
	stop_cost_paid.emit(before, energy)


func _update_energy(real_delta: float) -> void:
	match mode:
		Mode.SLOW:
			energy -= DRAIN_SLOW * real_delta
			if energy <= 0.0:
				energy = 0.0
				set_mode(Mode.NONE)
				_start_overload()
		Mode.STOP:
			stop_left -= real_delta
			if stop_left <= 0.0:
				set_mode(Mode.NONE)
				if energy <= 0.0:
					_start_overload()
		_:
			if cooldown > 0.0:
				cooldown = maxf(cooldown - real_delta, 0.0)
				if cooldown == 0.0:
					_regen_wait = REGEN_DELAY
					overload_changed.emit(false)
			elif _regen_wait > 0.0:
				_regen_wait -= real_delta
			else:
				energy = minf(energy + REGEN * real_delta, MAX_ENERGY)


func _start_overload() -> void:
	cooldown = OVERLOAD_TIME
	overload_changed.emit(true)
