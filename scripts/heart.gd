# Un corazon de vida dibujado a mano: dos circulos y un triangulo.
# Se dibuja en codigo para no depender de que la fuente tenga el glifo.
extends Control

const FILL_FULL := Color(0.93, 0.2, 0.3, 1)
const FILL_EMPTY := Color(0.2, 0.22, 0.3, 0.55)
const OUTLINE := Color(0.3, 0.06, 0.12, 0.95)
const OUTLINE_WIDTH := 3.0

var filled := true:
	set(value):
		filled = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	# Primero el contorno (forma ensanchada) y encima el relleno.
	_draw_heart(OUTLINE, OUTLINE_WIDTH)
	_draw_heart(FILL_FULL if filled else FILL_EMPTY, 0.0)


func _draw_heart(color: Color, grow: float) -> void:
	var w := size.x
	var h := size.y
	var r := w * 0.26 + grow
	draw_circle(Vector2(w * 0.28, h * 0.34), r, color)
	draw_circle(Vector2(w * 0.72, h * 0.34), r, color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(w * 0.03 - grow, h * 0.42),
		Vector2(w * 0.97 + grow, h * 0.42),
		Vector2(w * 0.5, h * 0.95 + grow),
	]), color)
