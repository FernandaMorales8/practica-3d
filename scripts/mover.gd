# Plataforma movil: va y vuelve entre dos puntos a velocidad constante.
#
# AnimatableBody3D + sync_to_physics hace que el CharacterBody3D que va
# encima se mueva junto con la plataforma en lugar de resbalarse.
extends AnimatableBody3D

var point_a := Vector3.ZERO
var point_b := Vector3.ZERO
var speed := 3.0

var _t := 0.0


func _ready() -> void:
	position = point_a


func _physics_process(delta: float) -> void:
	var span := point_a.distance_to(point_b)
	if span < 0.001:
		return
	_t += delta * speed / span
	var weight := pingpong(_t, 1.0)
	position = point_a.lerp(point_b, weight)
