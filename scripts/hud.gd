# Interfaz de progreso: nivel, contador de estrellas, gema, vidas, tiempo,
# mensajes y el rotulo grande de celebracion. Tambien la pantalla de inicio
# (con el nickname y un resumen de records), la tabla de records completa, el
# boton de pausa y el menu de pausa: solo emiten senales, la logica y las
# consultas a la base de datos viven en main.gd.
extends CanvasLayer

signal start_pressed
signal level_selected(index: int)
signal quit_pressed
signal pause_pressed
signal resume_pressed
signal restart_pressed
signal menu_pressed
signal next_pressed
## Pide filas para la tabla. target: "preview" (pantalla de inicio) o "full".
## tab: "1".."3" (nivel), "general" o "historial".
signal board_query(target: String, tab: String, sort_by: String, filter: String)

const BANNER_FONT_SIZE := 64
const HeartScript := preload("res://scripts/heart.gd")
const HEART_SIZE := Vector2(32, 30)
const DB := preload("res://scripts/leaderboard_db.gd")

const GOLD_TEXT := Color(1, 0.94, 0.55, 1)
const ME_TEXT := Color(0.6, 0.92, 1, 1)
const DIM_TEXT := Color(1, 1, 1, 0.7)
const RESULT_TEXT := {"completado": "Completado", "sin_vidas": "Sin vidas", "sin_tiempo": "Sin tiempo", "abandonado": "Abandonado"}
const TRIAL_CARD_COLOR := Color(0.55, 0.16, 0.12, 0.95)
const TRIAL_CARD_EDGE := Color(1, 0.55, 0.25, 1)
const COUNTDOWN_CALM := Color(1, 1, 1, 1)
const COUNTDOWN_WARN := Color(1, 0.72, 0.25, 1)
const COUNTDOWN_PANIC := Color(1, 0.3, 0.25, 1)

@onready var _level_label: Label = $Root/TopPill/TopBar/LevelLabel
@onready var _star_label: Label = $Root/TopPill/TopBar/Stars/StarLabel
@onready var _star_icon: Control = $Root/TopPill/TopBar/Stars/StarIcon
@onready var _hearts: HBoxContainer = $Root/TopPill/TopBar/Hearts
@onready var _message: Label = $Root/Message
@onready var _hint: Label = $Root/Hint
@onready var _dim: ColorRect = $Root/Dim
@onready var _pause_panel: Panel = $Root/PausePanel
@onready var _pause_button: Button = $Root/PauseButton
@onready var _resume_button: Button = $Root/PausePanel/Box/ResumeButton
@onready var _start_screen: Control = $Root/StartScreen
@onready var _title: Label = $Root/StartScreen/Columns/Box/Title
@onready var _start_button: Button = $Root/StartScreen/Columns/Box/StartButton
@onready var _level_buttons: HBoxContainer = $Root/StartScreen/Columns/Box/LevelButtons
@onready var _nick_edit: LineEdit = $Root/StartScreen/Columns/Box/NickRow/NickEdit
@onready var _nick_error: Label = $Root/StartScreen/Columns/Box/NickError
@onready var _preview_tabs: HBoxContainer = $Root/StartScreen/Columns/BoardPreview/Box/Tabs
@onready var _preview_rows: GridContainer = $Root/StartScreen/Columns/BoardPreview/Box/Rows
@onready var _welcome: Label = $Root/StartScreen/Columns/BoardPreview/Box/Welcome
@onready var _gem_icon: Control = $Root/TopPill/TopBar/Gems/GemIcon
@onready var _time_label: Label = $Root/TopPill/TopBar/TimeLabel
@onready var _power_label: Label = $Root/PowerLabel
@onready var _win_panel: Panel = $Root/WinPanel
@onready var _win_text: Label = $Root/WinPanel/Box/WinText
@onready var _next_button: Button = $Root/WinPanel/Box/NextButton

var _message_tween: Tween = null
var _banner_tween: Tween = null
var _star_tween: Tween = null
var _banner: Label = null
var _lives_shown := -1
var _title_tween: Tween = null
# Tween de escala de cada boton, para cortar el anterior al cambiar de estado.
var _button_tweens := {}
var _lives_card: PanelContainer = null
var _lives_card_hearts: HBoxContainer = null
var _lives_card_text: Label = null
var _lives_card_tween: Tween = null
var _water_overlay: ColorRect = null
var _water_tween: Tween = null
var _preview_tab := "1"
# Tabla completa, construida en codigo.
var _board_panel: Panel = null
var _board_grid: GridContainer = null
var _board_filter: LineEdit = null
var _board_path: Label = null
var _board_tab_buttons := {}
var _board_sort_buttons := {}
var _board_tab := "1"
var _board_sort := "tiempo"
var _me := ""
# Pestanas de nivel: [id, corto, largo]. main.gd las fija con set_level_tabs.
var _level_tabs: Array = [["1", "N1", "Nivel 1"], ["2", "N2", "Nivel 2"], ["3", "N3", "Nivel 3"]]
var _level_total := 3
var _gem_levels := 3
var _full_tabs_box: HBoxContainer = null
var _trial_label: Label = null
var _trial_buttons: HBoxContainer = null
# Contrarreloj.
var _countdown: Label = null
var _countdown_tween: Tween = null
var _countdown_second := -1
var _vignette: TextureRect = null
var _flash: ColorRect = null
var _trial_mode := false


