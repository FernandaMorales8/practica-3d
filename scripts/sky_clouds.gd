# Decoracion del cielo: nubes y pajaros.
#
# Todo se genera en codigo con mallas simples, sin colision y sin proyectar
# sombra: es puro adorno para que el fondo no se vea vacio. No anade ningun
# archivo de arte al proyecto.
extends Node3D

const CLOUD_COUNT := 46
const PUFF_SPHERE_RADIUS := 1.0

# Zona donde pueden aparecer las nubes, en metros. El nivel recorre Z de 0 a -90,
# asi que el cielo se cubre de sobra por delante y por detras del recorrido.
const AREA_X := 190.0
const AREA_Z_MIN := -260.0
const AREA_Z_MAX := 70.0
const AREA_Y_MIN := 22.0
const AREA_Y_MAX := 66.0

# Deriva lenta hacia +X para que el cielo no se vea congelado.
const DRIFT_SPEED := 0.7

# Pajaros: vuelan en circulos amplios alrededor del nivel, a distintas alturas.
const BIRD_COUNT := 16
# La camara mira unos 22 grados hacia abajo, asi que solo alcanza a ver hasta
# unos 14 grados por encima del horizonte: unos pajaros a 18-40 m de altura
# quedaban siempre fuera del encuadre por arriba. Volando bajo y algo lejos si
# entran en el trozo de cielo que la camara mira.
const BIRD_ALT_MIN := 7.0
const BIRD_ALT_MAX := 20.0
const BIRD_RADIUS_MIN := 32.0
const BIRD_RADIUS_MAX := 78.0
# Radianes por segundo: valores bajos = vuelo lento y lejano.
const BIRD_SPEED_MIN := 0.055
const BIRD_SPEED_MAX := 0.12
const BIRD_FLAP_SPEED := 8.5
const BIRD_BOB_SPEED := 0.7

var _clouds: Array[Node3D] = []
var _birds: Array[Dictionary] = []
var _material_top: StandardMaterial3D = null
var _material_bottom: StandardMaterial3D = null
var _material_bird: StandardMaterial3D = null
var _sphere: SphereMesh = null
var _bird_body: BoxMesh = null
var _bird_wing: BoxMesh = null
var _elapsed := 0.0


func _ready() -> void:
	_material_top = _make_material(Color(1, 1, 1, 1))
	_material_bottom = _make_material(Color(0.85, 0.89, 0.97, 1))
	_material_bird = _make_material(Color(0.22, 0.24, 0.32, 1))

	# Las mallas se crean una vez y las comparten todas las piezas.
	_sphere = SphereMesh.new()
	_sphere.radius = PUFF_SPHERE_RADIUS
	_sphere.height = PUFF_SPHERE_RADIUS * 2.0
	_sphere.radial_segments = 12
	_sphere.rings = 6

	_bird_body = BoxMesh.new()
	_bird_body.size = Vector3(0.9, 0.55, 2.0)
	_bird_wing = BoxMesh.new()
	_bird_wing.size = Vector3(2.4, 0.12, 1.1)

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260921
	for i in CLOUD_COUNT:
		_clouds.append(_build_cloud(rng, i))
	for i in BIRD_COUNT:
		_birds.append(_build_bird(rng, i))


func _process(delta: float) -> void:
	_elapsed += delta

	for cloud in _clouds:
		cloud.position.x += DRIFT_SPEED * delta
		if cloud.position.x > AREA_X:
			cloud.position.x = -AREA_X

	for bird in _birds:
		_update_bird(bird, delta)


# Cada nivel tine las nubes con su luz (blancas a mediodia, rosadas al
# atardecer). Los materiales son compartidos: basta con cambiarlos aqui.
func set_tint(top: Color, bottom: Color) -> void:
	if _material_top != null:
		_material_top.albedo_color = top
	if _material_bottom != null:
		_material_bottom.albedo_color = bottom


