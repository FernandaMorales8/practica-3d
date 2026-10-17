# Plataforma Turbo: al pisar la flecha el jugador sale disparado hacia
# delante (-Z del bloque) con mas velocidad durante un momento.
extends Area3D

signal boosted(node: Node)

@export var duration := 1.5

var _cooldown := 0.0


func _ready() -> void:
	add_to_group("boost_pad")


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if _cooldown > 0.0:
		return
	for body in get_overlapping_bodies():
		if not body.is_in_group("player") or not body.has_method("apply_turbo"):
			continue
		var forward := -global_transform.basis.z
		forward.y = 0.0
		if body.call("apply_turbo", duration, forward.normalized()):
			_cooldown = 0.5
			boosted.emit(self)
