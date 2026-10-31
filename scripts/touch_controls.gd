# Controles tactiles para dispositivos moviles (Practica 6)
# Implementa:
# 1. Joystick virtual flotante/ergonomico con zona muerta y radio ajustable.
# 2. Boton tactil de salto grande (>= 96 px) compatible con multitouch.
# 3. Zona de control de camara tactil en la mitad derecha de la pantalla.
# 4. Capa de entrada unificada: inyecta directamente al Input Map (move_*, jump).
# 5. Deteccion de pantalla tactil y modo depuracion para PC (F1 / toggle).
# 6. Adaptacion a Safe Area (notches, bordes redondeados).
# 7. Menu de ajustes en tiempo real (opacidad, tamano, zona muerta, haptica).
extends CanvasLayer

signal settings_closed

const Settings := preload("res://scripts/settings_manager.gd")

# Constantes de ergonomia
const BASE_JOYSTICK_RADIUS := 90.0
const BASE_HANDLE_RADIUS := 38.0
const BASE_BUTTON_RADIUS := 54.0   # Diametro 108 px (cumple >= 96 px)
const MARGIN_BOTTOM := 70.0
const MARGIN_SIDE := 80.0
const LOOK_SENSITIVITY := 0.0035

# Indices multitouch (-1 = libre)
var _stick_touch_id := -1
var _jump_touch_id := -1
var _look_touch_id := -1

# Coordenadas locales y centros
var _stick_center := Vector2.ZERO
var _stick_handle_pos := Vector2.ZERO
var _jump_center := Vector2.ZERO
var _jump_pressed := false

# Safe area insets
var _safe_insets := Rect2(0, 0, 0, 0)

# Referencias
var _camera_rig: Node3D = null
var _settings_panel: PanelContainer = null
var _settings_button: Button = null

# Contenedor de controles dibujados
var _draw_control: Control = null


func _ready() -> void:
	layer = 15  # Por encima del mundo y bajo dialogos criticos
	Settings.load_settings()

	# Conectar evento de cambio de tamano de pantalla para safe area
	get_viewport().size_changed.connect(_on_viewport_resized)

	_build_ui()
	_update_safe_area()
	_update_visibility()


func set_camera_rig(cam: Node3D) -> void:
	_camera_rig = cam


func _unhandled_key_input(event: InputEvent) -> void:
	# Tecla rapida F1 en PC para alternar controles tactiles de depuracion
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			Settings.touch_debug = not Settings.touch_debug
			Settings.save_settings()
			_update_visibility()
			get_viewport().set_input_as_handled()


func _on_viewport_resized() -> void:
	_update_safe_area()
	_recalculate_positions()
	if _draw_control != null:
		_draw_control.queue_redraw()


func _update_safe_area() -> void:
	var safe_rect: Rect2i = DisplayServer.get_display_safe_area()
	var window_size: Vector2i = DisplayServer.window_get_size()
	if window_size.x > 0 and window_size.y > 0:
		var view_size := get_viewport().get_visible_rect().size
		var scale_x := view_size.x / float(window_size.x)
		var scale_y := view_size.y / float(window_size.y)
		_safe_insets = Rect2(
			safe_rect.position.x * scale_x,
			safe_rect.position.y * scale_y,
			(window_size.x - safe_rect.end.x) * scale_x,
			(window_size.y - safe_rect.end.y) * scale_y
		)
	else:
		_safe_insets = Rect2(0, 0, 0, 0)


func _update_visibility() -> void:
	# Deteccion de dispositivo movil nativo (Android o iOS) o navegador web en movil/tablet
	var is_mobile_os: bool = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	var is_mobile_web: bool = OS.has_feature("web") and DisplayServer.is_touchscreen_available()
	# En PC permanece oculto por defecto para jugar limpiamente con teclado y raton.
	# Solo se muestra si se activa el modo de depuracion en PC (tecla F1 o en el menu de Ajustes).
	var should_show: bool = is_mobile_os or is_mobile_web or Settings.touch_debug
	visible = should_show
	set_process_input(should_show)
	set_process_unhandled_input(true)


