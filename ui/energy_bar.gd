extends Control
## Barra de energía de las habilidades de tiempo, dibujada en pixel art.
##   Color según la habilidad activa: lima (Q), azul hielo (R), crema sin usar.
##   Naranja si no alcanza para activar; roja parpadeando durante el enfriamiento.
##   La marca vertical indica la energía mínima para activar.

const BAR_SIZE := Vector2(60, 5)
const OUTLINE := Color("2b1d14")
const BACKGROUND := Color("4a3a33")
const IDLE := Color("f3e3b5")
const SLOW := Color("9cff6b")
const STOP := Color("99c7ff")
const LOW := Color("f0a04b")
const OVERHEAT := Color("ff4a4a")
const OVERHEAT_DIM := Color("8a2020")
const DENIED_FLASH_TIME := 0.3

@export var powers_path: NodePath

var _denied_flash := 0.0

@onready var powers: TimePowers = get_node(powers_path)


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	custom_minimum_size = BAR_SIZE
	powers.activation_denied.connect(func(): _denied_flash = DENIED_FLASH_TIME)


func _process(delta: float) -> void:
	_denied_flash = maxf(_denied_flash - delta / Engine.time_scale, 0.0)
	queue_redraw()


func _draw() -> void:
	var outline := OVERHEAT if _denied_flash > 0.0 else OUTLINE
	draw_rect(Rect2(Vector2(-1, -1), BAR_SIZE + Vector2(2, 2)), outline)
	draw_rect(Rect2(Vector2.ZERO, BAR_SIZE), BACKGROUND)

	var ratio: float
	var color: Color
	if powers.cooldown > 0.0:
		ratio = 1.0 - powers.cooldown / TimePowers.OVERHEAT_COOLDOWN
		var blink := int(Time.get_ticks_msec() / 150) % 2 == 0
		color = OVERHEAT if blink else OVERHEAT_DIM
	else:
		ratio = powers.energy / TimePowers.MAX_ENERGY
		match powers.mode:
			TimePowers.Mode.SLOW:
				color = SLOW
			TimePowers.Mode.STOP:
				color = STOP
			_:
				color = LOW if powers.energy < TimePowers.MIN_TO_ACTIVATE else IDLE
	var width := floorf(BAR_SIZE.x * clampf(ratio, 0.0, 1.0))
	if width > 0.0:
		draw_rect(Rect2(Vector2.ZERO, Vector2(width, BAR_SIZE.y)), color)
		draw_rect(Rect2(Vector2.ZERO, Vector2(width, 1)), color.lightened(0.4))

	var mark_x := floorf(BAR_SIZE.x * TimePowers.MIN_TO_ACTIVATE / TimePowers.MAX_ENERGY)
	draw_rect(Rect2(Vector2(mark_x, 0), Vector2(1, BAR_SIZE.y)), OUTLINE)
