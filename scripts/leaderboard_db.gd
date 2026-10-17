# Persistencia en SQLite: jugadores, intentos por nivel y la tabla de records.
#
# Usa la extension godot-sqlite (res://addons/godot-sqlite). La clase SQLite
# se crea con ClassDB y se llama de forma dinamica: si la extension no carga
# (otra plataforma, binario ausente), el juego sigue funcionando y la tabla
# de records se muestra como no disponible en lugar de romper el script.
#
# Modelo de datos:
#   jugadores  - un nickname por fila (sin distinguir mayusculas).
#   intentos   - cada partida de un nivel, termine como termine: completado,
#                sin vidas, sin tiempo (contrarreloj) o abandonado. "numero" es el n-esimo intento del
#                jugador en ese nivel, asi el record sabe cuantos intentos
#                costo conseguirlo.
#   v_records  - vista con el mejor intento completado (el mas rapido) de cada
#                jugador en cada nivel.
extends RefCounted

const DB_PATH := "user://aventura.db"
const SCHEMA_VERSION := 2

const RESULT_COMPLETED := "completado"
const RESULT_NO_LIVES := "sin_vidas"
const RESULT_ABANDONED := "abandonado"
const RESULT_NO_TIME := "sin_tiempo"

const NICK_MIN := 2
const NICK_MAX := 16

const SCHEMA := [
	"""CREATE TABLE IF NOT EXISTS jugadores (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		nickname TEXT NOT NULL UNIQUE COLLATE NOCASE,
		creado TEXT NOT NULL DEFAULT (datetime('now', 'localtime'))
	)""",
	"""CREATE TABLE IF NOT EXISTS intentos (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		jugador_id INTEGER NOT NULL REFERENCES jugadores(id) ON DELETE CASCADE,
		nivel INTEGER NOT NULL,
		nivel_nombre TEXT NOT NULL,
		numero INTEGER NOT NULL,
		resultado TEXT NOT NULL CHECK (resultado IN ('completado', 'sin_vidas', 'sin_tiempo', 'abandonado')),
		tiempo_ms INTEGER NOT NULL,
		estrellas INTEGER NOT NULL DEFAULT 0,
		estrellas_total INTEGER NOT NULL DEFAULT 0,
		gema INTEGER NOT NULL DEFAULT 0,
		corazones INTEGER NOT NULL DEFAULT 0,
		poderes INTEGER NOT NULL DEFAULT 0,
		caidas INTEGER NOT NULL DEFAULT 0,
		vidas_restantes INTEGER NOT NULL DEFAULT 0,
		medalla TEXT,
		fecha TEXT NOT NULL DEFAULT (datetime('now', 'localtime'))
	)""",
	"CREATE INDEX IF NOT EXISTS idx_intentos_jugador ON intentos(jugador_id, nivel)",
	"CREATE INDEX IF NOT EXISTS idx_intentos_record ON intentos(nivel, resultado, tiempo_ms)",
	"""CREATE VIEW IF NOT EXISTS v_records AS
		SELECT * FROM (
			SELECT i.*, j.nickname,
				ROW_NUMBER() OVER (
					PARTITION BY i.jugador_id, i.nivel
					ORDER BY i.tiempo_ms ASC, i.estrellas DESC, i.id ASC
				) AS orden,
				(SELECT COUNT(*) FROM intentos x
					WHERE x.jugador_id = i.jugador_id AND x.nivel = i.nivel) AS intentos_totales
			FROM intentos i
			JOIN jugadores j ON j.id = i.jugador_id
			WHERE i.resultado = 'completado'
		) WHERE orden = 1""",
]

var _db: Object = null
var _available := false


func open() -> bool:
	if _available:
		return true
	if not ClassDB.class_exists("SQLite"):
		push_warning("Extension SQLite no disponible: la tabla de records queda desactivada.")
		return false
	_db = ClassDB.instantiate("SQLite")
	_db.set("path", DB_PATH)
	# 0 = QUIET: sin volcar cada consulta a la consola.
	_db.set("verbosity_level", 0)
	_db.set("foreign_keys", true)
	if not _db.call("open_db"):
		push_warning("No se pudo abrir la base de datos: " + DB_PATH)
		_db = null
		return false
	_available = true
	_migrate()
	for statement in SCHEMA:
		_exec(statement)
	_exec("PRAGMA user_version = %d" % SCHEMA_VERSION)
	return true