# El rotulo de celebracion se crea en codigo para no tocar la escena.
func _ready() -> void:
	# Los botones tienen que responder con el arbol en pausa.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_start_button.pressed.connect(start_pressed.emit)
	$Root/StartScreen/Columns/Box/QuitButton.pressed.connect(quit_pressed.emit)
	$Root/StartScreen/Columns/BoardPreview/Box/FullBoardButton.pressed.connect(open_board)
	_nick_edit.text_submitted.connect(func(_t: String) -> void: start_pressed.emit())
	_nick_edit.text_changed.connect(func(_t: String) -> void: _nick_error.text = "")
	_style_line_edit(_nick_edit)
	_pause_button.pressed.connect(pause_pressed.emit)
	_resume_button.pressed.connect(resume_pressed.emit)
	$Root/PausePanel/Box/RestartButton.pressed.connect(restart_pressed.emit)
	$Root/PausePanel/Box/MenuButton.pressed.connect(menu_pressed.emit)
	_next_button.pressed.connect(next_pressed.emit)
	$Root/WinPanel/Box/WinMenuButton.pressed.connect(menu_pressed.emit)

	for button in find_children("*", "Button", true, false):
		_add_button_juice(button)

	var root := get_node_or_null("Root")
	if root == null:
		return

	_banner = Label.new()
	_banner.name = "Banner"
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.anchor_left = 0.0
	_banner.anchor_right = 1.0
	_banner.anchor_top = 0.0
	_banner.anchor_bottom = 0.0
	_banner.offset_left = 0.0
	_banner.offset_right = 0.0
	_banner.offset_top = 120.0
	_banner.offset_bottom = 230.0
	_banner.add_theme_font_size_override("font_size", BANNER_FONT_SIZE)
	_banner.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_banner.add_theme_color_override("font_outline_color", Color(0.06, 0.1, 0.2, 1))
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.modulate.a = 0.0
	_banner.visible = false
	root.add_child(_banner)

	_build_water_overlay(root)
	_build_hurry_fx(root)
	_build_lives_card(root)
	_build_trial_row()
	# En la web no hay ventana que cerrar.
	if OS.has_feature("web"):
		$Root/StartScreen/Columns/Box/QuitButton.visible = false
	_build_preview_tabs()
	_build_board(root)

	# Desde la victoria tambien se puede consultar la tabla.
	var win_board := Button.new()
	win_board.name = "WinBoardButton"
	win_board.text = "Ver records"
	win_board.custom_minimum_size = Vector2(0, 44)
	win_board.theme_type_variation = &"SecondaryButton"
	win_board.add_theme_font_size_override("font_size", 22)
	win_board.pressed.connect(open_board)
	_add_button_juice(win_board)
	var win_box := $Root/WinPanel/Box
	win_box.add_child(win_board)
	win_box.move_child(win_board, $Root/WinPanel/Box/WinMenuButton.get_index())


# Escape cierra la tabla completa antes que cualquier otra cosa.
func _unhandled_input(event: InputEvent) -> void:
	if _board_panel != null and _board_panel.visible and event.is_action_pressed("ui_cancel"):
		close_board()
		get_viewport().set_input_as_handled()


func set_level(current: int, total: int, level_name: String, prefix: String = "Nivel") -> void:
	_level_label.text = "%s %d/%d  -  %s" % [prefix, current, total, level_name]


func set_stars(collected: int, total: int) -> void:
	_star_label.text = "%d / %d" % [collected, total]


