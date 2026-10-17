# Construye un nivel completo a partir de los datos de level_data.gd.
#
# Todo el nivel se genera en codigo: bloques solidos, decoracion, estrellas,
# objetos (corazon, gema, Super salto), resortes, checkpoints, plataformas
# moviles y la meta final.
#
# Regla de colision: el pack KayKit no incluye colision, asi que cada bloque
# solido recibe una BoxShape3D calculada desde su nombre (X ancho, Z fondo,
# Y alto) con el pivote en la base, desplazada media altura hacia arriba.
class_name LevelBuilder
extends RefCounted

const DATA := preload("res://scripts/level_data.gd")
const SceneryScript := preload("res://scripts/scenery.gd")

const SCRIPT_PICKUP := "res://scripts/pickup.gd"
const SCRIPT_MOVER := "res://scripts/mover.gd"
const SCRIPT_SPRING := "res://scripts/spring_pad.gd"
const SCRIPT_CRUMBLE := "res://scripts/crumble.gd"
const SCRIPT_BOOST := "res://scripts/boost_pad.gd"

# Modelo, color y halo de cada objeto recogible.
const ITEM_LOOK := {
	"star": {"model": "star", "color": "yellow", "halo": Color(1, 0.82, 0.3, 0.55), "scale": 1.0},
	"heart": {"model": "heart", "color": "red", "halo": Color(1, 0.35, 0.45, 0.6), "scale": 1.0},
	"gem": {"model": "diamond", "color": "blue", "halo": Color(0.35, 0.8, 1, 0.7), "scale": 1.25},
	"power": {"model": "power", "color": "yellow", "halo": Color(0.65, 1, 0.35, 0.6), "scale": 1.1},
	# Aro de tiempo del contrarreloj: se atraviesa como una puerta. El modelo
	# tiene el pivote abajo; se baja medio aro para centrarlo en el punto.
	"time": {"model": "hoop", "color": "green", "halo": Color(0.4, 1, 0.75, 0.55), "scale": 0.55, "offset_y": -1.3, "spin": 1.2, "radius": 1.3},
}

# Bloques que deben frenar al jugador.
const SOLID_PREFIXES := ["platform_", "barrier_", "pillar_", "platform_wood_"]


static func build(level_root: Node3D, data: Dictionary) -> Dictionary:
	_clear(level_root)

	var star_total := 0

	for entry in data.get("blocks", []):
		_add_solid(level_root, entry[0], entry[1], Vector3(entry[2], entry[3], entry[4]),
			entry[5] if entry.size() > 5 else 0.0)

	for entry in data.get("crumbles", []):
		_add_crumble(level_root, entry[0], entry[1], Vector3(entry[2], entry[3], entry[4]))

	for pad_pos in data.get("boost_pads", []):
		_add_boost_pad(level_root, pad_pos)

	for entry in data.get("decor", []):
		_add_decor(level_root, entry[0], entry[1], Vector3(entry[2], entry[3], entry[4]), entry[5])

	for star_pos in data.get("stars", []):
		_add_pickup(level_root, "star", star_pos, 0.9)
		star_total += 1

	var gem_total := 0
	for item in data.get("items", []):
		var item_look: Dictionary = ITEM_LOOK.get(item[0], {})
		_add_pickup(level_root, item[0], item[1], float(item_look.get("radius", 1.0)))
		if item[0] == "gem":
			gem_total += 1

	for spring_pos in data.get("springs", []):
		_add_spring(level_root, spring_pos)

	for cp_pos in data.get("checkpoints", []):
		_add_checkpoint(level_root, cp_pos)

	for mover in data.get("movers", []):
		_add_mover(level_root, mover)

	_add_goal(level_root, data.get("goal", Vector3.ZERO))

	SceneryScript.build(level_root, data)

	return {
		"spawn": data.get("spawn", Vector3(0, 2, 0)),
		"fall_y": data.get("fall_y", -18.0),
		"star_total": star_total,
		"gem_total": gem_total,
	}


# --- Limpieza ----------------------------------------------------------------

static func _clear(level_root: Node3D) -> void:
	for child in level_root.get_children():
		level_root.remove_child(child)
		child.queue_free()


# --- Bloques solidos ---------------------------------------------------------

