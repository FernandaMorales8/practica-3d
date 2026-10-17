# Resorte: al pisarlo lanza al jugador hacia arriba.
#
# No usa body_entered: un jugador que se queda encima y vuelve a caer sobre el
# muelle no "entra" de nuevo en el area. Se revisa en cada paso de fisica
# quien esta dentro y se lanza solo si va hacia abajo o esta apoyado.
extends Area3D

signal bounced(node: Node)

## Velocidad vertical del lanzamiento (m/s). Con gravedad 20 sube ~7 m.
@export var launch_speed := 17.0
@export var cooldown := 0.35

var _cooldown := 0.0
var _visual: Node3D = null


func _ready() -> void:
	add_to_group("spring")
	_visual = get_node_or_null("Visual")


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if _cooldown > 0.0:
		return
	for body in get_overlapping_bodies():
		if not body.is_in_group("player") or not body.has_method("launch"):
			continue
		if body.velocity.y > 0.5:
			continue
		if body.call("launch", launch_speed):
			_cooldown = cooldown
			_squash()
			bounced.emit(self)


# El muelle se aplasta y rebota para que se note el empujon.
func _squash() -> void:
	if _visual == null:
		return
	_visual.scale = Vector3(1.25, 0.45, 1.25)
	var tween := create_tween()
	tween.tween_property(_visual, "scale", Vector3(0.9, 1.25, 0.9), 0.1)
	tween.tween_property(_visual, "scale", Vector3.ONE, 0.35) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
