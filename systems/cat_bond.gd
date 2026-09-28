extends Node
## Confianza del gato en el jugador (autoload "CatBond"), de 0 a 100.
## El gato fue un experimento descartado: empieza desconfiando de todos y
## aprende a confiar de a poco. Se guarda en user://cat_bond.cfg, así que
## la relación continúa entre partidas.
##
## Sube despacio (con un tope por sesión, para que tome varias partidas) y
## baja más rápido de lo que sube. No se muestra con una barra: se nota en
## cómo reacciona el gato (effects/bond_controller.gd).

signal trust_changed(value: float)

const SAVE_PATH := "user://cat_bond.cfg"
const MAX_TRUST := 100.0
const SESSION_GAIN_CAP := 15.0 ## lo máximo que puede subir en una sesión de juego

## Niveles de la relación
const WARY := 20.0 ## por debajo: hostil (bufa y araña)
const TOLERANT := 50.0 ## por debajo: desconfiado (retrocede)
const BONDED := 80.0 ## desde aquí: apegado (se acerca, cabezazos, panza arriba)
const ADOPTED := 90.0 ## el holograma de retiro pasa de DESCARTADO a ADOPTADO

var trust := 0.0
var session_gain := 0.0

var _dirty := false
var _save_wait := 0.0


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		trust = clampf(float(cfg.get_value("bond", "trust", 0.0)), 0.0, MAX_TRUST)


## Cambia la confianza. Las subidas se recortan al tope de la sesión.
func change(amount: float) -> void:
	if amount > 0.0:
		amount = minf(amount, SESSION_GAIN_CAP - session_gain)
		if amount <= 0.0:
			return
		session_gain += amount
	var before := trust
	trust = clampf(trust + amount, 0.0, MAX_TRUST)
	if trust != before:
		_dirty = true
		trust_changed.emit(trust)


func is_hostile() -> bool:
	return trust < WARY


func is_wary() -> bool:
	return trust >= WARY and trust < TOLERANT


func is_bonded() -> bool:
	return trust >= BONDED


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("bond", "trust", trust)
	cfg.save(SAVE_PATH)
	_dirty = false


func _process(delta: float) -> void:
	# Guarda como mucho cada 2 s mientras cambia (y siempre al cerrar)
	if _dirty:
		_save_wait -= delta
		if _save_wait <= 0.0:
			_save_wait = 2.0
			save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if _dirty:
			save()
