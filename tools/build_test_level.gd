extends SceneTree
## Genera las escenas de objetos (objects/*.tscn), el tileset y scenes/test_level.tscn.
##
## Uso (desde la carpeta del proyecto):
##   godot --headless -s res://tools/build_test_level.gd
##
## OJO: sobrescribe scenes/test_level.tscn. Si editaste el nivel a mano en el
## editor, esos cambios se pierden al volver a correr este script.
##
## Alturas: el salto del gato llega a ~52 px (3 tiles), así que ningún desnivel
## que haya que subir supera 2 tiles (32 px).

const T := 16
const LEVEL_TILES := 200
const VIEW_TOP := -152
const VIEW_BOTTOM := 64
const LEVEL_UID := "uid://b7kittestlvl1"

const MOVER := preload("res://objects/mover.gd")
const HAZARD := preload("res://objects/hazard.gd")
const CHECKPOINT := preload("res://objects/checkpoint.gd")
const RAIN := preload("res://objects/chestnut_rain.gd")
const CRUSHER_PERIOD := 1.0

const CITY_LIFE := preload("res://effects/city_life.gd")
const BG_MATERIAL := preload("res://effects/bg_material.tres")
const BG_FX_MATERIAL := preload("res://effects/bg_fx_material.tres")

# [nombre, textura, velocidad parallax, elementos animados [tipo, delante_de_la_capa]]
# Tipos de effects/city_life.gd: 0 ventanas, 1 drones, 2 tráfico, 3 ventiladores
const PARALLAX_LAYERS := [
	["Sky", "res://assets/city/bg_0_sky.png", 0.0, []],
	["FarCity", "res://assets/city/bg_1_far.png", 0.15, [[0, true]]],
	["MidCity", "res://assets/city/bg_2_mid.png", 0.4, [[1, false]]],
	["NearCity", "res://assets/city/bg_3_near.png", 0.7, [[2, false], [3, true]]],
]

# [desde, hasta, fila superior] (filas negativas = más alto; 0 = suelo normal)
const GROUND_STEPS := [
	[24, 29, -1], [30, 35, -2], [36, 39, -1],
	[116, 119, -2],
	[176, 199, -6],
]
const PITS := [[45, 58]]
const STATIC_PLATFORMS := [[96, 100, -2], [103, 107, -4], [110, 113, -2]]
const CHECKPOINTS := [[41, 0], [60, 0], [92, 0], [122, 0], [158, 0], [168, 0], [180, -6]]