func _make_material(tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 1.0
	material.metallic = 0.0
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return material


# --- Nubes --------------------------------------------------------------------

func _build_cloud(rng: RandomNumberGenerator, index: int) -> Node3D:
	var cloud := Node3D.new()
	cloud.name = "Cloud%d" % index
	cloud.position = Vector3(
		rng.randf_range(-AREA_X, AREA_X),
		rng.randf_range(AREA_Y_MIN, AREA_Y_MAX),
		rng.randf_range(AREA_Z_MIN, AREA_Z_MAX)
	)
	add_child(cloud)

	var width := rng.randf_range(8.0, 16.0)
	var puffs := rng.randi_range(4, 6)
	for p in puffs:
		var puff := MeshInstance3D.new()
		puff.mesh = _sphere
		# La esfera de abajo va algo mas oscura: da volumen sin sombras reales.
		puff.material_override = _material_bottom if p == 0 else _material_top
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puff.position = Vector3(
			rng.randf_range(-width, width),
			rng.randf_range(-1.4, 1.8),
			rng.randf_range(-width * 0.5, width * 0.5)
		)
		var size := rng.randf_range(3.0, 7.2)
		puff.scale = Vector3(size, size * 0.62, size)
		cloud.add_child(puff)

	return cloud


# --- Pajaros ------------------------------------------------------------------

func _build_bird(rng: RandomNumberGenerator, index: int) -> Dictionary:
	var bird := Node3D.new()
	bird.name = "Bird%d" % index
	add_child(bird)

	var body := MeshInstance3D.new()
	body.mesh = _bird_body
	body.material_override = _material_bird
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bird.add_child(body)

	# Cada ala gira sobre un pivote en su raiz, para que el aleteo la haga
	# subir y bajar en vez de desplazarla de lado.
	var wing_left := Node3D.new()
	wing_left.name = "WingLeft"
	wing_left.position = Vector3(-0.2, 0.06, 0.0)
	bird.add_child(wing_left)

	var wing_right := Node3D.new()
	wing_right.name = "WingRight"
	wing_right.position = Vector3(0.2, 0.06, 0.0)
	bird.add_child(wing_right)

	for side in [wing_left, wing_right]:
		var is_left: bool = side == wing_left
		var blade := MeshInstance3D.new()
		blade.mesh = _bird_wing
		blade.material_override = _material_bird
		blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		blade.position = Vector3(-0.82 if is_left else 0.82, 0.0, 0.0)
		side.add_child(blade)

	var bird_data := {
		"node": bird,
		"wing_left": wing_left,
		"wing_right": wing_right,
		# Los centros van repartidos en Z para que no vuelen todos sobre el
		# mismo punto del recorrido.
		"center": Vector3(
			rng.randf_range(-18.0, 18.0),
			0.0,
			rng.randf_range(AREA_Z_MIN * 0.6, AREA_Z_MAX * 0.6)
		),
		"radius": rng.randf_range(BIRD_RADIUS_MIN, BIRD_RADIUS_MAX),
		"angle": rng.randf_range(0.0, TAU),
		"speed": rng.randf_range(BIRD_SPEED_MIN, BIRD_SPEED_MAX),
		"dir": 1.0 if rng.randf() > 0.5 else -1.0,
		"alt": rng.randf_range(BIRD_ALT_MIN, BIRD_ALT_MAX),
		"bob_phase": rng.randf_range(0.0, TAU),
		"flap_phase": rng.randf_range(0.0, TAU),
	}
	# Los deja ya colocados, sin esperar al primer frame.
	_update_bird(bird_data, 0.0)
	return bird_data


# Los diccionarios se pasan por referencia, asi que actualizar aqui el angulo
# deja el cambio guardado en el array de pajaros.
func _update_bird(bird: Dictionary, delta: float) -> void:
	var node: Node3D = bird["node"]
	var angle: float = float(bird["angle"]) + float(bird["speed"]) * float(bird["dir"]) * delta
	bird["angle"] = angle

	var radius: float = bird["radius"]
	var center: Vector3 = bird["center"]
	# Altura con un vaiven suave y lento: suben y bajan mientras circulan.
	var altitude: float = float(bird["alt"]) + sin(_elapsed * BIRD_BOB_SPEED + float(bird["bob_phase"])) * 1.6

	var pos := center + Vector3(cos(angle) * radius, altitude, sin(angle) * radius)
	node.global_position = pos

	# Mira hacia donde vuela: la tangente del circulo.
	var tangent := Vector3(-sin(angle), 0.0, cos(angle)) * float(bird["dir"])
	if tangent.length_squared() > 0.0001:
		node.look_at(pos + tangent)

	# Aleteo: las dos alas suben y bajan a la vez, en espejo.
	var flap := sin(_elapsed * BIRD_FLAP_SPEED + float(bird["flap_phase"])) * 0.55
	var wing_left: Node3D = bird["wing_left"]
	var wing_right: Node3D = bird["wing_right"]
	wing_left.rotation.z = flap
	wing_right.rotation.z = -flap
