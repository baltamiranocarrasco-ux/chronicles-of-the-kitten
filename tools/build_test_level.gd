extends Node
## Genera las escenas de objetos (objects/*.tscn), el tileset y scenes/test_level.tscn.
##
## Uso (desde la carpeta del proyecto):
##   godot --headless --path . res://tools/build_test_level.tscn
##
## Se corre como escena (no con -s) para que carguen los autoloads (CatBond):
## sin ellos los scripts que los usan no compilan y se guardan sin script.
##
## OJO: sobrescribe scenes/test_level.tscn. Si editaste el nivel a mano en el
## editor, esos cambios se pierden al volver a correr este script.
##
## El nivel recorre azoteas conectadas a tres alturas:
##   zona alta  (filas -8 a -14): proyectores holográficos, tuberías y cables
##   zona media (filas -2 a 0)  : la ruta principal, con las cajas
##   zona baja  (filas 4 y 5)   : estructuras oscuras, vapor y vacíos mortales
## El salto del gato llega a ~52 px (3 tiles) y con Shift salta ~7 tiles de
## largo; ningún desnivel que haya que subir supera 3 tiles.

const T := 16
const LEVEL_TILES := 240
const VIEW_TOP := -304
const VIEW_BOTTOM := 160
const BOTTOM_ROW := 10 ## los edificios llegan hasta aquí (el fondo del mundo)
const FALL_LIMIT := 150.0 ## más abajo, el gato cayó a un vacío
const LEVEL_UID := "uid://b7kittestlvl1"

const MOVER := preload("res://objects/mover.gd")
const CHECKPOINT := preload("res://objects/checkpoint.gd")
const CRATE := preload("res://objects/crate.gd")
const LASER := preload("res://objects/hazards/laser_gate.gd")
const STEAM := preload("res://objects/hazards/steam_vent.gd")
const MINES := preload("res://objects/hazards/mine_curtain.gd")
const SAW := preload("res://objects/hazards/saw_rail.gd")
const CABLE := preload("res://objects/hazards/live_cable.gd")
const PUDDLE := preload("res://objects/hazards/electric_puddle.gd")
const SOCKET := preload("res://objects/interactive/energy_socket.gd")
const BATTERY := preload("res://objects/interactive/battery.gd")
const CHIP := preload("res://objects/interactive/data_chip.gd")
const HINT := preload("res://objects/interactive/hint_zone.gd")
const EXIT := preload("res://objects/interactive/level_exit.gd")
const PROJECTOR := preload("res://objects/interactive/holo_projector.gd")
const PIPE := preload("res://objects/interactive/pipe_walk.gd")
const FOG := preload("res://effects/zone_fog.gd")

const CITY_LIFE := preload("res://effects/city_life.gd")
const HOLOGRAM_ADS := preload("res://effects/hologram_ads.gd")
const HOLOGRAMS := 10
const BG_MATERIAL := preload("res://effects/bg_material.tres")
const BG_FX_MATERIAL := preload("res://effects/bg_fx_material.tres")

# [nombre, textura, parallax horizontal, parallax vertical, elementos animados [tipo, delante]]
# Tipos de effects/city_life.gd: 0 ventanas, 1 drones, 2 tráfico, 3 humo, 4 lluvia;
# HOLOGRAMS = hologramas publicitarios (effects/hologram_ads.gd).
# El parallax vertical es chico: al subir a la zona alta la ciudad baja un
# poco (estás más arriba) sin que se vean los bordes de las imágenes.
const PARALLAX_LAYERS := [
	["Sky", "res://assets/city/bg_0_sky.png", 0.0, 0.0, []],
	["FarCity", "res://assets/city/bg_1_far.png", 0.1, 0.04, []],
	["TowerCity", "res://assets/city/bg_2_midfar.png", 0.22, 0.08, [[0, true]]],
	["MidCity", "res://assets/city/bg_3_mid.png", 0.4, 0.14, [[1, false], [3, true], [HOLOGRAMS, true]]],
	["NearCity", "res://assets/city/bg_4_near.png", 0.65, 0.22, [[2, false], [4, true]]],
]
## Altura de la cámara (borde de arriba) en la que el fondo se ve como antes
const BG_REFERENCE_TOP := -152.0
## El fondo está dibujado con el triple de detalle que el pixel art del juego
## (ver tools/generate_city.py) y se muestra a escala 1/3 con filtrado suave
const BG_DETAIL := 3.0