# Un corazon por vida: llenos los que quedan, apagados los perdidos.
func set_lives(lives: int, max_lives: int) -> void:
	while _hearts.get_child_count() < max_lives:
		var heart := HeartScript.new()
		heart.custom_minimum_size = HEART_SIZE
		heart.pivot_offset = HEART_SIZE * 0.5
		_hearts.add_child(heart)
	while _hearts.get_child_count() > max_lives:
		var extra := _hearts.get_child(_hearts.get_child_count() - 1)
		_hearts.remove_child(extra)
		extra.queue_free()
	for i in max_lives:
		_hearts.get_child(i).filled = i < lives
	# El corazon que se acaba de perder da un pequeno latido.
	if _lives_shown > lives and lives >= 0 and lives < max_lives:
		var lost: Control = _hearts.get_child(lives)
		lost.scale = Vector2(1.5, 1.5)
		var tween := create_tween()
		tween.tween_property(lost, "scale", Vector2.ONE, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_lives_shown = lives


func show_message(text: String, hold: float = 1.6) -> void:
	_message.text = text
	_message.modulate.a = 1.0
	if _message_tween != null and _message_tween.is_valid():
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(hold)
	_message_tween.tween_property(_message, "modulate:a", 0.0, 0.5)


# Rotulo grande y centrado: entra, se mantiene y se desvanece.
func show_banner(text: String, hold: float = 2.5) -> void:
	if _banner == null:
		return
	_banner.text = text
	_banner.visible = true
	_banner.modulate.a = 0.0
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2(0.5, 0.5)
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	# Entra creciendo con un rebote y sale subiendo y desvaneciendose.
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.2)
	_banner_tween.parallel().tween_property(_banner, "scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(hold)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.5)
	_banner_tween.parallel().tween_property(_banner, "scale", Vector2(1.15, 1.15), 0.5) \
		.set_ease(Tween.EASE_IN)
	_banner_tween.tween_callback(_hide_banner)


func _hide_banner() -> void:
	if _banner != null:
		_banner.visible = false


# Salto del contador cada vez que se recoge una estrella.
func pulse_stars() -> void:
	if _star_tween != null and _star_tween.is_valid():
		_star_tween.kill()
	_star_label.pivot_offset = Vector2(_star_label.size.x * 0.5, _star_label.size.y * 0.5)
	_star_label.scale = Vector2(1.35, 1.35)
	# La estrella del icono da una vuelta rapida mientras el numero salta.
	_star_icon.pivot_offset = _star_icon.size * 0.5
	_star_icon.scale = Vector2(1.4, 1.4)
	_star_icon.rotation = -0.6
	_star_tween = create_tween().set_parallel()
	_star_tween.tween_property(_star_label, "scale", Vector2.ONE, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_star_tween.tween_property(_star_icon, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_star_tween.tween_property(_star_icon, "rotation", 0.0, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func set_hint(text: String) -> void:
	_hint.text = text


# Panel de felicitaciones al llegar a la meta. En el ultimo nivel el boton
# principal pasa a ser "Jugar de nuevo".
func show_win(title: String, text: String, next_label: String) -> void:
	$Root/WinPanel/Box/WinTitle.text = title
	_win_text.text = text
	_next_button.text = next_label
	_win_panel.visible = true
	_pause_button.visible = false
	_hide_lives_card()
	_show_dim(true)
	_pop_in(_win_panel)
	_next_button.grab_focus()


func hide_win() -> void:
	_win_panel.visible = false
	_show_dim(_pause_panel.visible)


func set_paused(paused: bool) -> void:
	_pause_panel.visible = paused
	_pause_button.visible = not paused and not _start_screen.visible and not _win_panel.visible
	_show_dim(paused or _win_panel.visible)
	if paused:
		_pop_in(_pause_panel)
		_resume_button.grab_focus()


# Un boton por nivel en la pantalla de inicio. Cada elemento de `choices`
# es un diccionario con "name", "difficulty", "best" (-1 si nunca se termino)
# y "total" (estrellas del nivel).
func set_level_choices(choices: Array) -> void:
	for key in _button_tweens.keys():
		if not is_instance_valid(key):
			_button_tweens.erase(key)
	_clear_grid(_level_buttons)
	_clear_grid(_trial_buttons)
	for i in choices.size():
		var choice: Dictionary = choices[i]
		var button := Button.new()
		button.add_theme_constant_override("line_spacing", -2)
		button.custom_minimum_size = Vector2(196, 116)
		button.theme_type_variation = &"LevelCard"
		button.add_theme_font_size_override("font_size", 20)
		button.text = "%d. %s\n%s\n%s" % [i + 1, choice.get("name", "Nivel %d" % (i + 1)), choice.get("difficulty", ""), choice.get("record", "Sin completar")]
		button.pressed.connect(level_selected.emit.bind(i))
		_add_button_juice(button)
		if choice.get("trial", false):
			_style_trial_card(button)
			_trial_buttons.add_child(button)
		else:
			_level_buttons.add_child(button)
	_trial_label.visible = _trial_buttons.get_child_count() > 0


# La pantalla de inicio tapa el HUD de juego; el boton de pausa no tiene
# sentido mientras esta visible.
func set_start_screen(visible_now: bool) -> void:
	_start_screen.visible = visible_now
	if visible_now:
		_win_panel.visible = false
		_show_dim(false)
	_pause_button.visible = not visible_now and not _pause_panel.visible
	_message.visible = not visible_now
	_hint.visible = not visible_now
	if visible_now:
		close_board()
		_hide_lives_card()
		_countdown.visible = false
		_vignette.modulate.a = 0.0
		_power_label.visible = false
		if _nick_edit.text.strip_edges() == "":
			_nick_edit.grab_focus()
		else:
			_start_button.grab_focus()
		_fade_in(_start_screen)
		board_query.emit("preview", _preview_tab, "tiempo", "")
		_start_title_bob()
	elif _title_tween != null and _title_tween.is_valid():
		_title_tween.kill()


func set_time(ms: int) -> void:
	_time_label.text = DB.format_time(ms)


func set_gem(found: bool) -> void:
	_gem_icon.found = found
	if found:
		_gem_icon.pivot_offset = _gem_icon.size * 0.5
		_gem_icon.scale = Vector2(1.7, 1.7)
		create_tween().tween_property(_gem_icon, "scale", Vector2.ONE, 0.45) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# Cuenta atras del Super salto; con 0 se oculta.
func set_power(seconds: float) -> void:
	_power_label.visible = seconds > 0.0
	if seconds > 0.0:
		_power_label.text = "Super salto  %d s" % ceili(seconds)
		# Parpadea en los ultimos segundos para avisar de que se acaba.
		_power_label.modulate.a = 1.0 if seconds > 3.0 or fmod(seconds, 0.5) > 0.2 else 0.35


# --- Contrarreloj ------------------------------------------------------------------

# Fila de tarjetas de contrarreloj debajo de las de la aventura.
func _build_trial_row() -> void:
	var box := _level_buttons.get_parent()
	_trial_label = Label.new()
	_trial_label.text = "CONTRARRELOJ  -  corre antes de que suba la marea"
	_trial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_trial_label.add_theme_font_size_override("font_size", 20)
	_trial_label.add_theme_color_override("font_color", COUNTDOWN_WARN)
	box.add_child(_trial_label)
	box.move_child(_trial_label, _level_buttons.get_index() + 1)
	_trial_buttons = HBoxContainer.new()
	_trial_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_trial_buttons.add_theme_constant_override("separation", 12)
	box.add_child(_trial_buttons)
	box.move_child(_trial_buttons, _trial_label.get_index() + 1)


# Las tarjetas de contrarreloj son rojizas: se distinguen de un vistazo.
func _style_trial_card(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		# Se lee del contenedor, que ya esta en el arbol y hereda el tema; el
		# boton recien creado todavia no.
		var base := _trial_buttons.get_theme_stylebox(state, &"LevelCard")
		if not (base is StyleBoxFlat):
			continue
		var box := base.duplicate() as StyleBoxFlat
		if state == "normal" or state == "focus":
			box.bg_color = TRIAL_CARD_COLOR
		else:
			box.bg_color = TRIAL_CARD_COLOR.lightened(0.15)
		box.border_color = TRIAL_CARD_EDGE
		button.add_theme_stylebox_override(state, box)


func _build_hurry_fx(root: Control) -> void:
	# Bordes rojos que laten cuando queda poco tiempo.
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 0.1, 0.05, 0.0))
	gradient.add_point(0.55, Color(1, 0.1, 0.05, 0.0))
	gradient.set_color(gradient.get_point_count() - 1, Color(0.9, 0.05, 0.02, 0.85))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.05, 1.05)
	texture.width = 256
	texture.height = 256
	_vignette = TextureRect.new()
	_vignette.name = "Vignette"
	_vignette.texture = texture
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.anchor_right = 1.0
	_vignette.anchor_bottom = 1.0
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate.a = 0.0
	root.add_child(_vignette)
	root.move_child(_vignette, 1)

	# Destello blanco de los relampagos.
	_flash = ColorRect.new()
	_flash.name = "Flash"
	_flash.color = Color(0.9, 0.95, 1, 1)
	_flash.anchor_right = 1.0
	_flash.anchor_bottom = 1.0
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.modulate.a = 0.0
	root.add_child(_flash)
	root.move_child(_flash, 1)

	# Cuenta atras grande bajo la barra superior.
	_countdown = Label.new()
	_countdown.name = "Countdown"
	_countdown.visible = false
	_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown.anchor_left = 0.5
	_countdown.anchor_right = 0.5
	_countdown.offset_left = -160
	_countdown.offset_right = 160
	_countdown.offset_top = 70
	_countdown.offset_bottom = 140
	_countdown.add_theme_font_size_override("font_size", 58)
	_countdown.add_theme_constant_override("outline_size", 12)
	_countdown.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.1, 1))
	_countdown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_countdown)


