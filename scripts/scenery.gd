# Ambientacion de cada nivel: el mar, los pilares bajo las plataformas, las
# islas de fondo y la luz y el cielo propios del nivel.
#
# Todo es decorado: nada de esto tiene colision ni cambia la jugabilidad.
# Lo que se ve viene del "theme" de cada nivel en level_data.gd; lo que falte
# se toma de DEFAULT_THEME.
class_name Scenery
extends RefCounted

const DATA := preload("res://scripts/level_data.gd")
const WATER_SHADER := preload("res://shaders/water.gdshader")
const FOAM_SHADER := preload("res://shaders/foam_ring.gdshader")

const DEFAULT_THEME := {
	"sky_top": Color(0.27, 0.52, 0.9),
	"sky_horizon": Color(1, 0.86, 0.68),
	"ground_bottom": Color(0.75, 0.8, 0.87),
	"sun_color": Color(1, 0.92, 0.78),
	"sun_energy": 1.3,
	# Grados: inclinacion (negativa = hacia abajo) y orientacion del sol.
	"sun_pitch": -52.0,
	"sun_yaw": -35.0,
	"ambient": Color(0.72, 0.8, 0.92),
	"ambient_energy": 1.25,
	"fog_color": Color(0.96, 0.9, 0.82),
	"fog_density": 0.004,
	"water_deep": Color(0.05, 0.45, 0.62),
	"water_crest": Color(0.3, 0.82, 0.86),
	"cloud_top": Color(1, 1, 1),
	"cloud_bottom": Color(0.85, 0.89, 0.97),
	"island_colors": ["green", "blue", "yellow"],
	"flag_color": "red",
}

# El mar queda un metro por encima de la altura de muerte: el jugador se
# hunde en el agua justo antes de reaparecer, y la camara sigue por encima.
const SEA_ABOVE_FALL_Y := 1.0
const PILLAR_HEIGHT := 8.0

# Islas de fondo, a ambos lados del recorrido.
const ISLAND_COUNT := 20
const ISLAND_MIN_X := 20.0
const ISLAND_MAX_X := 66.0
const ISLAND_CAPS := ["platform_6x6x1", "platform_4x4x1", "platform_6x6x1", "platform_6x2x1"]
const ISLAND_PROPS := ["flag_A", "arch", "hoop", "diamond", "", "arch_wide", "flag_C", ""]


static func theme_of(data: Dictionary) -> Dictionary:
	var theme := DEFAULT_THEME.duplicate()
	theme.merge(data.get("theme", {}), true)
	return theme


static func build(level_root: Node3D, data: Dictionary) -> void:
	var theme := theme_of(data)
	var sea_y: float = data.get("fall_y", -18.0) + SEA_ABOVE_FALL_Y
	var goal: Vector3 = data.get("goal", Vector3.ZERO)

	var root := Node3D.new()
	root.name = "Scenery"
	level_root.add_child(root)

	# El mar y la espuma cuelgan de "Tide": en contrarreloj main.gd lo sube
	# entero para que la marea crezca a medida que se acaba el tiempo.
	var tide := Node3D.new()
	tide.name = "Tide"
	root.add_child(tide)

	var foam := _foam_material()
	_add_sea(tide, theme, sea_y, goal.z * 0.5)
	_add_supports(root, data, sea_y, foam)
	_add_entry_flags(root, data, theme)
	_add_islands(root, data, theme, sea_y, goal.z, foam)


# --- Mar ---------------------------------------------------------------------

static func _add_sea(root: Node3D, theme: Dictionary, sea_y: float, center_z: float) -> void:
	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	material.set_shader_parameter("deep_color", theme["water_deep"])
	material.set_shader_parameter("crest_color", theme["water_crest"])
	material.set_shader_parameter("horizon_color", theme["sky_horizon"])

	# Zona cercana con malla fina para que las olas se muevan de verdad.
	var near := PlaneMesh.new()
	near.size = Vector2(300, 300)
	near.subdivide_width = 150
	near.subdivide_depth = 150
	_add_mesh(root, "Sea", near, material, Vector3(0, sea_y, center_z))

	# Hasta el horizonte, un plano liso un poco mas bajo: sin el, el borde
	# del mar se veria como una linea recta contra el cielo.
	var far_material := material.duplicate() as ShaderMaterial
	far_material.set_shader_parameter("wave_height", 0.0)
	var far := PlaneMesh.new()
	far.size = Vector2(3000, 3000)
	_add_mesh(root, "SeaFar", far, far_material, Vector3(0, sea_y - 0.5, center_z))