# --- geometría (en tiles) -----------------------------------------------------
# Columnas de edificio: [desde, hasta, fila del techo]; llenan hasta BOTTOM_ROW.
# Donde no hay columna hay un vacío mortal.
const COLUMNS := [
	[0, 46, 0], # A inicio + B pasillo del contenedor
	[47, 54, 4], [58, 63, 4], [67, 72, 5], [73, 79, 4], # C zona baja
	[80, 82, 2], [83, 121, 0], # subida + D láseres + E sierras
	[127, 140, 0], # E después de las minas
	[141, 143, -2], [144, 146, -4], [147, 149, -6], [150, 158, -8], # F subida a la zona alta
	[166, 175, -8], # F techo alto tras la tubería
	[176, 193, -2], # G techo medio bajo los proyectores
	[200, 217, -2], [218, 239, 0], # H después del salto largo y la meta
]
# Bloques macizos sueltos: [desde, hasta, fila de arriba, fila de abajo]
const BLOCKS := [
	[20, 21, -3, -1], # torre de ventilación al inicio
	[30, 44, -4, -3], # techo bajo del pasillo del contenedor (pasillo de 2 tiles)
	[48, 79, -5, -2], # estructura oscura sobre la zona baja
	[88, 109, -4, -3], # techo del pasillo de láseres
]
# Vigas (se atraviesan desde abajo): [desde, hasta, fila]
const BEAMS := [
	[164, 169, -14], # cornisa secreta en lo alto, sobre el techo F
	[114, 116, -3], # repisa sobre las minas
]
const CHECKPOINTS := [[2, 0], [46, 0], [84, 0], [127, 0], [151, -8], [178, -2], [201, -2], [219, 0]]