## En contrarreloj no hay vidas ni gema: se ve la cuenta atras.
func set_trial_mode(on: bool) -> void:
	_trial_mode = on
	$Root/TopPill/TopBar/Hearts.visible = not on
	$Root/TopPill/TopBar/Gems.visible = not on
	_countdown.visible = on
	_countdown_second = -1
	# Los mensajes bajan para no taparse con la cuenta atras y el rotulo.
	_message.offset_top = 236.0 if on else 108.0
	_message.offset_bottom = _message.offset_top + 54.0
	if not on:
		_vignette.modulate.a = 0.0


# Cuenta atras: blanca, naranja con menos de 10 s y roja con menos de 5.
# Cada segundo de los ultimos 10 el numero da un golpe y los bordes laten.
func set_countdown(seconds: float, limit: float) -> void:
	if _countdown == null or not _trial_mode:
		return
	var left := maxf(seconds, 0.0)
	_countdown.text = "%d.%d" % [floori(left), floori(fmod(left, 1.0) * 10.0)] if left < 10.0 else "%d" % ceili(left)
	var color := COUNTDOWN_CALM
	if left <= 5.0:
		color = COUNTDOWN_PANIC
	elif left <= 10.0:
		color = COUNTDOWN_WARN
	_countdown.add_theme_color_override("font_color", color)

	var urgency := clampf(1.0 - left / 10.0, 0.0, 1.0)
	var beat := fmod(left, 1.0)
	# Latido: maximo justo al cambiar de segundo y se apaga enseguida.
	var pulse := pow(beat, 3.0) if left <= 10.0 else 0.0
	_vignette.modulate.a = urgency * (0.35 + 0.45 * pulse)

	var second := ceili(left)
	if left <= 10.0 and second != _countdown_second:
		_countdown_second = second
		_countdown.pivot_offset = _countdown.size * 0.5
		_countdown.scale = Vector2.ONE * (1.25 + urgency * 0.25)
		if _countdown_tween != null and _countdown_tween.is_valid():
			_countdown_tween.kill()
		_countdown_tween = create_tween()
		_countdown_tween.tween_property(_countdown, "scale", Vector2.ONE, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	elif left > 10.0:
		_countdown_second = -1


## "+3 s" en verde o "-3 s" en rojo, que sale de la cuenta atras y se va.
func show_time_delta(seconds: float) -> void:
	if _countdown == null:
		return
	var label := Label.new()
	label.text = ("+%d s" if seconds > 0.0 else "%d s") % roundi(seconds)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_constant_override("outline_size", 9)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1, 1))
	label.add_theme_color_override("font_color", Color(0.5, 1, 0.55) if seconds > 0.0 else COUNTDOWN_PANIC)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = _countdown.position + Vector2(_countdown.size.x * 0.5 + 70, 10)
	_countdown.get_parent().add_child(label)
	var tween := create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y + (-40.0 if seconds > 0.0 else 40.0), 0.9)
	tween.tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)
	# La cuenta atras tambien reacciona.
	_countdown.pivot_offset = _countdown.size * 0.5
	_countdown.scale = Vector2.ONE * (1.3 if seconds > 0.0 else 0.85)
	create_tween().tween_property(_countdown, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func flash(strength: float = 0.5) -> void:
	if _flash == null:
		return
	_flash.modulate.a = strength
	var tween := create_tween()
	tween.tween_property(_flash, "modulate:a", 0.0, 0.08)
	tween.tween_property(_flash, "modulate:a", strength * 0.6, 0.06)
	tween.tween_property(_flash, "modulate:a", 0.0, 0.35)


# --- Vidas al reaparecer -------------------------------------------------------

func _build_lives_card(root: Control) -> void:
	_lives_card = PanelContainer.new()
	_lives_card.name = "LivesCard"
	_lives_card.theme_type_variation = &"HudPill"
	_lives_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lives_card.visible = false
	_lives_card.anchor_left = 0.5
	_lives_card.anchor_right = 0.5
	_lives_card.anchor_top = 0.3
	_lives_card.anchor_bottom = 0.3
	_lives_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_lives_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(_lives_card)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	_lives_card.add_child(box)

	_lives_card_text = Label.new()
	_lives_card_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lives_card_text.add_theme_font_size_override("font_size", 34)
	_lives_card_text.add_theme_color_override("font_color", GOLD_TEXT)
	box.add_child(_lives_card_text)

	_lives_card_hearts = HBoxContainer.new()
	_lives_card_hearts.alignment = BoxContainer.ALIGNMENT_CENTER
	_lives_card_hearts.add_theme_constant_override("separation", 10)
	box.add_child(_lives_card_hearts)


# Tarjeta centrada con las vidas que quedan, al reaparecer tras una caida.
func show_lives_card(lives: int, max_lives: int) -> void:
	if _lives_card == null:
		return
	if lives == 1:
		_lives_card_text.text = "¡Ultima vida!"
	else:
		_lives_card_text.text = "Vidas restantes: %d" % lives
	for child in _lives_card_hearts.get_children():
		child.queue_free()
	for i in max_lives:
		var heart := HeartScript.new()
		heart.custom_minimum_size = HEART_SIZE * 1.4
		heart.filled = i < lives
		_lives_card_hearts.add_child(heart)

	_lives_card.visible = true
	_lives_card.reset_size()
	_lives_card.pivot_offset = _lives_card.size * 0.5
	_lives_card.scale = Vector2(0.6, 0.6)
	_lives_card.modulate.a = 0.0
	if _lives_card_tween != null and _lives_card_tween.is_valid():
		_lives_card_tween.kill()
	_lives_card_tween = create_tween()
	_lives_card_tween.tween_property(_lives_card, "modulate:a", 1.0, 0.15)
	_lives_card_tween.parallel().tween_property(_lives_card, "scale", Vector2.ONE, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_lives_card_tween.tween_interval(1.6)
	_lives_card_tween.tween_property(_lives_card, "modulate:a", 0.0, 0.4)
	_lives_card_tween.tween_callback(func() -> void: _lives_card.visible = false)


func _hide_lives_card() -> void:
	if _lives_card_tween != null and _lives_card_tween.is_valid():
		_lives_card_tween.kill()
	if _lives_card != null:
		_lives_card.visible = false


# --- Agua -----------------------------------------------------------------------

func _build_water_overlay(root: Control) -> void:
	_water_overlay = ColorRect.new()
	_water_overlay.name = "WaterOverlay"
	_water_overlay.color = Color(0.04, 0.24, 0.45, 1)
	_water_overlay.anchor_right = 1.0
	_water_overlay.anchor_bottom = 1.0
	_water_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_water_overlay.modulate.a = 0.0
	_water_overlay.visible = false
	root.add_child(_water_overlay)
	# Detras de todo el HUD: tine el juego, no los textos.
	root.move_child(_water_overlay, 0)


# Al hundirse la pantalla se tine de azul; al reaparecer se aclara.
func set_underwater(on: bool) -> void:
	if _water_overlay == null:
		return
	if _water_tween != null and _water_tween.is_valid():
		_water_tween.kill()
	_water_overlay.visible = true
	_water_tween = create_tween()
	if on:
		_water_tween.tween_property(_water_overlay, "modulate:a", 0.55, 1.2) \
			.set_ease(Tween.EASE_IN)
	else:
		_water_tween.tween_property(_water_overlay, "modulate:a", 0.0, 0.45)
		_water_tween.tween_callback(func() -> void: _water_overlay.visible = false)


# --- Nickname --------------------------------------------------------------------

func get_nickname() -> String:
	return _nick_edit.text


func set_nickname(nickname: String) -> void:
	_nick_edit.text = nickname
	_me = nickname


func show_nick_error(text: String) -> void:
	_nick_error.text = text
	_nick_edit.grab_focus()
	# Pequena sacudida del campo para que se vea donde esta el problema.
	var row := _nick_edit.get_parent() as Control
	var tween := create_tween()
	for offset in [12.0, -10.0, 6.0, 0.0]:
		tween.tween_property(row, "position:x", row.position.x + offset, 0.05)


func set_welcome(text: String) -> void:
	_welcome.text = text


func _style_line_edit(edit: LineEdit) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.09, 0.13, 0.29, 0.94)
	box.border_color = Color(1, 0.8, 0.26, 1)
	box.set_border_width_all(2)
	box.set_corner_radius_all(12)
	box.content_margin_left = 12
	box.content_margin_right = 12
	var focus := box.duplicate() as StyleBoxFlat
	focus.border_color = Color(0.6, 0.92, 1, 1)
	focus.set_border_width_all(3)
	edit.add_theme_stylebox_override("normal", box)
	edit.add_theme_stylebox_override("focus", focus)
	edit.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	edit.add_theme_color_override("font_placeholder_color", Color(1, 1, 1, 0.45))
	edit.add_theme_color_override("caret_color", GOLD_TEXT)


# --- Tabla de records: resumen en la pantalla de inicio -----------------------------

## Pestanas de cada nivel ([id, nombre corto, nombre largo]) y totales para
## la tabla general.
func set_level_tabs(tabs: Array, level_total: int, gem_levels: int) -> void:
	_level_tabs = tabs
	_level_total = level_total
	_gem_levels = gem_levels
	_build_preview_tabs()
	_build_full_tabs()


func _build_preview_tabs() -> void:
	_clear_grid(_preview_tabs)
	for tab in _level_tabs + [["general", "Gral", "General"]]:
		var button := Button.new()
		button.text = tab[1]
		button.custom_minimum_size = Vector2(62, 34)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 16)
		button.set_meta("tab", tab[0])
		button.pressed.connect(func() -> void:
			_preview_tab = tab[0]
			_style_tabs(_preview_tabs.get_children(), _preview_tab)
			board_query.emit("preview", _preview_tab, "tiempo", ""))
		_preview_tabs.add_child(button)
	_style_tabs(_preview_tabs.get_children(), _preview_tab)