func set_gameplay_active(active: bool) -> void:
	# Durante menus de pausa, inicio o felicitaciones se ocultan los controles del juego
	if _draw_control != null:
		_draw_control.visible = active
	if _settings_button != null:
		_settings_button.visible = active
	if not active:
		_release_all_inputs()


func _build_ui() -> void:
	# Control raiz para dibujar el joystick y el boton de salto
	_draw_control = Control.new()
	_draw_control.name = "TouchDraw"
	_draw_control.anchor_right = 1.0
	_draw_control.anchor_bottom = 1.0
	_draw_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_control.draw.connect(_on_draw_controls)
	add_child(_draw_control)

	# Boton para abrir los Ajustes de Controles Tactiles
	_settings_button = Button.new()
	_settings_button.name = "TouchSettingsButton"
	_settings_button.text = "⚙ Controles"
	_settings_button.focus_mode = Control.FOCUS_NONE
	_settings_button.anchor_left = 1.0
	_settings_button.anchor_right = 1.0
	_settings_button.offset_left = -290.0
	_settings_button.offset_top = 16.0
	_settings_button.offset_right = -174.0
	_settings_button.offset_bottom = 58.0
	_settings_button.theme_type_variation = &"SecondaryButton"
	_settings_button.pressed.connect(open_settings_panel)
	add_child(_settings_button)

	_build_settings_panel()
	_recalculate_positions()


func _recalculate_positions() -> void:
	var view_size := get_viewport().get_visible_rect().size
	var scale := Settings.touch_scale

	# Posicion del joystick en la esquina inferior izquierda (con insets)
	var stick_x := MARGIN_SIDE + _safe_insets.position.x + (BASE_JOYSTICK_RADIUS * scale)
	var stick_y := view_size.y - MARGIN_BOTTOM - _safe_insets.size.y - (BASE_JOYSTICK_RADIUS * scale)
	_stick_center = Vector2(stick_x, stick_y)
	if _stick_touch_id == -1:
		_stick_handle_pos = _stick_center

	# Posicion del boton de salto en la esquina inferior derecha (con insets)
	var jump_x := view_size.x - MARGIN_SIDE - _safe_insets.size.x - (BASE_BUTTON_RADIUS * scale)
	var jump_y := view_size.y - MARGIN_BOTTOM - _safe_insets.size.y - (BASE_BUTTON_RADIUS * scale)
	_jump_center = Vector2(jump_x, jump_y)


# --- DIBUJADO DE CONTROLES TACTILES ---

func _on_draw_controls() -> void:
	if not visible or not _draw_control.visible:
		return

	var opacity := Settings.touch_opacity
	var scale := Settings.touch_scale
	var stick_r := BASE_JOYSTICK_RADIUS * scale
	var handle_r := BASE_HANDLE_RADIUS * scale
	var jump_r := BASE_BUTTON_RADIUS * scale

	# 1. Base del Joystick
	var base_col := Color(0.12, 0.16, 0.28, opacity * 0.5)
	var ring_col := Color(0.8, 0.9, 1.0, opacity * 0.75)
	_draw_control.draw_circle(_stick_center, stick_r, base_col)
	_draw_control.draw_arc(_stick_center, stick_r, 0.0, TAU, 36, ring_col, 3.0 * scale)

	# Circulo interior de zona muerta (guia visual sutil)
	var deadzone_r := stick_r * Settings.joystick_deadzone
	_draw_control.draw_arc(_stick_center, deadzone_r, 0.0, TAU, 24, Color(1, 1, 1, opacity * 0.25), 1.5 * scale)

	# Perilla del Joystick (Handle)
	var handle_col := Color(0.3, 0.6, 1.0, opacity * 0.85) if _stick_touch_id != -1 else Color(0.7, 0.8, 0.95, opacity * 0.7)
	_draw_control.draw_circle(_stick_handle_pos, handle_r, handle_col)
	_draw_control.draw_arc(_stick_handle_pos, handle_r, 0.0, TAU, 28, Color(1, 1, 1, opacity * 0.9), 2.5 * scale)

	# 2. Boton de Salto
	var jump_base_col := Color(0.15, 0.45, 0.85, opacity * 0.85) if _jump_pressed else Color(0.12, 0.2, 0.38, opacity * 0.6)
	var jump_ring_col := Color(1.0, 0.92, 0.5, opacity * 0.95) if _jump_pressed else Color(0.85, 0.92, 1.0, opacity * 0.8)
	var current_jump_r := jump_r * (0.92 if _jump_pressed else 1.0)
	_draw_control.draw_circle(_jump_center, current_jump_r, jump_base_col)
	_draw_control.draw_arc(_jump_center, current_jump_r, 0.0, TAU, 36, jump_ring_col, 3.5 * scale)

	# Flecha/icono de salto en el boton
	var icon_color := Color(1, 1, 1, opacity * 0.95)
	_draw_jump_arrow(_jump_center, current_jump_r * 0.45, icon_color)


