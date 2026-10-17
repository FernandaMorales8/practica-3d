# Bloque que se rompe: al pisarlo tiembla un instante, cae al mar y vuelve a
# aparecer unos segundos despues. Obliga a no quedarse quieto.
#
# Es un AnimatableBody3D: mientras tiembla sigue siendo suelo firme, y al
# caer arrastra un momento al jugador antes de soltarlo.
extends AnimatableBody3D

signal crumbled(node: Node)

@export var delay := 0.5
@export var respawn_time := 3.0

const FALL_GRAVITY := 25.0
const SHAKE := 0.07

enum State { SOLID, SHAKING, FALLING }

var _home := Vector3.ZERO
var _state := State.SOLID
var _t := 0.0
var _fall_speed := 0.0
var _visual: Node3D = null
var _shape: CollisionShape3D = null


func _ready() -> void:
	add_to_group("crumble")
	sync_to_physics = false
	_home = position
	_visual = get_node_or_null("Visual")
	_shape = get_node_or_null("Shape")
	var sensor := get_node_or_null("Sensor") as Area3D
	if sensor != null:
		sensor.body_entered.connect(_on_sensor_body_entered)


func _on_sensor_body_entered(body: Node3D) -> void:
	if _state != State.SOLID or not body.is_in_group("player"):
		return
	_state = State.SHAKING
	_t = 0.0
	crumbled.emit(self)


func _physics_process(delta: float) -> void:
	match _state:
		State.SHAKING:
			_t += delta
			# El temblor crece hasta que se suelta.
			var amount := SHAKE * (1.0 + _t / delay * 1.5)
			if _visual != null:
				_visual.position = Vector3(randf_range(-amount, amount), 0.0, randf_range(-amount, amount))
			if _t >= delay:
				_state = State.FALLING
				_t = 0.0
				_fall_speed = 0.0
		State.FALLING:
			_t += delta
			_fall_speed += FALL_GRAVITY * delta
			position.y -= _fall_speed * delta
			if _visual != null:
				_visual.rotation.z += delta * 0.9
				_visual.rotation.x += delta * 0.5
			# Un instante de margen para que el jugador note que cae con el.
			if _t > 0.15 and _shape != null and not _shape.disabled:
				_shape.set_deferred("disabled", true)
			if _t >= respawn_time:
				_reset()


func _reset() -> void:
	_state = State.SOLID
	position = _home
	if _shape != null:
		_shape.set_deferred("disabled", false)
	if _visual != null:
		_visual.position = Vector3.ZERO
		_visual.rotation = Vector3.ZERO
		_visual.scale = Vector3.ONE * 0.2
		create_tween().tween_property(_visual, "scale", Vector3.ONE, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