# Filas del resumen: los 5 primeros del nivel (o de la general).
func set_board_preview(tab: String, rows: Array, available: bool) -> void:
	_clear_grid(_preview_rows)
	if not available:
		_preview_rows.columns = 1
		_add_cell(_preview_rows, "Base de datos no disponible", DIM_TEXT, 18)
		return
	if tab == "general":
		_preview_rows.columns = 4
		for h in ["#", "Jugador", "Niveles", "Estrellas"]:
			_add_cell(_preview_rows, h, GOLD_TEXT, 18)
		for i in rows.size():
			var r: Dictionary = rows[i]
			var color := _row_color(r)
			_add_cell(_preview_rows, str(i + 1), color, 18)
			_add_cell(_preview_rows, str(r["nickname"]), color, 18, true)
			_add_cell(_preview_rows, "%d / %d" % [int(r["niveles"]), _level_total], color, 18)
			_add_cell(_preview_rows, str(r["estrellas"]), color, 18)
	else:
		_preview_rows.columns = 4
		for h in ["#", "Jugador", "Tiempo", "Estrellas"]:
			_add_cell(_preview_rows, h, GOLD_TEXT, 18)
		for i in rows.size():
			var r: Dictionary = rows[i]
			var color := _row_color(r)
			_add_cell(_preview_rows, str(i + 1), color, 18)
			_add_cell(_preview_rows, str(r["nickname"]), color, 18, true)
			_add_cell(_preview_rows, DB.format_time(int(r["tiempo_ms"])), color, 18)
			_add_cell(_preview_rows, "%d/%d%s" % [int(r["estrellas"]), int(r["estrellas_total"]), "  +gema" if int(r["gema"]) == 1 else ""], color, 18)
	if rows.is_empty():
		for text in ["", "Sin records aun", "", ""]:
			_add_cell(_preview_rows, text, DIM_TEXT, 18)