func _ready() -> void:
	var tileset := build_tileset()
	var platform_scene := save_scene(build_moving_platform(), "res://objects/moving_platform.tscn")
	var crate_scene := save_scene(build_crate(), "res://objects/crate.tscn")

	var level := Node2D.new()
	level.name = "TestLevel"
	build_background(level)
	build_ground(level, tileset)
	build_bounds(level)
	# Penumbra de la zona baja (sobre los tiles, debajo de todo lo demás)
	obj(level, FOG, "LowZoneFog", Vector2(46 * T, -16), {size = Vector2(36 * T, VIEW_BOTTOM + 16)})

	var o := add(level, Node2D.new(), "Objects")
	build_section_a(o, crate_scene)
	build_section_b(o, crate_scene)
	build_section_c(o)
	build_section_d(o)
	build_section_e(o, crate_scene)
	build_section_f(o)
	build_section_g(o, platform_scene)
	build_section_h(o, crate_scene)

	var checkpoints := add(level, Node2D.new(), "Checkpoints")
	for i in CHECKPOINTS.size():
		var cp := Marker2D.new()
		cp.set_script(CHECKPOINT)
		cp.position = Vector2(CHECKPOINTS[i][0] * T, CHECKPOINTS[i][1] * T - 16)
		add(checkpoints, cp, "Checkpoint%d" % (i + 1))

	var player: Node2D = load("res://scenes/player.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	player.position = Vector2(3 * T, -16)
	player.set("fall_limit", FALL_LIMIT)
	add(level, player, "Player")
	var cam := Camera2D.new()
	# Con la interpolación de física la cámara debe ir en el paso de física
	cam.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	cam.limit_left = 0
	cam.limit_right = LEVEL_TILES * T
	cam.limit_top = VIEW_TOP
	cam.limit_bottom = VIEW_BOTTOM
	# En vertical solo sigue al gato cuando se aleja del centro: los saltos no
	# sacuden la pantalla
	cam.drag_vertical_enabled = true
	cam.drag_top_margin = 0.3
	cam.drag_bottom_margin = 0.2
	# Mira un poco hacia arriba: menos muro abajo, más ciudad y zona alta
	cam.offset = Vector2(0, -36)
	add(player, cam, "Camera2D", level)

	save_scene(level, "res://scenes/test_level.tscn")
	ResourceSaver.set_uid("res://scenes/test_level.tscn", ResourceUID.text_to_id(LEVEL_UID))
	print("Nivel generado")
	get_tree().quit()


# --- secciones ------------------------------------------------------------------

## Superficie de una fila de techo (y en px).
func top(row: float) -> float:
	return row * T


## A. Inicio: terminal de energía, cajas ligeras para probar el zarpazo.
func build_section_a(o: Node, crate_scene: PackedScene) -> void:
	hint(o, 5, 0, "E: RECARGAR ENERGIA", "CERCA DE LAS TERMINALES")
	obj(o, SOCKET, "Socket1", Vector2(8.5 * T, top(0) - 11), {})
	hint(o, 12, 0, "CLIC: ZARPAZO", "LAS CAJAS LIGERAS SE ROMPEN DE UN GOLPE")
	crate(o, crate_scene, "BoxA1", 15, 0, CRATE.Kind.BOX)
	crate(o, crate_scene, "BoxA2", 16.2, 0, CRATE.Kind.BOX)
	crate(o, crate_scene, "BoxA3", 15.6, 0, CRATE.Kind.BOX, 1)
	crate(o, crate_scene, "MetalA1", 25, 0, CRATE.Kind.METAL)


## B. Pasillo bajo con cajas ligeras en fila (para romperlas corriendo con la
## Q) y un contenedor blindado que lo bloquea.
func build_section_b(o: Node, crate_scene: PackedScene) -> void:
	hint(o, 28, 0, "CONTENEDOR BLINDADO", "3 GOLPES. CON LA R PUEDES DARLOS TODOS DE UNA VEZ")
	for i in 3:
		crate(o, crate_scene, "BoxB%d" % (i + 1), 32.5 + i * 1.6, 0, CRATE.Kind.BOX)
	crate(o, crate_scene, "Armored1", 41, 0, CRATE.Kind.ARMORED)


## C. Zona baja: estructuras oscuras, fugas de vapor, vacíos y un charco
## electrificado. Se baja desde el pasillo y se vuelve a subir al final.
func build_section_c(o: Node) -> void:
	hint(o, 47.5, 4, "ZONA BAJA", "VAPOR HIRVIENDO Y VACIOS MORTALES")
	obj(o, STEAM, "SteamUp1", Vector2(51.5 * T, top(4) - 8), {direction = STEAM.Dir.UP, length = 44.0, phase = 0.0})
	# Chorro lateral sobre el vacío: hay que saltar entre ráfagas
	obj(o, STEAM, "SteamSide1", Vector2(63.6 * T, top(4) - 5), {direction = STEAM.Dir.RIGHT, length = 46.0,
			idle_time = 1.4, burst_time = 0.8, phase = 0.6})
	obj(o, STEAM, "SteamUp2", Vector2(69.5 * T, top(5) - 8), {direction = STEAM.Dir.UP, length = 50.0, phase = 1.1})
	obj(o, STEAM, "SteamSide2", Vector2(73.4 * T, top(4) - 5), {direction = STEAM.Dir.LEFT, length = 44.0,
			idle_time = 1.2, burst_time = 0.7, phase = 0.2})
	obj(o, PUDDLE, "Puddle1", Vector2(74.5 * T, top(4)), {width = 3.0 * T})
	obj(o, BATTERY, "BatteryC", Vector2(60.5 * T, top(4)), {})


## D. Pasillo de puertas de escáner con barreras láser.
func build_section_d(o: Node) -> void:
	obj(o, SOCKET, "Socket2", Vector2(85.5 * T, top(0) - 11), {})
	hint(o, 87, 0, "BARRERAS LASER", "Q: CAMARA LENTA   R: DETENER EL TIEMPO")
	var colors := [Color(0.3, 0.95, 1.0), Color(1.0, 0.3, 0.85), Color(0.3, 0.95, 1.0)]
	for i in 3:
		obj(o, LASER, "Laser%d" % (i + 1), Vector2((93 + i * 6) * T + 8, top(-2)),
				{height = 32.0, phase = i * 0.37, color = colors[i]})


## E. Sierra en riel, minas flotantes en cadena sobre un vacío y otra sierra.
func build_section_e(o: Node, crate_scene: PackedScene) -> void:
	obj(o, SAW, "Saw1", Vector2(111 * T, top(0) - 8), {length = 7.0 * T, period = 1.5})
	hint(o, 116, 0, "MINAS EN CADENA", "ESPERA EL HUECO O DETEN EL TIEMPO")
	# Cuelgan de un cable alto y barren el arco del salto sobre el vacío
	obj(o, MINES, "Mines1", Vector2(122.3 * T, top(-6)), {count = 4, spacing = 20.0, drop = 66.0,
			amplitude = 20.0, period = 1.9, wave = 1.1})
	obj(o, SAW, "Saw2", Vector2(130 * T, top(0) - 8), {length = 6.0 * T, period = 1.2, phase = 0.4})
	crate(o, crate_scene, "MetalE1", 138, 0, CRATE.Kind.METAL)
	obj(o, BATTERY, "BatteryE", Vector2(115 * T, top(-3)), {})


## F. Subida a la zona alta: escalones, una tubería industrial sobre el vacío
## con cables de alta tensión pelados colgando encima, y un charco en el techo.
func build_section_f(o: Node) -> void:
	obj(o, SOCKET, "Socket3", Vector2(152.5 * T, top(-8) - 11), {})
	hint(o, 154, -8, "CABLES DE ALTA TENSION", "NO LOS ROCES CUANDO CHISPORROTEAN")
	obj(o, PIPE, "Pipe1", Vector2(159 * T, top(-8)), {length = 7.0 * T})
	obj(o, CABLE, "Cable1", Vector2(150 * T, top(-13)), {span = Vector2(26 * T, 0), sag = 14.0,
			drops = [[0.38, 58.0], [0.55, 57.0]], phase = 0.0})
	obj(o, CABLE, "Cable2", Vector2(140 * T, top(-9)), {span = Vector2(10 * T, -32), sag = 10.0,
			drops = [], phase = 0.5})
	obj(o, PUDDLE, "Puddle2", Vector2(170 * T, top(-8)), {width = 3.0 * T})
	obj(o, MINES, "Mines2", Vector2(147.6 * T, top(-11)), {count = 2, spacing = 20.0, drop = 36.0,
			amplitude = 14.0, period = 2.2, wave = 2.0})


## G. Proyectores holográficos. Desde la cornisa secreta en lo alto proyectan
## letreros y estructuras de alambre más abajo: con la R son escalones hasta
## la cornisa (chip secreto). Al seguir, otro proyector marca el salto largo.
func build_section_g(o: Node, _platform_scene: PackedScene) -> void:
	hint(o, 172, -8, "HOLOGRAMAS", "CON LA R SE VUELVEN SOLIDOS")
	var ledge := top(-14)
	var steps := [
		[Vector2(165 * T, ledge), Vector2(177.5 * T, top(-9.6)), PROJECTOR.Kind.SIGN, "OJO 8K", Color(0.35, 0.95, 1.0)],
		[Vector2(166.5 * T, ledge), Vector2(173 * T, top(-11.5)), PROJECTOR.Kind.WIREFRAME, "", Color(1.0, 0.35, 0.85)],
		[Vector2(168 * T, ledge), Vector2(177 * T, top(-13.2)), PROJECTOR.Kind.SIGN, "-50%", Color(1.0, 0.75, 0.3)],
	]
	for i in steps.size():
		var s: Array = steps[i]
		obj(o, PROJECTOR, "Projector%d" % (i + 1), s[0], {target = s[1] - s[0], kind = s[2], text = s[3],
				color = s[4], width = 30.0})
	obj(o, CHIP, "SecretChip", Vector2(165.5 * T, ledge - 12), {})
	obj(o, BATTERY, "BatterySecret", Vector2(168.5 * T, ledge), {})
	# Salto largo: el haz y su polvo marcan el arco (con la Q se encienden)
	hint(o, 190, -2, "SALTO LARGO", "SHIFT + ESPACIO. CON LA Q MIDE EL SALTO")
	obj(o, PROJECTOR, "ProjectorJump", Vector2(192 * T, top(-2)), {target = Vector2(4 * T, -46),
			kind = PROJECTOR.Kind.SIGN, text = "SALTA", width = 34.0, color = Color(0.4, 1.0, 0.75)})
	obj(o, MINES, "Mines3", Vector2(184 * T, top(-8)), {count = 3, spacing = 22.0, drop = 74.0,
			amplitude = 16.0, period = 1.6, wave = 1.4})


## H. Tramo final: sierra, cajas, vapor y la meta.
func build_section_h(o: Node, crate_scene: PackedScene) -> void:
	obj(o, SAW, "Saw3", Vector2(204 * T, top(-2) - 8), {length = 6.0 * T, period = 1.3})
	crate(o, crate_scene, "BoxH1", 212, -2, CRATE.Kind.BOX)
	crate(o, crate_scene, "BoxH2", 213.2, -2, CRATE.Kind.BOX)
	obj(o, STEAM, "SteamUp3", Vector2(222.5 * T, top(0) - 8), {direction = STEAM.Dir.UP, length = 48.0, phase = 0.3})
	obj(o, PUDDLE, "Puddle3", Vector2(226 * T, top(0)), {width = 2.5 * T})
	crate(o, crate_scene, "Armored2", 230, 0, CRATE.Kind.ARMORED)
	obj(o, EXIT, "LevelExit", Vector2(236 * T, top(0)), {})


func hint(o: Node, x: float, row: float, text: String, sub: String) -> void:
	obj(o, HINT, ("Hint_" + text.replace(" ", "").left(14)).validate_node_name(), Vector2(x * T, top(row) - 40),
			{text = text, subtitle = sub})


## Caja sobre un techo; `stack` = cuántas cajas de 16 px tiene debajo.
func crate(o: Node, scene: PackedScene, node_name: String, x: float, row: float, kind: int, stack := 0) -> void:
	var h: float = {CRATE.Kind.METAL: 16.0, CRATE.Kind.BOX: 11.0, CRATE.Kind.ARMORED: 32.0}[kind]
	place(o, scene, node_name, Vector2(x * T, top(row) - h / 2.0 - stack * 11.5 - 0.5), {kind = kind})


## Crea un nodo con un script de objeto (del tipo base del script) y le
## asigna las propiedades.
func obj(parent: Node, script: Script, node_name: String, pos: Vector2, props: Dictionary) -> Node2D:
	var n: Node2D = ClassDB.instantiate(script.get_instance_base_type())
	n.set_script(script)
	n.position = pos
	for key in props:
		n.set(key, props[key])
	add(parent, n, node_name)
	return n


# --- utilidades ---------------------------------------------------------------

func add(parent: Node, child: Node, child_name: String, owner_node: Node = null) -> Node:
	child.name = child_name
	parent.add_child(child)
	var root := owner_node if owner_node else (parent if parent.owner == null else parent.owner)
	if child != root:
		child.owner = root
	return child


func save_scene(root: Node, path: String) -> PackedScene:
	var packed := PackedScene.new()
	var err := packed.pack(root)
	assert(err == OK)
	ResourceSaver.save(packed, path)
	root.free()
	return load(path)


func place(parent: Node, scene: PackedScene, node_name: String, pos: Vector2, props: Dictionary) -> void:
	var node: Node2D = scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	node.position = pos
	for key in props:
		node.set(key, props[key])
	add(parent, node, node_name)


func rect_shape(size: Vector2) -> RectangleShape2D:
	var s := RectangleShape2D.new()
	s.size = size
	return s


func collision(shape: Shape2D, pos := Vector2.ZERO) -> CollisionShape2D:
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = pos
	return cs


func sprite(path: String, offset := Vector2.ZERO) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.offset = offset
	return s


# --- objetos ------------------------------------------------------------------

func build_moving_platform() -> Node:
	var body := AnimatableBody2D.new()
	body.name = "MovingPlatform"
	body.set_script(MOVER)
	add(body, sprite("res://objects/moving_platform.png"), "Sprite2D")
	var cs := collision(rect_shape(Vector2(48, 12)))
	cs.one_way_collision = true
	add(body, cs, "CollisionShape2D")
	return body


func build_crate() -> Node:
	# El dibujo, la forma y el peso los pone objects/crate.gd según el tipo
	var body := RigidBody2D.new()
	body.name = "Crate"
	body.set_script(CRATE)
	add(body, Sprite2D.new(), "Sprite2D")
	add(body, CollisionShape2D.new(), "CollisionShape2D")
	return body


# --- nivel --------------------------------------------------------------------

func build_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	ts.add_physics_layer()
	var src := TileSetAtlasSource.new()
	src.texture = load("res://assets/city/tiles.png")
	src.texture_region_size = Vector2i(T, T)
	ts.add_source(src, 0)
	var h := T / 2.0
	var solid := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	var beam := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, -h + 7), Vector2(-h, -h + 7)])
	# Tejado (fila 0, con charco en la columna 3), muro (fila 1) y viga (fila 2)
	for c in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
			Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
			Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)]:
		src.create_tile(c)
		var data := src.get_tile_data(c, 0)
		data.set_collision_polygons_count(0, 1)
		data.set_collision_polygon_points(0, 0, solid if c.y < 2 else beam)
		if c.y == 2:
			data.set_collision_polygon_one_way(0, 0, true)
	src.create_tile(Vector2i(0, 3)) # púas electrificadas decorativas, sin colisión
	ResourceSaver.save(ts, "res://assets/city/city_tileset.tres")
	return load("res://assets/city/city_tileset.tres")