# v1 -> v2: el CHECK de "resultado" no admitia 'sin_tiempo'. SQLite no deja
# cambiar un CHECK, asi que se rehace la tabla copiando los datos. La vista
# depende de la tabla: se borra y SCHEMA la vuelve a crear.
func _migrate() -> void:
	var rows := _query("PRAGMA user_version")
	var version := int(rows[0].values()[0]) if not rows.is_empty() else 0
	var has_table := not _query("SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'intentos'").is_empty()
	if not has_table or version >= 2:
		return
	_exec("BEGIN")
	_exec("DROP VIEW IF EXISTS v_records")
	_exec("ALTER TABLE intentos RENAME TO intentos_v1")
	_exec(SCHEMA[1])
	_exec("INSERT INTO intentos SELECT * FROM intentos_v1")
	_exec("DROP TABLE intentos_v1")
	_exec("COMMIT")


func close() -> void:
	if _db != null:
		_db.call("close_db")
	_db = null
	_available = false


func is_available() -> bool:
	return _available


func file_path() -> String:
	return ProjectSettings.globalize_path(DB_PATH)


# --- Jugadores ---------------------------------------------------------------

# Quita espacios sobrantes y deja solo letras, numeros, espacio, _ y -.
static func clean_nickname(raw: String) -> String:
	var allowed := RegEx.new()
	allowed.compile("[^\\p{L}\\p{N} _\\-]")
	var text := allowed.sub(raw.strip_edges(), "", true)
	while text.contains("  "):
		text = text.replace("  ", " ")
	return text.substr(0, NICK_MAX)


static func is_valid_nickname(nickname: String) -> bool:
	return nickname.length() >= NICK_MIN and nickname.length() <= NICK_MAX


# Devuelve el id del jugador, creandolo si es nuevo. -1 si no hay base.
func ensure_player(nickname: String) -> int:
	if not _available:
		return -1
	_query("INSERT OR IGNORE INTO jugadores (nickname) VALUES (?)", [nickname])
	_flush()
	var rows := _query("SELECT id FROM jugadores WHERE nickname = ?", [nickname])
	if rows.is_empty():
		return -1
	return int(rows[0]["id"])


# --- Intentos ----------------------------------------------------------------