# --- Tabla de records completa -----------------------------------------------------

func _build_board(root: Control) -> void:
	_board_panel = Panel.new()
	_board_panel.name = "BoardPanel"
	_board_panel.visible = false
	_board_panel.anchor_left = 0.5
	_board_panel.anchor_right = 0.5
	_board_panel.anchor_top = 0.5
	_board_panel.anchor_bottom = 0.5
	_board_panel.offset_left = -500
	_board_panel.offset_right = 500
	_board_panel.offset_top = -300
	_board_panel.offset_bottom = 300
	root.add_child(_board_panel)

	var box := VBoxContainer.new()
	box.anchor_right = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = 28
	box.offset_right = -28
	box.offset_top = 18
	box.offset_bottom = -18
	box.add_theme_constant_override("separation", 10)
	_board_panel.add_child(box)

	var title := Label.new()
	title.text = "TABLA DE RECORDS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", GOLD_TEXT)
	box.add_child(title)

	_full_tabs_box = HBoxContainer.new()
	_full_tabs_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_full_tabs_box.add_theme_constant_override("separation", 6)
	box.add_child(_full_tabs_box)
	_build_full_tabs()

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 10)
	box.add_child(tools)
	var search := Label.new()
	search.text = "Buscar jugador:"
	search.add_theme_font_size_override("font_size", 18)
	tools.add_child(search)
	_board_filter = LineEdit.new()
	_board_filter.custom_minimum_size = Vector2(240, 36)
	_board_filter.placeholder_text = "nickname"
	_board_filter.add_theme_font_size_override("font_size", 18)
	_board_filter.clear_button_enabled = true
	_style_line_edit(_board_filter)
	_board_filter.text_changed.connect(func(_t: String) -> void: _refresh_board())
	tools.add_child(_board_filter)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(spacer)
	var order := Label.new()
	order.text = "Ordenar:"
	order.add_theme_font_size_override("font_size", 18)
	tools.add_child(order)
	for sort in [["tiempo", "Tiempo"], ["estrellas", "Estrellas"]]:
		var button := Button.new()
		button.text = sort[1]
		button.custom_minimum_size = Vector2(120, 36)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 18)
		button.set_meta("tab", sort[0])
		button.pressed.connect(func() -> void:
			_board_sort = sort[0]
			_refresh_board())
		tools.add_child(button)
		_board_sort_buttons[sort[0]] = button

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_board_grid = GridContainer.new()
	_board_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board_grid.add_theme_constant_override("h_separation", 18)
	_board_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_board_grid)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	box.add_child(footer)
	_board_path = Label.new()
	_board_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board_path.add_theme_font_size_override("font_size", 14)
	_board_path.add_theme_color_override("font_color", DIM_TEXT)
	_board_path.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	footer.add_child(_board_path)
	var close := Button.new()
	close.text = "Cerrar"
	close.custom_minimum_size = Vector2(160, 44)
	close.add_theme_font_size_override("font_size", 22)
	close.pressed.connect(close_board)
	_add_button_juice(close)
	footer.add_child(close)