static func _foam_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FOAM_SHADER
	return material


static func _add_foam(root: Node3D, material: ShaderMaterial, pos: Vector3, width: float) -> void:
	var plane := PlaneMesh.new()
	# El aro empieza en el borde del pilar (inner = 0.42 del radio del plano).
	var size := width / 0.42
	plane.size = Vector2(size, size)
	plane.subdivide_width = 6
	plane.subdivide_depth = 6
	_add_mesh(root.get_node("Tide"), "Foam", plane, material, pos)


# --- Pilares bajo el recorrido -----------------------------------------------

# Cada plataforma fija se apoya en una columna de pilares que baja hasta el
# agua. Las moviles no: se ve claro que flotan y se desplazan.
static func _add_supports(root: Node3D, data: Dictionary, sea_y: float, foam: ShaderMaterial) -> void:
	for entry in data.get("blocks", []):
		var type_name: String = entry[0]
		var top := Vector3(entry[2], entry[3], entry[4])
		var size := DATA.block_size(type_name)
		var pillar := "pillar_2x2x8" if minf(size.x, size.z) >= 4.0 else "pillar_1x1x8"
		var width := 2.0 if pillar == "pillar_2x2x8" else 1.0
		_add_column(root, pillar, top, sea_y)
		_add_foam(root, foam, Vector3(top.x, sea_y, top.z), width)


# Apila pilares desde `top` hacia abajo hasta pasar un poco el nivel del mar.
static func _add_column(root: Node3D, pillar: String, top: Vector3, sea_y: float) -> void:
	var scene := _load(pillar, "neutral")
	if scene == null:
		return
	var y := top.y - PILLAR_HEIGHT
	while y + PILLAR_HEIGHT > sea_y - 1.0:
		var node: Node3D = scene.instantiate()
		node.position = Vector3(top.x, y, top.z)
		root.add_child(node)
		y -= PILLAR_HEIGHT


# --- Banderas ----------------------------------------------------------------

# Dos banderas flanquean la entrada (el lado +Z) de cada plataforma grande,
# salvo donde ya hay decoracion del nivel.
static func _add_entry_flags(root: Node3D, data: Dictionary, theme: Dictionary) -> void:
	var scene := _load("flag_A", theme["flag_color"])
	if scene == null:
		return
	var decor_spots: Array[Vector3] = []
	for entry in data.get("decor", []):
		decor_spots.append(Vector3(entry[2], entry[3], entry[4]))

	for entry in data.get("blocks", []):
		var size := DATA.block_size(entry[0])
		if size.x < 6.0 or size.z < 6.0:
			continue
		var base := Vector3(entry[2], entry[3] + size.y, entry[4])
		for side in [-1.0, 1.0]:
			var pos := base + Vector3(side * (size.x * 0.5 - 0.35), 0.0, size.z * 0.5 - 0.35)
			if _near_any(pos, decor_spots, 1.5):
				continue
			var flag: Node3D = scene.instantiate()
			flag.position = pos
			# La tela mira hacia fuera de la plataforma.
			flag.rotation.y = PI * 0.5 * side
			root.add_child(flag)


# --- Islas de fondo ----------------------------------------------------------

