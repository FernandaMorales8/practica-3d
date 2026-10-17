# Objetos interactivos del nivel: estrella, corazon, gema, Super salto, aro
# de tiempo, checkpoint y meta.
#
# Todos son Area3D que detectan al jugador (grupo "player") y avisan al
# nivel mediante la senal "collected". El nodo raiz del nivel conecta esas
# senales para llevar el progreso.
extends Area3D

signal collected(kind: String, node: Node)

# Se recogen una vez y desaparecen con una pequena animacion.
const COLLECTIBLE_KINDS := ["star", "heart", "gem", "power", "time"]

const FLAG_GREEN := "res://assets/KayKit_Platformer_Pack_1.0_FREE/Assets/gltf/green/flag_B_green.gltf"

var kind := "star"
var spin_speed := 2.2

var _taken := false
var _t := 0.0
var _visual: Node3D = null
var _flag: Node3D = null
var _visual_base_y := 0.0
var _halo: Node3D = null


func _ready() -> void:
	add_to_group("pickup")
	add_to_group("pickup_" + kind)
	body_entered.connect(_on_body_entered)
	_visual = get_node_or_null("Visual")
	_flag = get_node_or_null("Flag")
	if _visual != null:
		_visual_base_y = _visual.position.y
		_halo = _visual.get_node_or_null("Halo")


func _process(delta: float) -> void:
	_t += delta
	if _visual != null and spin_speed > 0.0:
		_visual.rotate_y(delta * spin_speed)
		_visual.position.y = _visual_base_y + sin(_t * 2.2) * 0.12
	# El halo late despacio; va a destiempo del rebote para que se vea vivo.
	if _halo != null:
		_halo.scale = Vector3.ONE * (1.0 + sin(_t * 3.1) * 0.12)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	if kind in COLLECTIBLE_KINDS:
		_collect()
		return

	match kind:
		"checkpoint":
			if _taken:
				return
			_taken = true
			_swap_flag_green()
			collected.emit(kind, self)
		"goal":
			if _taken:
				return
			_taken = true
			collected.emit(kind, self)


func _collect() -> void:
	if _taken:
		return
	_taken = true
	# No se puede cambiar la monitorizacion dentro del propio evento de
	# colision: el motor lo bloquea y lanza error. Se difiere un paso.
	set_deferred("monitoring", false)
	collected.emit(kind, self)
	if _visual != null:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(_visual, "scale", Vector3.ZERO, 0.18)
		tween.tween_property(_visual, "position:y", _visual.position.y + 0.6, 0.18)
		tween.chain().tween_callback(queue_free)
	else:
		queue_free()


# El checkpoint cambia de bandera roja a verde para que se lea a distancia.
func _swap_flag_green() -> void:
	if _flag == null:
		return
	var parent := _flag.get_parent()
	var pos := _flag.position
	_flag.queue_free()
	_flag = null

	var packed := load(FLAG_GREEN) as PackedScene
	if packed != null:
		var node: Node3D = packed.instantiate()
		node.name = "Flag"
		node.position = pos
		parent.add_child(node)
		_flag = node