func _init() -> void:
	var tileset := build_tileset()
	var platform_scene := save_scene(build_moving_platform(), "res://objects/moving_platform.tscn")
	var crusher_scene := save_scene(build_crusher(), "res://objects/crusher.tscn")
	var ball_scene := save_scene(build_spike_ball(), "res://objects/spike_ball.tscn")

	var level := Node2D.new()
	level.name = "TestLevel"
	build_background(level)
	build_ground(level, tileset)
	build_bounds(level)

	var objects := add(level, Node2D.new(), "Objects")
	# Sección 1: foso con plataformas móviles (congela el tiempo para subirte fácil)
	place(objects, platform_scene, "PitPlatform1", Vector2(744, 6), {travel = Vector2(80, 0), period = 2.4})
	place(objects, platform_scene, "PitPlatform2", Vector2(840, 6), {travel = Vector2(80, 0), period = 2.4})
	# Sección 2: aplastadores rápidos. Pasan casi todo el ciclo abajo y se abren
	# ~0.23 s, menos de lo que tarda el gato en cruzar (~0.35 s): hace falta
	# cámara lenta (Q) o congelarlos arriba (R)
	for i in 3:
		place(objects, crusher_scene, "Crusher%d" % (i + 1), Vector2((68 + i * 8) * T, -96),
				{phase_offset = i / 3.0, period = CRUSHER_PERIOD, slam_hold_up = 0.06,
				slam_fall = 0.05, slam_hold_down = 0.74})
	# Sección 3: castañas con púas rodando
	for i in 3:
		place(objects, ball_scene, "SpikeBall%d" % (i + 1), Vector2((126 + i * 10) * T, -8),
				{phase_offset = i * 0.3})
	# Sección 4: lluvia de castañas. Solo se cruza congelando el tiempo (R)
	var rain := Node2D.new()
	rain.set_script(RAIN)
	rain.position = Vector2(164 * T, 0)
	add(objects, rain, "ChestnutRain")
	# Sección 5: ascensor rápido hasta la cornisa alta
	place(objects, platform_scene, "Elevator", Vector2(172 * T, 6),
			{travel = Vector2(0, -88), period = 2.0})

	var checkpoints := add(level, Node2D.new(), "Checkpoints")
	for i in CHECKPOINTS.size():
		var cp := Marker2D.new()
		cp.set_script(CHECKPOINT)
		cp.position = Vector2(CHECKPOINTS[i][0] * T, CHECKPOINTS[i][1] * T - 16)
		add(checkpoints, cp, "Checkpoint%d" % (i + 1))

	var player: Node2D = load("res://scenes/player.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	player.position = Vector2(48, -16)
	add(level, player, "Player")
	var cam := Camera2D.new()
	cam.limit_left = 0
	cam.limit_right = LEVEL_TILES * T
	cam.limit_top = VIEW_TOP
	cam.limit_bottom = VIEW_BOTTOM
	add(player, cam, "Camera2D", level)

	save_scene(level, "res://scenes/test_level.tscn")
	ResourceSaver.set_uid("res://scenes/test_level.tscn", ResourceUID.text_to_id(LEVEL_UID))
	print("Nivel generado")
	quit()


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


func circle_shape(radius: float) -> CircleShape2D:
	var s := CircleShape2D.new()
	s.radius = radius
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


func build_crusher() -> Node:
	# Origen = centro del tronco. El sprite (32x160) tiene 112 px de cuerda arriba.
	var body := AnimatableBody2D.new()
	body.name = "Crusher"
	body.set_script(MOVER)
	body.set("travel", Vector2(0, 72))
	body.set("period", 2.0)
	body.set("motion", 1) # SLAM
	add(body, sprite("res://objects/crusher.png", Vector2(0, -56)), "Sprite2D")
	# El cuerpo sólido incluye las púas: mientras bloquea, el gato no puede
	# meterse debajo, y cuando deja de bloquear las púas ya pasaron por encima
	add(body, collision(rect_shape(Vector2(28, 48)), Vector2(0, 0)), "CollisionShape2D")
	var hazard := Area2D.new()
	hazard.set_script(HAZARD)
	add(body, hazard, "Hazard")
	# Dentro del cuerpo y más angosta: solo daña si el tronco cae encima del gato,
	# no al apoyarse en su costado
	add(hazard, collision(rect_shape(Vector2(24, 10)), Vector2(0, 18)), "CollisionShape2D", body)
	return body


func build_spike_ball() -> Node:
	var body := AnimatableBody2D.new()
	body.name = "SpikeBall"
	body.set_script(MOVER)
	body.set("travel", Vector2(64, 0))
	body.set("period", 1.6)
	body.set("roll_radius", 8.0)
	add(body, sprite("res://objects/spike_ball.png"), "Sprite2D")
	add(body, collision(circle_shape(5)), "CollisionShape2D")
	var hazard := Area2D.new()
	hazard.set_script(HAZARD)
	add(body, hazard, "Hazard")
	add(hazard, collision(circle_shape(7)), "CollisionShape2D", body)
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
		p.scroll_scale = Vector2(l[2], 1.0)
		p.repeat_size = Vector2(384, 0)
		p.repeat_times = 3
		add(bg, p, l[0])
		var s := sprite(l[1])
		s.centered = false
		s.position = Vector2(0, VIEW_TOP)
		s.material = BG_MATERIAL
		# Elementos animados detrás o delante de la imagen de la capa
		var behind := []
		var front := []
		for life in l[3]:
			(front if life[1] else behind).append(life[0])
		for kind in behind:
			add(p, city_life(kind, s.texture), "Life%d" % kind)
		add(p, s, "Sprite2D")
		for kind in front:
			add(p, city_life(kind, s.texture), "Life%d" % kind)


func city_life(kind: int, texture: Texture2D) -> Node2D:
	var n := Node2D.new()
	n.set_script(CITY_LIFE)
	n.set("kind", kind)
	n.set("texture", texture)
	n.position = Vector2(0, VIEW_TOP)
	n.material = BG_FX_MATERIAL
	return n


func ground_top(x: int) -> int:
	for step in GROUND_STEPS:
		if x >= step[0] and x <= step[1]:
			return step[2]
	return 0


func in_pit(x: int) -> bool:
	for pit in PITS:
		if x >= pit[0] and x <= pit[1]:
			return true
	return false


func build_ground(level: Node, tileset: TileSet) -> void:
	var ground: TileMapLayer = add(level, TileMapLayer.new(), "Ground")
	ground.tile_set = tileset
	var bottom_row := VIEW_BOTTOM / T
	var filled := {}
	for x in LEVEL_TILES:
		if in_pit(x):
			ground.set_cell(Vector2i(x, bottom_row - 1), 0, Vector2i(0, 3))
			continue
		for y in range(ground_top(x), bottom_row):
			filled[Vector2i(x, y)] = true
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
	for pl in STATIC_PLATFORMS:
		for x in range(pl[0], pl[1] + 1):
			var ax := 0 if x == pl[0] else (2 if x == pl[1] else 1)
			ground.set_cell(Vector2i(x, pl[2]), 0, Vector2i(ax, 2))


func build_bounds(level: Node) -> void:
	var bounds := add(level, StaticBody2D.new(), "LevelBounds")
	for side in [[0.0, Vector2.RIGHT, "Left"], [LEVEL_TILES * T * 1.0, Vector2.LEFT, "Right"]]:
		var wb := WorldBoundaryShape2D.new()
		wb.normal = side[1]
		add(bounds, collision(wb, Vector2(side[0], 0)), side[2])