# Guarda un intento terminado. `run` lleva las claves de la tabla intentos
# (nivel, nivel_nombre, resultado, tiempo_ms, estrellas, ...). Devuelve el
# numero de intento asignado, o 0 si no se pudo guardar.
func record_attempt(player_id: int, run: Dictionary) -> int:
	if not _available or player_id < 0:
		return 0
	var nivel := int(run.get("nivel", 1))
	var prev := _query("SELECT COUNT(*) AS n FROM intentos WHERE jugador_id = ? AND nivel = ?", [player_id, nivel])
	var numero := (int(prev[0]["n"]) if not prev.is_empty() else 0) + 1
	var ok := _exec_bound(
		"""INSERT INTO intentos (jugador_id, nivel, nivel_nombre, numero, resultado,
			tiempo_ms, estrellas, estrellas_total, gema, corazones, poderes, caidas,
			vidas_restantes, medalla)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
		[
			player_id, nivel, str(run.get("nivel_nombre", "")), numero,
			str(run.get("resultado", RESULT_ABANDONED)), int(run.get("tiempo_ms", 0)),
			int(run.get("estrellas", 0)), int(run.get("estrellas_total", 0)),
			1 if run.get("gema", false) else 0, int(run.get("corazones", 0)),
			int(run.get("poderes", 0)), int(run.get("caidas", 0)),
			int(run.get("vidas_restantes", 0)), run.get("medalla", null),
		])
	_flush()
	return numero if ok else 0


# En la version web, user:// vive en memoria y Godot lo copia a IndexedDB
# solo despues de cerrar un archivo escrito con FileAccess. SQLite escribe por
# su cuenta y eso no dispara la copia: sin esto, al recargar la pagina se
# perdian los intentos. Tras cada guardado se escribe un archivo minimo; al
# cerrarlo, Godot programa la copia de todo user://, base incluida.
const SYNC_PATH := "user://.sync"


func _flush() -> void:
	if _db == null or not OS.has_feature("web"):
		return
	var marker := FileAccess.open(SYNC_PATH, FileAccess.WRITE)
	if marker != null:
		marker.store_string(str(Time.get_unix_time_from_system()))
		marker.close()


# Mejor intento completado de un jugador en un nivel. Vacio si no hay.
func personal_best(player_id: int, nivel: int) -> Dictionary:
	var rows := _query("SELECT * FROM v_records WHERE jugador_id = ? AND nivel = ?", [player_id, nivel])
	return rows[0] if not rows.is_empty() else {}


# Puesto (1 = primero) de un tiempo en el nivel, contando un record por jugador.
func rank_of(nivel: int, player_id: int) -> Dictionary:
	var rows := _query(
		"""SELECT
			(SELECT COUNT(*) FROM v_records r WHERE r.nivel = ?1 AND
				(r.tiempo_ms < me.tiempo_ms OR (r.tiempo_ms = me.tiempo_ms AND r.id < me.id))) + 1 AS puesto,
			(SELECT COUNT(*) FROM v_records r WHERE r.nivel = ?1) AS total
		FROM v_records me WHERE me.nivel = ?1 AND me.jugador_id = ?2""",
		[nivel, player_id])
	return rows[0] if not rows.is_empty() else {}


# --- Consultas de la tabla ---------------------------------------------------

# Records de un nivel. sort_by: "tiempo" (por defecto) o "estrellas".
func level_board(nivel: int, sort_by: String = "tiempo", filter: String = "", limit: int = 50) -> Array:
	var order := "tiempo_ms ASC, estrellas DESC, id ASC"
	if sort_by == "estrellas":
		order = "estrellas DESC, gema DESC, tiempo_ms ASC, id ASC"
	return _query(
		"""SELECT nickname, tiempo_ms, numero, intentos_totales, estrellas, estrellas_total,
			gema, corazones, caidas, medalla, fecha
		FROM v_records WHERE nivel = ? AND nickname LIKE ?
		ORDER BY %s LIMIT ?""" % order,
		[nivel, "%" + filter + "%", limit])


# Resumen por jugador de todos los niveles: niveles completados, suma de sus
# mejores tiempos, mejores estrellas por nivel, gemas e intentos totales.
func general_board(filter: String = "", limit: int = 50) -> Array:
	return _query(
		"""WITH mejor AS (
			SELECT jugador_id, nivel, MIN(tiempo_ms) AS t, MAX(estrellas) AS e, MAX(gema) AS g
			FROM intentos WHERE resultado = 'completado'
			GROUP BY jugador_id, nivel
		), total AS (
			SELECT jugador_id, COUNT(*) AS n, SUM(caidas) AS c, SUM(tiempo_ms) AS jugado
			FROM intentos GROUP BY jugador_id
		)
		SELECT j.nickname,
			COUNT(m.nivel) AS niveles,
			COALESCE(SUM(m.t), 0) AS tiempo_ms,
			COALESCE(SUM(m.e), 0) AS estrellas,
			COALESCE(SUM(m.g), 0) AS gemas,
			t.n AS intentos, t.c AS caidas, t.jugado AS jugado_ms
		FROM jugadores j
		JOIN total t ON t.jugador_id = j.id
		LEFT JOIN mejor m ON m.jugador_id = j.id
		WHERE j.nickname LIKE ?
		GROUP BY j.id
		ORDER BY niveles DESC, estrellas DESC, gemas DESC, tiempo_ms ASC
		LIMIT ?""",
		["%" + filter + "%", limit])


# Ultimos intentos de un jugador, de cualquier resultado.
func history(nickname: String, limit: int = 40) -> Array:
	return _query(
		"""SELECT i.nivel, i.nivel_nombre, i.numero, i.resultado, i.tiempo_ms, i.estrellas,
			i.estrellas_total, i.gema, i.corazones, i.caidas, i.medalla, i.fecha
		FROM intentos i JOIN jugadores j ON j.id = i.jugador_id
		WHERE j.nickname = ?
		ORDER BY i.id DESC LIMIT ?""",
		[nickname, limit])


# Mejor marca del jugador en cada nivel, indexada por nivel (1..n).
func player_records(nickname: String) -> Dictionary:
	var out := {}
	for row in _query("SELECT * FROM v_records WHERE nickname = ?", [nickname]):
		out[int(row["nivel"])] = row
	return out


# --- Utilidades --------------------------------------------------------------

# 83456 ms -> "1:23.45"
static func format_time(ms: int) -> String:
	var total := maxi(ms, 0)
	var minutes := total / 60000
	var seconds := (total / 1000) % 60
	var hundredths := (total % 1000) / 10
	return "%d:%02d.%02d" % [minutes, seconds, hundredths]


func _exec(sql: String) -> bool:
	if _db == null:
		return false
	var ok: bool = _db.call("query", sql)
	if not ok:
		push_warning("SQLite: " + str(_db.get("error_message")))
	return ok


func _exec_bound(sql: String, bindings: Array) -> bool:
	if _db == null:
		return false
	var ok: bool = _db.call("query_with_bindings", sql, bindings)
	if not ok:
		push_warning("SQLite: " + str(_db.get("error_message")))
	return ok


func _query(sql: String, bindings: Array = []) -> Array:
	if not _exec_bound(sql, bindings):
		return []
	var result: Variant = _db.get("query_result")
	return (result as Array).duplicate() if result is Array else []
