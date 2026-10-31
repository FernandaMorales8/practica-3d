# Administrador de configuraciones de usuario (controles tactiles, haptica, etc.)
# Guarda y carga las preferencias en user://settings.cfg.
class_name SettingsManager
extends RefCounted

const SETTINGS_PATH := "user://settings.cfg"

# Valores por defecto segun la especificacion de la Practica 6
const DEFAULT_TOUCH_OPACITY := 0.65       # Rango: 0.2 a 1.0
const DEFAULT_TOUCH_SCALE := 1.0          # Multiplicador: 0.8 a 1.4 (tamano base >= 96 px)
const DEFAULT_JOYSTICK_DEADZONE := 0.20   # Rango: 0.10 a 0.35
const DEFAULT_JOYSTICK_RADIUS := 100.0    # Pixeles base (80 a 120 px)
const DEFAULT_HAPTICS_ENABLED := true     # Vibracion haptica activada
const DEFAULT_TOUCH_DEBUG := false        # Mostrar controles en PC para pruebas

# Duraciones de vibracion haptica de referencia (en milisegundos)
const VIB_PICKUP_MS := 40
const VIB_JUMP_MS := 45
const VIB_BOOST_MS := 65
const VIB_DAMAGE_MS := 95

static var touch_opacity: float = DEFAULT_TOUCH_OPACITY
static var touch_scale: float = DEFAULT_TOUCH_SCALE
static var joystick_deadzone: float = DEFAULT_JOYSTICK_DEADZONE
static var joystick_radius: float = DEFAULT_JOYSTICK_RADIUS
static var haptics_enabled: bool = DEFAULT_HAPTICS_ENABLED
static var touch_debug: bool = DEFAULT_TOUCH_DEBUG

static var _loaded := false


static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_PATH)
	if err != OK:
		# Archivo no existe aun; se usan los valores por defecto
		return

	touch_opacity = float(config.get_value("touch", "opacity", DEFAULT_TOUCH_OPACITY))
	touch_scale = float(config.get_value("touch", "scale", DEFAULT_TOUCH_SCALE))
	joystick_deadzone = float(config.get_value("touch", "deadzone", DEFAULT_JOYSTICK_DEADZONE))
	joystick_radius = float(config.get_value("touch", "radius", DEFAULT_JOYSTICK_RADIUS))
	haptics_enabled = bool(config.get_value("haptics", "enabled", DEFAULT_HAPTICS_ENABLED))
	touch_debug = bool(config.get_value("touch", "debug_pc", DEFAULT_TOUCH_DEBUG))


static func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("touch", "opacity", touch_opacity)
	config.set_value("touch", "scale", touch_scale)
	config.set_value("touch", "deadzone", joystick_deadzone)
	config.set_value("touch", "radius", joystick_radius)
	config.set_value("haptics", "enabled", haptics_enabled)
	config.set_value("touch", "debug_pc", touch_debug)

	var err := config.save(SETTINGS_PATH)
	if err != OK:
		push_warning("No se pudo guardar la configuracion en %s: %d" % [SETTINGS_PATH, err])


## Ejecuta una vibracion haptica en el dispositivo si esta activada
static func vibrate(duration_ms: int) -> void:
	if not haptics_enabled:
		return
	if duration_ms <= 0:
		return
	# Input.vibrate_handheld solo tiene efecto en plataformas que lo soporten (Android, iOS)
	Input.vibrate_handheld(duration_ms)
