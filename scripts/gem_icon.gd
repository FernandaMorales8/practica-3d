# Icono de la gema secreta del nivel, dibujado a mano como la estrella y los
# corazones. Apagado hasta que se encuentra la gema.
extends Control

const FILL := Color(0.38, 0.82, 1, 1)
const FACET := Color(0.75, 0.95, 1, 1)
const FILL_EMPTY := Color(0.2, 0.22, 0.3, 0.55)
const OUTLINE := Color(0.04, 0.18, 0.38, 0.95)
const OUTLINE_WIDTH := 3.0

var found := false:
	set(value):
		found = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_colored_polygon(_gem(w, h, OUTLINE_WIDTH), OUTLINE)
	draw_colored_polygon(_gem(w, h, 0.0), FILL if found else FILL_EMPTY)
	if found:
		# Faceta clara en la corona para que brille.
		draw_colored_polygon(PackedVector2Array([
			Vector2(w * 0.3, h * 0.2), Vector2(w * 0.5, h * 0.2),
			Vector2(w * 0.42, h * 0.38), Vector2(w * 0.18, h * 0.38),
		]), FACET)


# Corona plana arriba y punta abajo, como un diamante de dibujo.
static func _gem(w: float, h: float, grow: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(w * 0.28 - grow * 0.5, h * 0.12 - grow),
		Vector2(w * 0.72 + grow * 0.5, h * 0.12 - grow),
		Vector2(w * 0.98 + grow, h * 0.38),
		Vector2(w * 0.5, h * 0.94 + grow),
		Vector2(w * 0.02 - grow, h * 0.38),
	])
