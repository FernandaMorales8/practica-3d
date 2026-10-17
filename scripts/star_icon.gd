# Icono de estrella del contador, dibujado a mano como los corazones: asi no
# depende de que la fuente tenga el glifo.
extends Control

const FILL := Color(1, 0.84, 0.25, 1)
const SHINE := Color(1, 0.95, 0.65, 1)
const OUTLINE := Color(0.42, 0.24, 0.02, 0.95)
const OUTLINE_WIDTH := 3.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var center := size * 0.5 + Vector2(0, size.y * 0.04)
	var outer := minf(size.x, size.y) * 0.5 - OUTLINE_WIDTH
	draw_colored_polygon(_star(center, outer, 0.48, OUTLINE_WIDTH), OUTLINE)
	draw_colored_polygon(_star(center, outer, 0.48, 0.0), FILL)
	# Brillo pequeno en la mitad superior para darle volumen.
	draw_colored_polygon(_star(center - Vector2(0, outer * 0.12), outer * 0.42, 0.48, 0.0), SHINE)


# Cinco puntas, con la primera hacia arriba. `grow` engorda la forma para el
# contorno.
static func _star(center: Vector2, outer: float, inner_ratio: float, grow: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 10:
		var radius := (outer if i % 2 == 0 else outer * inner_ratio) + grow
		var angle := -PI * 0.5 + i * PI / 5.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points
