extends CanvasLayer
## HUD del nivel (hijo del jugador): barra de vida arriba a la izquierda y
## mensajes en el centro (pistas, secretos, nivel completado).
## La energía de las habilidades se sigue viendo en el lomo del gato
## (effects/spine_meter.gd).

const HOLO := preload("res://effects/hologram_ads.gd")
const VIEW := Vector2(384, 216)
const SEGMENTS := 10
const BAR_POS := Vector2(30, 9) ## esquina del primer segmento
const SEG := Vector2(6.5, 4.0)
const GAP := 1.5
const OK := Color(0.4, 1.0, 0.75)
const LOW := Color(1.0, 0.75, 0.3)
const CRIT := Color(1.0, 0.3, 0.35)
const TRAIL := Color(1.0, 0.95, 0.9)
const TOAST_COLOR := Color(0.4, 0.95, 1.0)

var _shown := 1.0 ## fracción de vida dibujada
var _trail := 1.0 ## rastro del daño reciente, baja más lento
var _hit := 0.0
var _toast := ""
var _toast_sub := ""
var _toast_left := 0.0
var _toast_total := 1.0
var _toast_color := TOAST_COLOR
var _t := 0.0
var _canvas := Node2D.new()


func _ready() -> void:
	layer = 10
	process_mode = PROCESS_MODE_ALWAYS
	add_child(_canvas)
	_canvas.draw.connect(_on_draw)
	var player := get_parent()
	player.health_changed.connect(_on_health)
	player.hurt_taken.connect(func(_kind, _amount): _hit = 1.0)


## Mensaje en el centro de la pantalla. sub: segunda línea más chica.
func toast(text: String, seconds := 2.6, color := TOAST_COLOR, sub := "") -> void:
	_toast = text.to_upper()
	_toast_sub = sub.to_upper()
	_toast_left = seconds
	_toast_total = seconds
	_toast_color = color


func _on_health(value: float, max_value: float) -> void:
	var f := value / max_value
	if f > _shown:
		_trail = f # curarse no deja rastro
	_shown = f


func _process(delta: float) -> void:
	var real := delta / Engine.time_scale
	_t += real
	_trail = move_toward(_trail, _shown, real * 0.5) if _trail > _shown else _shown
	_hit = maxf(_hit - real * 3.0, 0.0)
	_toast_left = maxf(_toast_left - real, 0.0)
	_canvas.queue_redraw()


func _on_draw() -> void:
	_draw_health()
	if _toast_left > 0.0:
		_draw_toast()


func _draw_health() -> void:
	var c := OK if _shown > 0.5 else (LOW if _shown > 0.25 else CRIT)
	var pulse := 1.0
	if _shown <= 0.25:
		pulse = 0.6 + 0.4 * absf(sin(_t * 6.0))
	var width := SEGMENTS * (SEG.x + GAP) - GAP
	# Placa de fondo inclinada, con borde de neón
	var plate := PackedVector2Array([Vector2(4, 4), Vector2(BAR_POS.x + width + 9, 4),
			Vector2(BAR_POS.x + width + 5, 18), Vector2(4, 18)])
	_canvas.draw_colored_polygon(plate, Color(0.03, 0.03, 0.08, 0.6))
	plate.append(plate[0])
	_canvas.draw_polyline(plate, Color(c, 0.35 + 0.4 * _hit), 0.6, true)
	text(_canvas, "VIDA", Vector2(7, 8.5), 0.85, Color(c, pulse), false)
	for i in SEGMENTS:
		var x := BAR_POS.x + i * (SEG.x + GAP)
		var r := Rect2(Vector2(x, BAR_POS.y), SEG)
		var lo := float(i) / SEGMENTS
		var fill := clampf((_shown - lo) * SEGMENTS, 0.0, 1.0)
		var trail := clampf((_trail - lo) * SEGMENTS, 0.0, 1.0)
		_canvas.draw_rect(r, Color(c, 0.12))
		if trail > fill:
			_canvas.draw_rect(Rect2(r.position, Vector2(SEG.x * trail, SEG.y)), Color(TRAIL, 0.75))
		if fill > 0.0:
			_canvas.draw_rect(Rect2(r.position, Vector2(SEG.x * fill, SEG.y)), Color(c, 0.9 * pulse))
			_canvas.draw_rect(Rect2(r.position, Vector2(SEG.x * fill, 1.0)), Color(c.lightened(0.5), pulse))
	# Destello al recibir daño
	if _hit > 0.0:
		_canvas.draw_rect(Rect2(Vector2(0, 0), VIEW), Color(CRIT, 0.12 * _hit))


func _draw_toast() -> void:
	var a := clampf(minf(_toast_left / 0.4, (_toast_total - _toast_left) / 0.15), 0.0, 1.0)
	var y := 62.0
	var w := maxf(_toast.length() * 5.2 * 1.3, _toast_sub.length() * 5.2 * 0.75) + 20.0
	var band := Rect2(Vector2((VIEW.x - w) / 2.0, y - 8), Vector2(w, 26 if _toast_sub == "" else 34))
	_canvas.draw_rect(band, Color(0.02, 0.02, 0.06, 0.65 * a))
	_canvas.draw_line(band.position, band.position + Vector2(w, 0), Color(_toast_color, 0.6 * a), 0.6, true)
	_canvas.draw_line(band.end - Vector2(w, 0), band.end, Color(_toast_color, 0.6 * a), 0.6, true)
	text(_canvas, _toast, Vector2(VIEW.x / 2.0, y), 1.3, Color(_toast_color, a), true)
	if _toast_sub != "":
		text(_canvas, _toast_sub, Vector2(VIEW.x / 2.0, y + 14), 0.75, Color(Color.WHITE, 0.85 * a), true)


## Texto con la tipografía vectorial de los hologramas.
static func text(ci: CanvasItem, s: String, pos: Vector2, size: float, color: Color, centered: bool) -> void:
	var lines := PackedVector2Array()
	var x := pos.x - (s.length() * 5.2 * size - 1.2 * size) / 2.0 if centered else pos.x
	for ch in s:
		for stroke in HOLO.FONT.get(ch, []):
			for i in range(0, stroke.size() - 2, 2):
				lines.append(Vector2(x + stroke[i] * size, pos.y + stroke[i + 1] * size))
				lines.append(Vector2(x + stroke[i + 2] * size, pos.y + stroke[i + 3] * size))
		x += 5.2 * size
	if lines.is_empty():
		return
	ci.draw_multiline(lines, Color(color, color.a * 0.25), size * 1.4, true)
	ci.draw_multiline(lines, color, maxf(size * 0.35, 0.4), true)