func _draw_jump_arrow(center: Vector2, half_h: float, col: Color) -> void:
	# Dibuja flecha apuntando arriba
	var tip := center + Vector2(0, -half_h)
	var left := center + Vector2(-half_h * 0.75, half_h * 0.1)
	var right := center + Vector2(half_h * 0.75, half_h * 0.1)
	var stem_left := center + Vector2(-half_h * 0.28, half_h * 0.1)
	var stem_right := center + Vector2(half_h * 0.28, half_h * 0.1)
	var stem_bottom_l := center + Vector2(-half_h * 0.28, half_h * 0.9)
	var stem_bottom_r := center + Vector2(half_h * 0.28, half_h * 0.9)

	var points: PackedVector2Array = [tip, right, stem_right, stem_bottom_r, stem_bottom_l, stem_left, left]
	_draw_control.draw_colored_polygon(points, col)


# --- MANEJO DE ENTRADAS MULTITOUCH Y UNIFICACION CON INPUT MAP ---

func _input(event: InputEvent) -> void:
	if not visible or not _draw_control.visible:
		return

	# Si el panel de ajustes esta abierto, no procesar controles de juego
	if _settings_panel != null and _settings_panel.visible:
		return

	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	var pos := event.position
	var scale := Settings.touch_scale
	var stick_r := BASE_JOYSTICK_RADIUS * scale
	var jump_r := BASE_BUTTON_RADIUS * scale
	var view_size := get_viewport().get_visible_rect().size

	if event.pressed:
		# 1. Comprobar boton de salto
		if pos.distance_to(_jump_center) <= jump_r * 1.3:
			_jump_touch_id = event.index
			_jump_pressed = true
			Input.action_press("jump")
			Input.action_press("jump_primary")
			Settings.vibrate(Settings.VIB_JUMP_MS)
			_draw_control.queue_redraw()
			return

		# 2. Comprobar joystick (mitad izquierda inferior)
		if pos.x < view_size.x * 0.45 and pos.y > view_size.y * 0.35:
			if _stick_touch_id == -1:
				_stick_touch_id = event.index
				# Permitir que el joystick sea semi-dinamico si se pulsa cerca
				if pos.distance_to(_stick_center) < stick_r * 2.0:
					_stick_handle_pos = pos
				_update_stick_input(pos)
				_draw_control.queue_redraw()
				return

		# 3. Comprobar zona de camara (mitad derecha, fuera de botones)
		if pos.x >= view_size.x * 0.4 and pos.y > 70.0:
			if _look_touch_id == -1 and _jump_touch_id != event.index:
				_look_touch_id = event.index
				return

	else:
		# Liberar toques
		if event.index == _jump_touch_id:
			_jump_touch_id = -1
			_jump_pressed = false
			Input.action_release("jump")
			Input.action_release("jump_primary")
			_draw_control.queue_redraw()

		if event.index == _stick_touch_id:
			_stick_touch_id = -1
			_stick_handle_pos = _stick_center
			_release_move_inputs()
			_draw_control.queue_redraw()

		if event.index == _look_touch_id:
			_look_touch_id = -1


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if event.index == _stick_touch_id:
		_update_stick_input(event.position)
		_draw_control.queue_redraw()
	elif event.index == _look_touch_id:
		# Rotar la camara con el pulgar derecho
		if _camera_rig != null and _camera_rig.has_method("rotate_yaw_relative"):
			_camera_rig.rotate_yaw_relative(event.relative.x * LOOK_SENSITIVITY)