func build_background(level: Node) -> void:
	var bg := add(level, Node2D.new(), "Background")
	for l in PARALLAX_LAYERS:
		var p := Parallax2D.new()
		p.scroll_scale = Vector2(l[2], l[3])
		p.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add(bg, p, l[0])
		var s := sprite(l[1])
		s.scale = Vector2.ONE / BG_DETAIL
		# Cada capa se repite a su propio ancho (las de ciudad miden dos pantallas)
		p.repeat_size = Vector2(s.texture.get_width() / BG_DETAIL, 0)
		p.repeat_times = 1 # las capas miden al menos una pantalla: basta una copia a cada lado
		s.centered = false
		# Con scroll vertical k la capa se ve en pantalla en y - k * borde_de_la_cámara:
		# así, a la altura de referencia queda igual que antes
		var y: float = -l[3] * -BG_REFERENCE_TOP
		s.position = Vector2(0, y)
		s.material = BG_MATERIAL
		# Elementos animados detrás o delante de la imagen de la capa
		var behind := []
		var front := []
		for life in l[4]:
			(front if life[1] else behind).append(life[0])
		for kind in behind:
			add(p, city_life(kind, s.texture, y), life_name(kind))
		add(p, s, "Sprite2D")
		for kind in front:
			add(p, city_life(kind, s.texture, y), life_name(kind))
		# Al bajar a la zona baja la capa sube: debajo sigue la base de los
		# edificios (el color de la última fila de la imagen)
		if l[3] > 0.0:
			var base := ColorRect.new()
			base.color = bottom_color(s.texture)
			base.position = Vector2(0, y + s.texture.get_height() / BG_DETAIL - 1)
			base.size = Vector2(s.texture.get_width() / BG_DETAIL, 160)
			base.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add(p, base, "Base")


