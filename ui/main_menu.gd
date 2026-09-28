extends Node2D
## Menú de inicio: la ciudad de fondo desplazándose sola (con hologramas,
## humo, ventanas y lluvia), el gato durmiendo en una azotea y el título con
## la tipografía de los hologramas. Por ahora: JUGAR y SALIR (el selector de
## niveles se agregará después; ver Game.LEVELS).

const HOLOGRAMS := preload("res://effects/hologram_ads.gd")
const CITY_LIFE := preload("res://effects/city_life.gd")
const TITLE := preload("res://ui/vector_title.gd")
const CAT_SHEET := preload("res://assets/cat/cat_sheet.png")
const BG_MATERIAL := preload("res://effects/bg_material.tres")
const BG_FX_MATERIAL := preload("res://effects/bg_fx_material.tres")
const BG_DETAIL := 3.0 ## el fondo tiene el triple de detalle (ver tools/generate_city.py)
const VIEW := Vector2(384, 216)

## [textura, velocidad de desplazamiento (px/s), elementos animados]
const LAYERS := [
	["res://assets/city/bg_0_sky.png", 0.0, []],
	["res://assets/city/bg_1_far.png", -2.0, []],
	["res://assets/city/bg_2_midfar.png", -4.0, [CITY_LIFE.Kind.LIGHTS]],
	["res://assets/city/bg_3_mid.png", -7.0, [&"holograms", CITY_LIFE.Kind.SMOKE]],
	["res://assets/city/bg_4_near.png", -11.0, [CITY_LIFE.Kind.RAIN]],
]
const LEDGE_Y := 186.0 ## azotea donde duerme el gato
const CAT_X := 322.0
const CYAN := Color(0.35, 0.92, 1.0)
const MAGENTA := Color(1.0, 0.3, 0.85)

var _cat: Sprite2D
var _cat_frames: Array[int] = []
var _cat_t := 0.0
var _play: Button


func _ready() -> void:
	var cam := Camera2D.new()
	cam.position = VIEW / 2.0
	add_child(cam)
	for l in LAYERS:
		_add_layer(l[0], l[1], l[2])
	_add_ledge_and_cat()
	_add_ui()
	_play.grab_focus()


func _process(delta: float) -> void:
	# El gato duerme (panza arriba si ya confía en ti)
	_cat_t += delta
	_cat.frame = _cat_frames[int(_cat_t / 0.33) % _cat_frames.size()]


# --- fondo --------------------------------------------------------------------

func _add_layer(path: String, speed: float, life: Array) -> void:
	var tex: Texture2D = load(path)
	var layer := Parallax2D.new()
	layer.repeat_size = Vector2(tex.get_width() / BG_DETAIL, 0)
	layer.repeat_times = 1
	layer.autoscroll = Vector2(speed, 0)
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(layer)
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	sprite.scale = Vector2.ONE / BG_DETAIL
	sprite.material = BG_MATERIAL
	layer.add_child(sprite)
	for kind in life:
		var node := Node2D.new()
		if kind is StringName:
			node.set_script(HOLOGRAMS)
		else:
			node.set_script(CITY_LIFE)
			node.set("kind", kind)
		node.set("layer_width", layer.repeat_size.x)
		node.material = BG_FX_MATERIAL
		layer.add_child(node)


func _add_ledge_and_cat() -> void:
	# Borde de una azotea mojada en primer plano
	var ledge := Polygon2D.new()
	ledge.polygon = PackedVector2Array([Vector2(250, LEDGE_Y), Vector2(VIEW.x, LEDGE_Y),
			Vector2(VIEW.x, VIEW.y), Vector2(250, VIEW.y)])
	ledge.color = Color(0.045, 0.04, 0.07)
	add_child(ledge)
	var rim := Line2D.new()
	rim.points = PackedVector2Array([Vector2(250, LEDGE_Y), Vector2(VIEW.x, LEDGE_Y)])
	rim.width = 1.0
	rim.default_color = Color(MAGENTA, 0.8)
	add_child(rim)

	_cat = Sprite2D.new()
	_cat.texture = CAT_SHEET
	_cat.hframes = 8
	var frame := CAT_SHEET.get_width() / 8
	_cat.vframes = CAT_SHEET.get_height() / frame
	_cat.scale = Vector2.ONE * 32.0 / frame
	if frame > 32:
		_cat.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_cat.flip_h = true
	_cat.position = Vector2(CAT_X, LEDGE_Y - 13.5) # las patas están en la fila 29.5 del cuadro de 32
	var belly := CatBond.is_bonded() and _cat.vframes >= 10
	for f in (range(74, 78) if belly else range(40, 48)):
		_cat_frames.append(f)
	add_child(_cat)


# --- interfaz --------------------------------------------------------------------

func _add_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)

	# Franja oscura difusa detrás del título, para que se lea sobre los hologramas
	var band := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.02, 0.02, 0.06, 0.8))
	grad.set_color(1, Color(0.02, 0.02, 0.06, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	band.texture = tex
	band.stretch_mode = TextureRect.STRETCH_SCALE
	band.position = Vector2(VIEW.x / 2.0 - 150, 8)
	band.size = Vector2(300, 60)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(band)

	var title := TITLE.new()
	title.text = "CHRONICLES OF THE KITTEN"
	title.size = 1.45
	title.position = Vector2(VIEW.x / 2.0, 30)
	ui.add_child(title)

	var subtitle := TITLE.new()
	var adopted := CatBond.trust >= CatBond.ADOPTED
	subtitle.text = "SUJETO K-7 - ADOPTADO" if adopted else "SUJETO K-7 - DESCARTADO"
	subtitle.size = 0.62
	subtitle.color = Color(1.0, 0.62, 0.78) if adopted else Color(1.0, 0.25, 0.25)
	subtitle.position = Vector2(VIEW.x / 2.0, 44)
	ui.add_child(subtitle)

	var box := VBoxContainer.new()
	box.position = Vector2(VIEW.x / 2.0 - 45, 94)
	box.size = Vector2(90, 0)
	box.add_theme_constant_override("separation", 6)
	ui.add_child(box)
	_play = _button("JUGAR", func(): Game.start_level(0))
	box.add_child(_play)
	box.add_child(_button("SALIR", func(): get_tree().quit()))

	var hint := Label.new()
	hint.text = "A/D mover   ESPACIO saltar   SHIFT correr   CTRL deslizarse   Q/R tiempo   ESC menú"
	hint.add_theme_font_size_override("font_size", 6)
	hint.add_theme_color_override("font_color", Color(0.75, 0.8, 0.95, 0.75))
	hint.position = Vector2(8, VIEW.y - 14)
	ui.add_child(hint)


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(90, 18)
	b.add_theme_font_size_override("font_size", 9)
	b.add_theme_color_override("font_color", CYAN)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", _style(Color(0.02, 0.03, 0.09, 0.75), Color(CYAN, 0.7)))
	b.add_theme_stylebox_override("hover", _style(Color(0.12, 0.04, 0.16, 0.85), MAGENTA))
	b.add_theme_stylebox_override("focus", _style(Color(0.12, 0.04, 0.16, 0.85), MAGENTA))
	b.add_theme_stylebox_override("pressed", _style(Color(0.25, 0.06, 0.25, 0.9), MAGENTA))
	# El foco sigue al mouse solo si se mueve (si el menú se abre con el
	# cursor quieto encima de SALIR, Enter no debe cerrar el juego)
	b.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseMotion and not b.has_focus():
			b.grab_focus())
	b.pressed.connect(action)
	return b


func _style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_content_margin_all(2)
	return s