func _update_stick_input(touch_pos: Vector2) -> void:
	var scale := Settings.touch_scale
	var max_r := BASE_JOYSTICK_RADIUS * scale
	var offset := touch_pos - _stick_center
	var dist := offset.length()

	if dist > max_r:
		offset = offset.normalized() * max_r
		dist = max_r

	_stick_handle_pos = _stick_center + offset

	var norm := dist / max_r
	var deadzone := Settings.joystick_deadzone

	if norm < deadzone:
		_release_move_inputs()
		return

	# Normalizar fuerza entre deadzone y 1.0
	var factor := (norm - deadzone) / (1.0 - deadzone)
	var dir := offset.normalized() * factor

	# Inyectar al Input Map unificado
	# X: izquierda (-) / derecha (+)
	if dir.x < -0.05:
		Input.action_press("move_left", absf(dir.x))
		Input.action_release("move_right")
	elif dir.x > 0.05:
		Input.action_press("move_right", dir.x)
		Input.action_release("move_left")
	else:
		Input.action_release("move_left")
		Input.action_release("move_right")

	# Y: arriba/adelante (-) / abajo/atras (+)
	if dir.y < -0.05:
		Input.action_press("move_forward", absf(dir.y))
		Input.action_release("move_back")
	elif dir.y > 0.05:
		Input.action_press("move_back", dir.y)
		Input.action_release("move_forward")
	else:
		Input.action_release("move_forward")
		Input.action_release("move_back")


func _release_move_inputs() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_forward")
	Input.action_release("move_back")


func _release_all_inputs() -> void:
	_stick_touch_id = -1
	_jump_touch_id = -1
	_look_touch_id = -1
	_jump_pressed = false
	_stick_handle_pos = _stick_center
	_release_move_inputs()
	Input.action_release("jump")
	Input.action_release("jump_primary")
	if _draw_control != null:
		_draw_control.queue_redraw()


# --- PANEL DE AJUSTES DE CONTROLES TACTILES ---