func bottom_color(tex: Texture2D) -> Color:
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	var c := Color(0, 0, 0, 0)
	var y := img.get_height() - 1
	for x in range(0, img.get_width(), 8):
		c += img.get_pixel(x, y)
	c /= float(img.get_width() / 8)
	c.a = 1.0
	return c


func life_name(kind: int) -> String:
	return "Holograms" if kind == HOLOGRAMS else ["Lights", "Drones", "Traffic", "Smoke", "Rain"][kind]


func city_life(kind: int, texture: Texture2D, y: float) -> Node2D:
	var n := Node2D.new()
	if kind == HOLOGRAMS:
		n.set_script(HOLOGRAM_ADS)
	else:
		n.set_script(CITY_LIFE)
		n.set("kind", kind)
	n.set("layer_width", texture.get_width() / BG_DETAIL)
	n.position = Vector2(0, y)
	n.material = BG_FX_MATERIAL
	return n


func build_ground(level: Node, tileset: TileSet) -> void:
	var ground: TileMapLayer = add(level, TileMapLayer.new(), "Ground")
	ground.tile_set = tileset
	var filled := {}
	for col in COLUMNS:
		for x in range(col[0], col[1] + 1):
			for y in range(col[2], BOTTOM_ROW):
				filled[Vector2i(x, y)] = true
	for b in BLOCKS:
		for x in range(b[0], b[1] + 1):
			for y in range(b[2], b[3] + 1):
				filled[Vector2i(x, y)] = true
	# Vacíos: púas electrificadas allá abajo
	for x in LEVEL_TILES:
		if not filled.has(Vector2i(x, BOTTOM_ROW - 1)):
			ground.set_cell(Vector2i(x, BOTTOM_ROW - 1), 0, Vector2i(0, 3))
	for cell in filled:
		var ax := 1
		if cell.x > 0 and not filled.has(cell + Vector2i.LEFT):
			ax = 0
		elif cell.x < LEVEL_TILES - 1 and not filled.has(cell + Vector2i.RIGHT):
			ax = 2
		var ay := 0 if not filled.has(cell + Vector2i.UP) else 1
		# Algunos tejados tienen un charco que refleja el neón
		if ay == 0 and ax == 1 and cell.x % 7 == 3:
			ax = 3
		ground.set_cell(cell, 0, Vector2i(ax, ay))
	for b in BEAMS:
		for x in range(b[0], b[1] + 1):
			var ax := 0 if x == b[0] else (2 if x == b[1] else 1)
			ground.set_cell(Vector2i(x, b[2]), 0, Vector2i(ax, 2))


func build_bounds(level: Node) -> void:
	var bounds := add(level, StaticBody2D.new(), "LevelBounds")
	for side in [[0.0, Vector2.RIGHT, "Left"], [LEVEL_TILES * T * 1.0, Vector2.LEFT, "Right"]]:
		var wb := WorldBoundaryShape2D.new()
		wb.normal = side[1]
		add(bounds, collision(wb, Vector2(side[0], 0)), side[2])
