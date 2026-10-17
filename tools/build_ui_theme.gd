# Genera res://ui/theme.tres, el tema global de la interfaz.
#
# Uso (desde la carpeta del proyecto):
#   godot --headless --path . -s res://tools/build_ui_theme.gd
#
# El .tres resultante tambien se puede retocar a mano en el editor de temas;
# si se vuelve a ejecutar este script, esos retoques se pierden.
extends SceneTree

const FONT_PATH := "res://assets/fonts/Fredoka.ttf"
const OUT_PATH := "res://ui/theme.tres"

# Paleta: azul noche de los paneles, crema de los bordes y el dorado de las
# estrellas para la accion principal.
const NAVY := Color(0.09, 0.13, 0.29, 0.94)
const NAVY_LIGHT := Color(0.16, 0.24, 0.48, 1)
const NAVY_EDGE := Color(0.05, 0.08, 0.19, 1)
const CREAM := Color(1, 0.94, 0.76, 1)
const GOLD := Color(1, 0.8, 0.26, 1)
const GOLD_HOVER := Color(1, 0.88, 0.42, 1)
const GOLD_PRESSED := Color(0.95, 0.71, 0.18, 1)
const GOLD_EDGE := Color(0.78, 0.47, 0.08, 1)
const BROWN := Color(0.32, 0.17, 0.04, 1)
const SKY := Color(0.36, 0.62, 0.95, 1)
const SKY_HOVER := Color(0.47, 0.71, 1, 1)
const SKY_PRESSED := Color(0.3, 0.54, 0.86, 1)
const SKY_EDGE := Color(0.16, 0.32, 0.62, 1)


func _initialize() -> void:
	var theme := Theme.new()

	var base: FontFile = load(FONT_PATH)
	var font := FontVariation.new()
	font.base_font = base
	# Fredoka es una fuente variable: se fija el peso en semi-negrita.
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
	theme.default_font = font
	theme.default_font_size = 22

	_label(theme)
	_panels(theme)
	_buttons(theme, "Button", GOLD, GOLD_HOVER, GOLD_PRESSED, GOLD_EDGE, BROWN)
	_buttons(theme, "SecondaryButton", SKY, SKY_HOVER, SKY_PRESSED, SKY_EDGE, Color.WHITE)
	theme.set_type_variation("SecondaryButton", "Button")
	_level_card(theme)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_PATH.get_base_dir()))
	var err := ResourceSaver.save(theme, OUT_PATH)
	if err != OK:
		push_error("No se pudo guardar el tema: %d" % err)
	else:
		print("Tema guardado en ", OUT_PATH)
	quit()


func _label(theme: Theme) -> void:
	theme.set_color("font_color", "Label", Color.WHITE)
	theme.set_color("font_outline_color", "Label", NAVY_EDGE)
	theme.set_constant("outline_size", "Label", 6)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.28))
	theme.set_constant("shadow_offset_x", "Label", 0)
	theme.set_constant("shadow_offset_y", "Label", 3)


func _panels(theme: Theme) -> void:
	# Ventanas: esquinas grandes, borde crema y sombra que las despega del juego.
	var panel := _box(NAVY, 26)
	panel.set_border_width_all(4)
	panel.border_color = CREAM
	panel.shadow_color = Color(0, 0, 0, 0.35)
	panel.shadow_size = 18
	panel.shadow_offset = Vector2(0, 10)
	theme.set_stylebox("panel", "Panel", panel)

	# Pildora translucida detras de los contadores del HUD.
	var pill := _box(Color(0.06, 0.1, 0.24, 0.55), 22)
	pill.set_border_width_all(2)
	pill.border_color = Color(1, 1, 1, 0.18)
	pill.content_margin_left = 22
	pill.content_margin_right = 22
	pill.content_margin_top = 8
	pill.content_margin_bottom = 8
	theme.set_stylebox("panel", "HudPill", pill)
	theme.set_type_variation("HudPill", "PanelContainer")


# Botones con canto inferior grueso: al pulsarlos el canto se reduce y el
# texto baja, como una tecla que se hunde.
func _buttons(theme: Theme, type_name: String, fill: Color, hover: Color, pressed: Color, edge: Color, text: Color) -> void:
	var normal := _button_box(fill, edge, 6)
	normal.shadow_color = Color(0, 0, 0, 0.25)
	normal.shadow_size = 6
	normal.shadow_offset = Vector2(0, 4)
	var hovered := normal.duplicate() as StyleBoxFlat
	hovered.bg_color = hover
	var down := _button_box(pressed, edge, 2)
	down.content_margin_top += 4
	var disabled := _button_box(fill.darkened(0.35), edge.darkened(0.35), 6)

	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.set_border_width_all(3)
	focus.border_color = Color(1, 1, 1, 0.95)
	focus.set_corner_radius_all(20)
	focus.set_expand_margin_all(4)

	theme.set_stylebox("normal", type_name, normal)
	theme.set_stylebox("hover", type_name, hovered)
	theme.set_stylebox("pressed", type_name, down)
	theme.set_stylebox("hover_pressed", type_name, down)
	theme.set_stylebox("disabled", type_name, disabled)
	theme.set_stylebox("focus", type_name, focus)

	for item in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		theme.set_color(item, type_name, text)
	theme.set_color("font_disabled_color", type_name, Color(text, 0.5))
	theme.set_color("font_outline_color", type_name, Color(0, 0, 0, 0))
	theme.set_constant("outline_size", type_name, 0)


# Tarjetas de nivel de la pantalla de inicio: azules, con el borde crema de
# las ventanas y un tono dorado al pasar por encima.
func _level_card(theme: Theme) -> void:
	var normal := _button_box(NAVY_LIGHT, NAVY_EDGE, 6)
	normal.set_border_width(SIDE_LEFT, 3)
	normal.set_border_width(SIDE_TOP, 3)
	normal.set_border_width(SIDE_RIGHT, 3)
	normal.border_color = CREAM.darkened(0.15)
	normal.content_margin_top = 12
	normal.content_margin_bottom = 18
	var hovered := normal.duplicate() as StyleBoxFlat
	hovered.bg_color = NAVY_LIGHT.lightened(0.12)
	hovered.border_color = GOLD
	var down := hovered.duplicate() as StyleBoxFlat
	down.set_border_width(SIDE_BOTTOM, 3)
	down.content_margin_top = 15
	down.content_margin_bottom = 15

	theme.set_type_variation("LevelCard", "Button")
	theme.set_stylebox("normal", "LevelCard", normal)
	theme.set_stylebox("hover", "LevelCard", hovered)
	theme.set_stylebox("pressed", "LevelCard", down)
	theme.set_stylebox("hover_pressed", "LevelCard", down)
	for item in ["font_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(item, "LevelCard", Color.WHITE)
	theme.set_color("font_hover_color", "LevelCard", GOLD_HOVER)
	theme.set_color("font_hover_pressed_color", "LevelCard", GOLD_HOVER)


func _box(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	return box


func _button_box(fill: Color, edge: Color, bottom: int) -> StyleBoxFlat:
	var box := _box(fill, 16)
	box.border_color = edge
	box.set_border_width(SIDE_BOTTOM, bottom)
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 8
	# Los margenes de contenido sustituyen al grosor del borde, no se suman:
	# el canto inferior va incluido aqui.
	box.content_margin_bottom = 8 + bottom
	return box