func _build_full_tabs() -> void:
	if _full_tabs_box == null:
		return
	_clear_grid(_full_tabs_box)
	_board_tab_buttons.clear()
	for tab in _level_tabs + [["general", "General", "General"], ["historial", "Historial", "Mi historial"]]:
		var button := Button.new()
		button.text = tab[2]
		button.custom_minimum_size = Vector2(122, 40)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 17)
		button.set_meta("tab", tab[0])
		button.pressed.connect(func() -> void:
			_board_tab = tab[0]
			_refresh_board())
		_full_tabs_box.add_child(button)
		_board_tab_buttons[tab[0]] = button


func open_board() -> void:
	if _board_panel == null:
		return
	_board_panel.visible = true
	_show_dim(true)
	_pop_in(_board_panel)
	_refresh_board()


func close_board() -> void:
	if _board_panel == null or not _board_panel.visible:
		return
	_board_panel.visible = false
	_show_dim(_pause_panel.visible or _win_panel.visible)


func is_board_open() -> bool:
	return _board_panel != null and _board_panel.visible


func _refresh_board() -> void:
	_style_tabs(_board_tab_buttons.values(), _board_tab)
	_style_tabs(_board_sort_buttons.values(), _board_sort)
	# Ordenar solo tiene sentido en las tablas de nivel.
	for button in _board_sort_buttons.values():
		button.disabled = not _board_tab.is_valid_int()
	_board_filter.editable = _board_tab != "historial"
	board_query.emit("full", _board_tab, _board_sort, _board_filter.text.strip_edges())