static func _add_solid(level_root: Node3D, type_name: String, color: String, pos: Vector3, rot_y_deg: float = 0.0) -> void:
	var scene := _load_model(type_name, color)
	if scene == null:
		return

	var size := DATA.block_size(type_name)

	var body := StaticBody3D.new()
	body.name = "Block_" + type_name
	body.position = pos
	level_root.add_child(body)

	body.rotation.y = deg_to_rad(rot_y_deg)
	var visual: Node3D = scene.instantiate()
	body.add_child(visual)

	var shape := BoxShape3D.new()
	shape.size = size

	var col := CollisionShape3D.new()
	col.shape = shape
	# El pivote del modelo esta en la base: subimos la caja media altura.
	col.position = Vector3(0.0, size.y * 0.5, 0.0)
	body.add_child(col)


# --- Decoracion (sin colision) ----------------------------------------------

static func _add_decor(level_root: Node3D, type_name: String, color: String, pos: Vector3, rot_y_deg: float) -> void:
	var scene := _load_model(type_name, color)
	if scene == null:
		return

	var node: Node3D = scene.instantiate()
	node.name = "Decor_" + type_name
	node.position = pos
	node.rotation.y = deg_to_rad(rot_y_deg)
	level_root.add_child(node)


# --- Coleccionables, checkpoints y meta --------------------------------------

static func _add_pickup(level_root: Node3D, kind: String, pos: Vector3, radius: float) -> void:
	var look: Dictionary = ITEM_LOOK.get(kind, ITEM_LOOK["star"])
	var area := Area3D.new()
	area.name = "Pickup_" + kind
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitoring = true
	area.set_script(load(SCRIPT_PICKUP))
	area.set("kind", kind)
	area.set("spin_speed", float(look.get("spin", 2.2)))

	var shape := SphereShape3D.new()
	shape.radius = radius
	var col := CollisionShape3D.new()
	col.shape = shape
	area.add_child(col)

	var scene := _load_model(look["model"], look["color"])
	if scene != null:
		var visual: Node3D = scene.instantiate()
		visual.name = "Visual"
		visual.scale = Vector3.ONE * float(look["scale"])
		visual.position.y = float(look.get("offset_y", 0.0))
		area.add_child(visual)
		# Dentro del Visual: el halo desaparece con el objeto al recogerlo.
		visual.add_child(_make_halo(look["halo"]))

	level_root.add_child(area)


# Resplandor detras del objeto, siempre de cara a la camara. Un material por
# color, compartido entre todos los objetos de ese color.
static var _halo_materials: Dictionary = {}
static var _halo_texture: GradientTexture2D = null

static func _make_halo(color: Color) -> MeshInstance3D:
	if _halo_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(0.5, 0.0)
		texture.width = 64
		texture.height = 64
		_halo_texture = texture
	var material: StandardMaterial3D = _halo_materials.get(color)
	if material == null:
		material = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		material.albedo_color = color
		material.albedo_texture = _halo_texture
		material.no_depth_test = false
		_halo_materials[color] = material
	var quad := QuadMesh.new()
	quad.size = Vector2(1.9, 1.9)
	var halo := MeshInstance3D.new()
	halo.name = "Halo"
	halo.mesh = quad
	halo.material_override = material
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return halo


static func _add_checkpoint(level_root: Node3D, pos: Vector3) -> void:
	var area := Area3D.new()
	area.name = "Checkpoint"
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitoring = true
	area.set_script(load(SCRIPT_PICKUP))
	area.set("kind", "checkpoint")
	area.set("spin_speed", 0.0)

	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 3.0, 2.4)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0, 1.5, 0)
	area.add_child(col)

	# Poste neutral + bandera roja que pasa a verde al activarse.
	var pole_scene := _load_model("pillar_1x1x2", "neutral")
	if pole_scene != null:
		var pole: Node3D = pole_scene.instantiate()
		area.add_child(pole)

	var flag_scene := _load_model("flag_B", "red")
	if flag_scene != null:
		var flag: Node3D = flag_scene.instantiate()
		flag.name = "Flag"
		flag.position = Vector3(0, 2.0, 0)
		area.add_child(flag)

	level_root.add_child(area)