func _build_settings_panel() -> void:
	_settings_panel = PanelContainer.new()
	_settings_panel.name = "TouchSettingsPanel"
	_settings_panel.visible = false
	_settings_panel.anchor_left = 0.5
	_settings_panel.anchor_top = 0.5
	_settings_panel.anchor_right = 0.5
	_settings_panel.anchor_bottom = 0.5
	_settings_panel.offset_left = -260.0
	_settings_panel.offset_top = -240.0
	_settings_panel.offset_right = 260.0
	_settings_panel.offset_bottom = 240.0
	_settings_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_settings_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	_settings_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	# Titulo
	var title := Label.new()
	title.text = "AJUSTES DE CONTROLES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1, 0.92, 0.55))
	box.add_child(title)

	# 1. Opacidad
	var op_row := HBoxContainer.new()
	var op_lbl := Label.new()
	op_lbl.text = "Opacidad:"
	op_lbl.custom_minimum_size = Vector2(140, 0)
	var op_val_lbl := Label.new()
	op_val_lbl.text = "%d %%" % int(Settings.touch_opacity * 100)
	op_val_lbl.custom_minimum_size = Vector2(50, 0)
	var op_slider := HSlider.new()
	op_slider.min_value = 0.2
	op_slider.max_value = 1.0
	op_slider.step = 0.05
	op_slider.value = Settings.touch_opacity
	op_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	op_slider.value_changed.connect(func(v: float) -> void:
		Settings.touch_opacity = v
		op_val_lbl.text = "%d %%" % int(v * 100)
		_draw_control.queue_redraw()
	)
	op_row.add_child(op_lbl)
	op_row.add_child(op_slider)
	op_row.add_child(op_val_lbl)
	box.add_child(op_row)

	# 2. Tamano / Escala
	var sz_row := HBoxContainer.new()
	var sz_lbl := Label.new()
	sz_lbl.text = "Tamano:"
	sz_lbl.custom_minimum_size = Vector2(140, 0)
	var sz_val_lbl := Label.new()
	sz_val_lbl.text = "%.1fx" % Settings.touch_scale
	sz_val_lbl.custom_minimum_size = Vector2(50, 0)
	var sz_slider := HSlider.new()
	sz_slider.min_value = 0.8
	sz_slider.max_value = 1.4
	sz_slider.step = 0.05
	sz_slider.value = Settings.touch_scale
	sz_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sz_slider.value_changed.connect(func(v: float) -> void:
		Settings.touch_scale = v
		sz_val_lbl.text = "%.1fx" % v
		_recalculate_positions()
		_draw_control.queue_redraw()
	)
	sz_row.add_child(sz_lbl)
	sz_row.add_child(sz_slider)
	sz_row.add_child(sz_val_lbl)
	box.add_child(sz_row)

	# 3. Zona Muerta (Deadzone)
	var dz_row := HBoxContainer.new()
	var dz_lbl := Label.new()
	dz_lbl.text = "Zona muerta:"
	dz_lbl.custom_minimum_size = Vector2(140, 0)
	var dz_val_lbl := Label.new()
	dz_val_lbl.text = "%.2f" % Settings.joystick_deadzone
	dz_val_lbl.custom_minimum_size = Vector2(50, 0)
	var dz_slider := HSlider.new()
	dz_slider.min_value = 0.10
	dz_slider.max_value = 0.35
	dz_slider.step = 0.02
	dz_slider.value = Settings.joystick_deadzone
	dz_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dz_slider.value_changed.connect(func(v: float) -> void:
		Settings.joystick_deadzone = v
		dz_val_lbl.text = "%.2f" % v
		_draw_control.queue_redraw()
	)
	dz_row.add_child(dz_lbl)
	dz_row.add_child(dz_slider)
	dz_row.add_child(dz_val_lbl)
	box.add_child(dz_row)

	# 4. Vibracion haptica
	var vib_check := CheckButton.new()
	vib_check.text = "Vibracion haptica (movil)"
	vib_check.button_pressed = Settings.haptics_enabled
	vib_check.toggled.connect(func(on: bool) -> void:
		Settings.haptics_enabled = on
		if on:
			Settings.vibrate(Settings.VIB_PICKUP_MS)
	)
	box.add_child(vib_check)

	# 5. Modo Depuracion PC
	var dbg_check := CheckButton.new()
	dbg_check.text = "Mostrar controles tactiles en PC (Debug)"
	dbg_check.button_pressed = Settings.touch_debug
	dbg_check.toggled.connect(func(on: bool) -> void:
		Settings.touch_debug = on
		_update_visibility()
	)
	box.add_child(dbg_check)

	# Boton Cerrar / Guardar
	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	var save_btn := Button.new()
	save_btn.text = "Guardar y Cerrar"
	save_btn.custom_minimum_size = Vector2(180, 44)
	save_btn.pressed.connect(close_settings_panel)
	btn_box.add_child(save_btn)
	box.add_child(btn_box)


func open_settings_panel() -> void:
	if _settings_panel != null:
		visible = true
		_settings_panel.visible = true
		_release_all_inputs()


func close_settings_panel() -> void:
	if _settings_panel != null:
		_settings_panel.visible = false
	Settings.save_settings()
	_update_visibility()
	settings_closed.emit()