# Rellena la tabla completa. `rows` llega ya consultado por main.gd.
func set_board_rows(tab: String, rows: Array, available: bool, db_path: String) -> void:
	if tab != _board_tab:
		return
	_clear_grid(_board_grid)
	_board_path.text = "Base de datos: " + db_path if available else "Base de datos no disponible (extension SQLite sin cargar)"
	if not available:
		_board_grid.columns = 1
		return
	var size := 18
	match tab:
		"general":
			var headers := ["#", "Jugador", "Niveles", "Suma mejores tiempos", "Estrellas", "Gemas", "Intentos", "Caidas"]
			_board_grid.columns = headers.size()
			for h in headers:
				_add_cell(_board_grid, h, GOLD_TEXT, size)
			for i in rows.size():
				var r: Dictionary = rows[i]
				var color := _row_color(r)
				var total_time := DB.format_time(int(r["tiempo_ms"])) if int(r["niveles"]) > 0 else "-"
				for cell in [str(i + 1), str(r["nickname"]), "%d / %d" % [int(r["niveles"]), _level_total], total_time,
						str(r["estrellas"]), "%d / %d" % [int(r["gemas"]), _gem_levels], str(r["intentos"]), str(r["caidas"])]:
					_add_cell(_board_grid, cell, color, size, cell == str(r["nickname"]))
		"historial":
			var headers := ["Nivel", "Intento", "Resultado", "Tiempo", "Estrellas", "Gema", "Corazones", "Caidas", "Fecha"]
			_board_grid.columns = headers.size()
			for h in headers:
				_add_cell(_board_grid, h, GOLD_TEXT, size)
			for r in rows:
				var res := str(r["resultado"])
				var color := ME_TEXT if res == "completado" else Color(1, 1, 1, 0.9)
				for cell in ["%d. %s" % [int(r["nivel"]), r["nivel_nombre"]], "#%d" % int(r["numero"]),
						RESULT_TEXT.get(res, res), DB.format_time(int(r["tiempo_ms"])),
						"%d/%d" % [int(r["estrellas"]), int(r["estrellas_total"])],
						"Si" if int(r["gema"]) == 1 else "-", str(r["corazones"]), str(r["caidas"]),
						str(r["fecha"]).substr(0, 16)]:
					_add_cell(_board_grid, cell, color, size)
		_:
			var headers := ["#", "Jugador", "Tiempo", "Medalla", "Intentos hasta record", "Estrellas", "Gema", "Caidas", "Fecha"]
			_board_grid.columns = headers.size()
			for h in headers:
				_add_cell(_board_grid, h, GOLD_TEXT, size)
			for i in rows.size():
				var r: Dictionary = rows[i]
				var color := _row_color(r)
				var medal: Variant = r.get("medalla")
				for cell in [str(i + 1), str(r["nickname"]), DB.format_time(int(r["tiempo_ms"])),
						str(medal) if medal != null else "-",
						"%d de %d" % [int(r["numero"]), int(r["intentos_totales"])],
						"%d/%d" % [int(r["estrellas"]), int(r["estrellas_total"])],
						"Si" if int(r["gema"]) == 1 else "-", str(r["caidas"]), str(r["fecha"]).substr(0, 16)]:
					_add_cell(_board_grid, cell, color, size, cell == str(r["nickname"]))
	if rows.is_empty():
		var empty := Label.new()
		empty.text = "Sin registros todavia." if tab != "historial" else "Aun no has jugado con este nickname."
		empty.add_theme_color_override("font_color", DIM_TEXT)
		empty.add_theme_font_size_override("font_size", 18)
		_board_grid.add_child(empty)


func _row_color(row: Dictionary) -> Color:
	return ME_TEXT if _me != "" and str(row.get("nickname", "")).to_lower() == _me.to_lower() else Color(1, 1, 1, 1)


func _add_cell(grid: GridContainer, text: String, color: Color, font_size: int, expand: bool = false) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 4)
	if expand:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.custom_minimum_size.x = 90
	grid.add_child(label)


static func _clear_grid(grid: Container) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()


# La pestana activa se ve como boton dorado; las demas, azules.
static func _style_tabs(buttons: Array, selected: String) -> void:
	for button in buttons:
		button.theme_type_variation = &"" if button.get_meta("tab") == selected else &"SecondaryButton"


# --- Animaciones de la interfaz ----------------------------------------------

# Las ventanas entran creciendo desde el centro con un pequeno rebote.
func _pop_in(panel: Control) -> void:
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.85, 0.85)
	panel.modulate.a = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(panel, "scale", Vector2.ONE, 0.32) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.18)


func _fade_in(control: Control) -> void:
	control.modulate.a = 0.0
	create_tween().tween_property(control, "modulate:a", 1.0, 0.35)


# Fondo oscuro detras de pausa y victoria: separa la ventana del juego.
func _show_dim(on: bool) -> void:
	if on == _dim.visible:
		return
	_dim.visible = on
	if on:
		_fade_in(_dim)


# El titulo respira y se balancea despacio mientras el menu esta abierto.
func _start_title_bob() -> void:
	if _title_tween != null and _title_tween.is_valid():
		_title_tween.kill()
	# El VBox recoloca al titulo, pero no toca escala ni giro: se anima eso.
	await get_tree().process_frame
	_title.pivot_offset = _title.size * 0.5
	_title_tween = create_tween().set_loops()
	_title_tween.tween_property(_title, "scale", Vector2(1.04, 1.04), 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_title_tween.parallel().tween_property(_title, "rotation", deg_to_rad(1.5), 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_title_tween.tween_property(_title, "scale", Vector2.ONE, 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_title_tween.parallel().tween_property(_title, "rotation", deg_to_rad(-1.5), 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# Los botones crecen un poco con el raton encima o con el foco del teclado,
# y se encogen al pulsarlos.
func _add_button_juice(button: Button) -> void:
	button.mouse_entered.connect(_scale_button.bind(button, 1.06))
	button.focus_entered.connect(_scale_button.bind(button, 1.06))
	button.mouse_exited.connect(_on_button_released.bind(button))
	button.focus_exited.connect(_on_button_released.bind(button))
	button.button_down.connect(_scale_button.bind(button, 0.96))
	button.button_up.connect(_on_button_released.bind(button))


func _on_button_released(button: Button) -> void:
	var over := button.get_global_rect().has_point(button.get_global_mouse_position())
	_scale_button(button, 1.06 if over or button.has_focus() else 1.0)


func _scale_button(button: Button, target: float) -> void:
	if not is_instance_valid(button):
		return
	var old: Tween = _button_tweens.get(button)
	if old != null and old.is_valid():
		old.kill()
	button.pivot_offset = button.size * 0.5
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2(target, target), 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_button_tweens[button] = tween