static func _add_goal(level_root: Node3D, pos: Vector3) -> void:
	var root := Node3D.new()
	root.name = "Goal"
	root.position = pos
	level_root.add_child(root)

	var sign_scene := _load_model("signage_finish_wide", "neutral")
	if sign_scene != null:
		var sign_node: Node3D = sign_scene.instantiate()
		root.add_child(sign_node)

	var area := Area3D.new()
	area.name = "GoalTrigger"
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitoring = true
	area.set_script(load(SCRIPT_PICKUP))
	area.set("kind", "goal")
	area.set("spin_speed", 0.0)

	var shape := BoxShape3D.new()
	shape.size = Vector3(6.0, 4.0, 2.0)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0, 2.0, 0)
	area.add_child(col)
	root.add_child(area)


# --- Contrarreloj: bloques que se rompen y Turbo ------------------------------

static func _add_crumble(level_root: Node3D, type_name: String, color: String, pos: Vector3) -> void:
	var scene := _load_model(type_name, color)
	if scene == null:
		return
	var size := DATA.block_size(type_name)

	var body := AnimatableBody3D.new()
	body.name = "Crumble"
	body.position = pos
	body.set_script(load(SCRIPT_CRUMBLE))

	var visual: Node3D = scene.instantiate()
	visual.name = "Visual"
	body.add_child(visual)

	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.name = "Shape"
	col.shape = shape
	col.position = Vector3(0, size.y * 0.5, 0)
	body.add_child(col)

	# Sensor fino sobre la cara de arriba: detecta que el jugador lo pisa.
	var sensor := Area3D.new()
	sensor.name = "Sensor"
	sensor.collision_layer = 0
	sensor.collision_mask = 1
	var sensor_shape := BoxShape3D.new()
	sensor_shape.size = Vector3(size.x - 0.05, 0.3, size.z - 0.05)
	var sensor_col := CollisionShape3D.new()
	sensor_col.shape = sensor_shape
	sensor_col.position = Vector3(0, size.y + 0.15, 0)
	sensor.add_child(sensor_col)
	body.add_child(sensor)

	level_root.add_child(body)


# El bloque flecha ya esta en "blocks"; aqui solo se pone el area encima.
static func _add_boost_pad(level_root: Node3D, pos: Vector3) -> void:
	var area := Area3D.new()
	area.name = "BoostPad"
	area.position = pos + Vector3(0, 1.0, 0)
	area.collision_layer = 0
	area.collision_mask = 1
	area.set_script(load(SCRIPT_BOOST))
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.8, 0.6, 3.8)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0, 0.3, 0)
	area.add_child(col)
	level_root.add_child(area)


# --- Resortes ----------------------------------------------------------------

# Muelle sobre una plataforma: sin colision solida, solo un Area3D que lanza
# al jugador hacia arriba al pisarlo (spring_pad.gd).
static func _add_spring(level_root: Node3D, pos: Vector3) -> void:
	var area := Area3D.new()
	area.name = "Spring"
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitoring = true
	area.set_script(load(SCRIPT_SPRING))

	var shape := BoxShape3D.new()
	shape.size = Vector3(1.4, 0.9, 1.4)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0, 0.45, 0)
	area.add_child(col)

	var scene := _load_model("spring_pad", "red")
	if scene != null:
		var visual: Node3D = scene.instantiate()
		visual.name = "Visual"
		area.add_child(visual)

	level_root.add_child(area)


# --- Plataformas moviles -----------------------------------------------------

static func _add_mover(level_root: Node3D, mover: Dictionary) -> void:
	var scene := _load_model(mover.get("type", "platform_2x2x1"), mover.get("color", "blue"))
	if scene == null:
		return

	var type_name: String = mover.get("type", "platform_2x2x1")
	var size := DATA.block_size(type_name)

	var body := AnimatableBody3D.new()
	body.name = "Mover"
	body.sync_to_physics = true
	body.position = mover.get("from", Vector3.ZERO)
	body.set_script(load(SCRIPT_MOVER))
	body.set("point_a", mover.get("from", Vector3.ZERO))
	body.set("point_b", mover.get("to", Vector3.ZERO))
	body.set("speed", float(mover.get("speed", 3.0)))
	level_root.add_child(body)

	var visual: Node3D = scene.instantiate()
	body.add_child(visual)

	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0, size.y * 0.5, 0)
	body.add_child(col)


# --- Utilidades --------------------------------------------------------------

static func _load_model(type_name: String, color: String) -> PackedScene:
	var path := DATA.asset_path(type_name, color)
	if not ResourceLoader.exists(path):
		push_warning("Modelo no encontrado: " + path)
		return null
	var res := load(path)
	if res is PackedScene:
		return res
	push_warning("No es una escena: " + path)
	return null