# Torres decorativas a los lados, mas grandes que el recorrido y difuminadas
# por la niebla: dan profundidad sin estorbar a la camara. La semilla sale
# del nombre del nivel, asi cada nivel tiene siempre el mismo paisaje.
static func _add_islands(root: Node3D, data: Dictionary, theme: Dictionary, sea_y: float, goal_z: float, foam: ShaderMaterial) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(data.get("name", "nivel")))
	var colors: Array = theme["island_colors"]

	for i in ISLAND_COUNT:
		var side := -1.0 if i % 2 == 0 else 1.0
		var scale := rng.randf_range(1.6, 3.2)
		var x := side * rng.randf_range(ISLAND_MIN_X + 3.0 * scale, ISLAND_MAX_X)
		var z := rng.randf_range(goal_z - 50.0, 40.0)
		var top_y := rng.randf_range(-6.0, 14.0)

		var island := Node3D.new()
		island.name = "Island"
		island.position = Vector3(x, top_y, z)
		island.rotation.y = rng.randi_range(0, 3) * PI * 0.5
		island.scale = Vector3.ONE * scale
		root.add_child(island)

		var color: String = colors[rng.randi_range(0, colors.size() - 1)]
		var cap_name: String = ISLAND_CAPS[rng.randi_range(0, ISLAND_CAPS.size() - 1)]
		var cap_scene := _load(cap_name, color)
		if cap_scene != null:
			island.add_child(cap_scene.instantiate())

		# Columna en coordenadas locales: la escala del nodo la agranda entera.
		var cap_size := DATA.block_size(cap_name)
		var pillar := "pillar_2x2x8" if cap_size.x >= 4.0 else "pillar_1x1x8"
		var local_sea := (sea_y - top_y) / scale
		_add_column(island, pillar, Vector3.ZERO, local_sea)
		var width := (2.0 if pillar == "pillar_2x2x8" else 1.0) * scale
		_add_foam(root, foam, Vector3(x, sea_y, z), width)

		var prop: String = ISLAND_PROPS[rng.randi_range(0, ISLAND_PROPS.size() - 1)]
		if prop != "":
			var prop_scene := _load(prop, colors[rng.randi_range(0, colors.size() - 1)])
			if prop_scene != null:
				var node: Node3D = prop_scene.instantiate()
				node.position.y = cap_size.y + (1.2 if prop == "diamond" else 0.0)
				island.add_child(node)


# --- Luz y cielo -------------------------------------------------------------

static func apply_environment(main: Node, data: Dictionary) -> void:
	var theme := theme_of(data)

	var env_node := main.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node != null and env_node.environment != null:
		var env := env_node.environment
		var sky_mat := env.sky.sky_material as ProceduralSkyMaterial if env.sky != null else null
		if sky_mat != null:
			sky_mat.sky_top_color = theme["sky_top"]
			sky_mat.sky_horizon_color = theme["sky_horizon"]
			sky_mat.ground_horizon_color = theme["sky_horizon"]
			sky_mat.ground_bottom_color = theme["ground_bottom"]
		env.ambient_light_color = theme["ambient"]
		env.ambient_light_energy = theme["ambient_energy"]
		# La niebla toma el color del horizonte: el mar lejano se funde con el
		# cielo en lugar de cortarse.
		env.fog_light_color = theme["fog_color"]
		env.fog_density = theme["fog_density"]

	var sun := main.get_node_or_null("Sun") as DirectionalLight3D
	if sun != null:
		sun.light_color = theme["sun_color"]
		sun.light_energy = theme["sun_energy"]
		sun.rotation_degrees = Vector3(theme["sun_pitch"], theme["sun_yaw"], 0.0)

	var clouds := main.get_node_or_null("Clouds")
	if clouds != null and clouds.has_method("set_tint"):
		clouds.call("set_tint", theme["cloud_top"], theme["cloud_bottom"])


# --- Utilidades --------------------------------------------------------------

static func _add_mesh(root: Node3D, node_name: String, mesh: Mesh, material: Material, pos: Vector3) -> void:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = pos
	root.add_child(node)


static func _near_any(pos: Vector3, spots: Array[Vector3], radius: float) -> bool:
	for spot in spots:
		if pos.distance_to(spot) < radius:
			return true
	return false


static func _load(type_name: String, color: String) -> PackedScene:
	var path := DATA.asset_path(type_name, color)
	if not ResourceLoader.exists(path):
		push_warning("Modelo no encontrado: " + path)
		return null
	return load(path) as PackedScene
