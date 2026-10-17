# Datos de los tres niveles del juego.
#
# Convencion del pack KayKit Platformer: cada archivo se llama
#   {tipo}_{X}x{Z}x{Y}_{color}.gltf
# donde X = ancho, Z = fondo, Y = alto, medidos en metros, y el pivote
# esta en el CENTRO DE LA BASE (y = 0 en la cara inferior).
# Ejemplo verificado: platform_6x2x1 -> 6 ancho, 2 fondo, 1 alto.
#
# Direccion de avance del nivel: -Z (el jugador mira hacia -Z al arrancar).
#
# Fisica de referencia para disenar saltos (player.gd):
#   velocidad 7 m/s, salto 10 m/s, gravedad 20 m/s^2
#   -> altura maxima ~2.5 m, alcance horizontal ~7 m
# Regla de diseno: separacion entre bordes <= 5 m y desniveles <= 2 m.
#
# Objetos y rutas secundarias (cada nivel tiene al menos una):
#   "items"   - [tipo, posicion]. "heart" da una vida (max 5), "gem" es la
#               gema secreta del nivel y "power" da Super salto durante unos
#               segundos (salto de ~4.5 m en vez de 2.5 m).
#   "springs" - resortes: lanzan al jugador ~7 m hacia arriba.
# Las ramas salen a los lados del camino principal (x = 0). Algunas solo se
# alcanzan con Super salto o con un resorte; varias vuelven al camino mas
# adelante, asi el recorrido deja de ser una linea recta.
#
# "par_time" (segundos) marca las medallas: oro <= par, plata <= par * 1.5.
#
# Contrarreloj ("mode": "contrarreloj", niveles 4 y 5):
#   "time_limit"   - segundos al empezar. Al llegar a 0 la marea se traga al
#                    jugador. No hay vidas: caer cuesta "fall_penalty" segundos.
#   "time_bonus"   - segundos que da cada aro de tiempo (items "time").
#   "checkpoint_bonus" - segundos extra al activar un checkpoint.
#   "crumbles"     - bloques que se rompen y caen poco despues de pisarlos.
#   "boost_pads"   - plataformas flecha: dan Turbo (mas velocidad) un instante.
# Mientras corre el reloj la marea sube; si se gana tiempo, baja.
class_name LevelData
extends RefCounted

const BASE := "res://assets/KayKit_Platformer_Pack_1.0_FREE/Assets/gltf/"


static func levels() -> Array:
	return [_level_1(), _level_2(), _level_3(), _trial_1(), _trial_2()]


static func level_count() -> int:
	return 5


## Los tres primeros forman la aventura; el resto son contrarreloj sueltos.
const CAMPAIGN_LEVELS := 3


static func is_trial(data: Dictionary) -> bool:
	return data.get("mode", "") == "contrarreloj"


# --- Nivel 1: Prado Verde (facil) --------------------------------------------
# Plataformas anchas, saltos de 2-3 m, desniveles de 1 m.
# Segunda mitad (desde z = -52): zigzag de plataformas pequenas, una
# plataforma movil lenta y una subida final hasta la meta en z = -110.
static func _level_1() -> Dictionary:
	return {
		"name": "Prado Verde",
		"difficulty": "Facil",
		"par_time": 45.0,
		# Mediodia soleado sobre un mar turquesa.
		"theme": {
			"water_deep": Color(0.03, 0.32, 0.5),
			"water_crest": Color(0.2, 0.66, 0.76),
			"island_colors": ["green", "yellow", "blue"],
			"flag_color": "red",
		},
		"fall_y": -18.0,
		"spawn": Vector3(0, 1.2, 0),
		"blocks": [
			["platform_6x6x1", "green", 0, 0, 0],
			["platform_4x4x1", "green", 0, 0, -7],
			["platform_4x4x1", "blue", 2, 0, -13],
			["platform_4x4x1", "green", -1, 0, -19],
			["platform_6x6x1", "blue", 0, 1, -27],
			["platform_2x2x1", "yellow", 0, 1, -33],
			["platform_2x2x1", "yellow", 0, 1, -38],
			["platform_4x4x1", "green", 1, 1, -44],
			["platform_6x6x1", "yellow", 0, 2, -52],
			["platform_4x4x1", "green", 2, 2, -59],
			["platform_2x2x1", "yellow", -1, 3, -64.5],
			["platform_2x2x1", "yellow", 1.5, 3, -69.5],
			["platform_4x4x1", "blue", 0, 3, -85],
			["platform_2x2x1", "green", -2, 4, -90.5],
			["platform_2x2x1", "green", 2, 4, -95],
			["platform_4x4x1", "yellow", 0, 5, -101],
			["platform_6x6x1", "green", 0, 5, -108],
			# Secreto: detras del punto de salida.
			["platform_2x2x1", "yellow", 0, 0, 7.5],
			# Rama derecha: tres saltos hasta el resorte que lleva a la gema.
			["platform_2x2x1", "yellow", 8, 0, -13],
			["platform_2x2x1", "green", 12.5, 1, -15.5],
			["platform_4x4x1", "blue", 13, 1, -21],
			# Bucle izquierdo: sale de la plataforma grande y vuelve al zigzag,
			# con un corazon a mitad de camino.
			["platform_2x2x1", "green", -7.5, 2, -51],
			["platform_2x2x1", "yellow", -11.5, 3, -54.5],
			["platform_4x4x1", "blue", -11.5, 3, -60],
			["platform_2x2x1", "green", -6.5, 3, -63.5],
		],
		"decor": [
			["cone", "neutral", -2.5, 1, 2.0, 0.0],
			["cone", "neutral", 2.5, 1, 2.0, 0.0],
			["sign", "neutral", -1.5, 1, -6.0, 0.0],
			["cone", "neutral", -1.5, 4, -83.5, 0.0],
			["cone", "neutral", 1.5, 4, -83.5, 0.0],
			["cone", "neutral", -2.5, 6, -105.5, 0.0],
			["cone", "neutral", 2.5, 6, -105.5, 0.0],
		],
		"stars": [
			Vector3(0, 2.3, -7),
			Vector3(2, 2.3, -13),
			Vector3(-1, 2.3, -19),
			Vector3(0, 3.3, -27),
			Vector3(0, 3.3, -33),
			Vector3(0, 3.3, -38),
			Vector3(1, 3.3, -44),
			Vector3(0, 4.3, -52),
			Vector3(2, 4.3, -59),
			Vector3(-1, 5.3, -64.5),
			Vector3(1.5, 5.3, -69.5),
			Vector3(0, 5.3, -77),
			Vector3(0, 5.3, -85),
			Vector3(-2, 6.3, -90.5),
			Vector3(2, 6.3, -95),
			Vector3(0, 7.3, -101),
			Vector3(0, 2.3, 7.5),
			Vector3(8, 2.3, -13),
			Vector3(12.5, 3.3, -15.5),
			Vector3(-7.5, 4.3, -51),
			Vector3(-6.5, 5.3, -63.5),
		],
		"items": [
			["gem", Vector3(13, 8.0, -21.5)],
			["heart", Vector3(-11.5, 5.3, -60)],
		],
		"springs": [
			Vector3(13, 2, -21.5),
		],
		"checkpoints": [
			Vector3(0, 2.0, -26),
			Vector3(-1.5, 3.0, -53),
			Vector3(1, 4.0, -86),
		],
		"movers": [
			{
				"type": "platform_2x2x1", "color": "blue",
				"from": Vector3(0, 3, -74), "to": Vector3(0, 3, -80),
				"speed": 2.5,
			},
		],
		"goal": Vector3(0, 6.0, -110),
	}


# --- Nivel 2: Canon Azul (medio) ---------------------------------------------
# Plataformas de 2x2, saltos de 3-4 m, desniveles de 1-2 m, una plataforma movil.
# Segunda mitad (desde z = -66): escalera en zigzag, una plataforma movil
# lateral y una ultima subida hasta la meta en z = -117.
static func _level_2() -> Dictionary:
	return {
		"name": "Canon Azul",
		"difficulty": "Medio",
		"par_time": 55.0,
		# Tarde fresca: cielo azul intenso, sol mas alto y blanco, mar profundo.
		"theme": {
			"sky_top": Color(0.12, 0.36, 0.82),
			"sky_horizon": Color(0.7, 0.86, 0.98),
			"ground_bottom": Color(0.55, 0.68, 0.85),
			"sun_color": Color(1, 0.97, 0.92),
			"sun_energy": 1.25,
			"sun_pitch": -58.0,
			"sun_yaw": 30.0,
			"ambient": Color(0.62, 0.75, 0.95),
			"ambient_energy": 1.2,
			"fog_color": Color(0.72, 0.85, 0.97),
			"water_deep": Color(0.02, 0.15, 0.4),
			"water_crest": Color(0.12, 0.4, 0.72),
			"cloud_bottom": Color(0.78, 0.86, 0.98),
			"island_colors": ["blue", "green"],
			"flag_color": "yellow",
		},
		"fall_y": -18.0,
		"spawn": Vector3(0, 1.2, 0),
		"blocks": [
			["platform_6x6x1", "blue", 0, 0, 0],
			["platform_2x2x1", "green", -1.5, 0, -7],
			["platform_2x2x1", "green", 1.5, 0, -11],
			["platform_2x2x1", "yellow", -1.5, 1, -15],
			["platform_2x2x1", "yellow", 1.5, 1, -19],
			["platform_4x4x1", "blue", 0, 1, -25],
			["platform_4x4x1", "blue", 0, 1, -45],
			["platform_2x2x1", "yellow", -2, 2, -50],
			["platform_2x2x1", "yellow", 2, 2, -54],
			["platform_2x2x1", "yellow", 0, 2, -59],
			["platform_6x6x1", "yellow", 0, 2, -66],
			["platform_2x2x1", "green", 2, 2, -73],
			["platform_2x2x1", "green", -1, 3, -77.5],
			["platform_2x2x1", "blue", 1.5, 4, -82],
			["platform_4x4x1", "blue", 0, 4, -88],
			["platform_2x2x1", "yellow", 0, 5, -99],
			["platform_2x2x1", "green", -2, 6, -103.5],
			["platform_2x2x1", "green", 1, 6, -108],
			["platform_6x6x1", "yellow", 0, 6, -115],
			# Rama izquierda: el Super salto espera al final y es la unica forma
			# de subir 3 m hasta la gema. Desde ahi se baja de vuelta al camino
			# saltandose la plataforma movil.
			["platform_2x2x1", "yellow", -6.5, 1, -25],
			["platform_2x2x1", "green", -11, 2, -27.5],
			["platform_4x4x1", "blue", -11, 2, -33],
			["platform_2x2x1", "yellow", -11, 5, -39.5],
			["platform_2x2x1", "green", -5.5, 2, -43],
			# Rama derecha: resorte hasta un mirador alto con un corazon, y
			# bajada directa a la plataforma azul de z = -88.
			["platform_2x2x1", "green", 7, 2, -66],
			["platform_2x2x1", "blue", 11.5, 3, -68.5],
			["platform_4x4x1", "yellow", 11.5, 3, -74],
			["platform_4x4x1", "blue", 11.5, 9, -80.5],
			["platform_2x2x1", "green", 6, 8, -85.5],
		],
		"decor": [
			["cone", "neutral", -2.5, 1, 2.0, 0.0],
			["cone", "neutral", 2.5, 1, 2.0, 0.0],
			["cone", "neutral", -1.5, 2, -24.0, 0.0],
			["cone", "neutral", 1.5, 2, -24.0, 0.0],
			["cone", "neutral", -2.5, 7, -112.5, 0.0],
			["cone", "neutral", 2.5, 7, -112.5, 0.0],
		],
		"stars": [
			Vector3(-1.5, 2.3, -7),
			Vector3(1.5, 2.3, -11),
			Vector3(-1.5, 3.3, -15),
			Vector3(1.5, 3.3, -19),
			Vector3(0, 3.3, -25),
			Vector3(0, 3.3, -35),
			Vector3(0, 3.3, -45),
			Vector3(-2, 4.3, -50),
			Vector3(0, 4.3, -66),
			Vector3(2, 4.3, -73),
			Vector3(-1, 5.3, -77.5),
			Vector3(1.5, 6.3, -82),
			Vector3(0, 6.3, -94),
			Vector3(0, 7.3, -99),
			Vector3(-2, 8.3, -103.5),
			Vector3(1, 8.3, -108),
			Vector3(-6.5, 3.3, -25),
			Vector3(-5.5, 4.3, -43),
			Vector3(7, 4.3, -66),
			Vector3(6, 10.3, -85.5),
		],
		"items": [
			["power", Vector3(-11, 4.3, -33)],
			["gem", Vector3(-11, 7.3, -39.5)],
			["heart", Vector3(11.5, 11.3, -80.5)],
		],
		"springs": [
			Vector3(11.5, 4, -74),
		],
		"checkpoints": [
			Vector3(0, 2.0, -24),
			Vector3(0, 2.0, -46),
			Vector3(-1.5, 3.0, -65),
			Vector3(1, 5.0, -87),
		],
		"movers": [
			{
				"type": "platform_2x2x1", "color": "green",
				"from": Vector3(0, 1, -31), "to": Vector3(0, 1, -39),
				"speed": 3.0,
			},
			{
				"type": "platform_2x2x1", "color": "yellow",
				"from": Vector3(-3, 4, -94), "to": Vector3(3, 4, -94),
				"speed": 2.5,
			},
		],
		"goal": Vector3(0, 7.0, -117),
	}


# --- Nivel 3: Torre Roja (dificil) -------------------------------------------
# Plataformas de 1x1, saltos de 3.5-4.5 m, desniveles de 1-2 m,
# plataformas moviles laterales y verticales.
# Segunda mitad (desde z = -85): saltos sobre bloques 1x1, un ascensor que
# hay que esperar arriba y la torre final con la meta en z = -130.
static func _level_3() -> Dictionary:
	return {
		"name": "Torre Roja",
		"difficulty": "Dificil",
		"par_time": 75.0,
		# Atardecer: sol bajo delante del jugador, cielo violeta y mar oscuro con
		# reflejos naranjas.
		"theme": {
			"sky_top": Color(0.3, 0.22, 0.55),
			"sky_horizon": Color(1, 0.58, 0.38),
			"ground_bottom": Color(0.42, 0.3, 0.45),
			"sun_color": Color(1, 0.68, 0.45),
			"sun_energy": 1.1,
			"sun_pitch": -26.0,
			"sun_yaw": 145.0,
			"ambient": Color(0.62, 0.55, 0.75),
			"ambient_energy": 1.0,
			"fog_color": Color(0.9, 0.6, 0.55),
			"fog_density": 0.005,
			"water_deep": Color(0.06, 0.07, 0.2),
			"water_crest": Color(0.32, 0.22, 0.42),
			"cloud_top": Color(1, 0.86, 0.8),
			"cloud_bottom": Color(0.85, 0.6, 0.7),
			"island_colors": ["red", "yellow"],
			"flag_color": "yellow",
		},
		"fall_y": -18.0,
		"spawn": Vector3(0, 1.2, 0),
		"blocks": [
			["platform_6x6x1", "red", 0, 0, 0],
			["platform_1x1x1", "yellow", -2, 0, -6],
			["platform_1x1x1", "yellow", 2, 0, -10],
			["platform_1x1x1", "yellow", -2, 0, -14],
			["platform_1x1x1", "yellow", 2, 1, -18],
			["platform_2x2x1", "blue", 0, 1, -22.5],
			["platform_1x1x1", "green", 0, 1, -26.5],
			["platform_1x1x1", "yellow", 0, 3, -30.5],
			["platform_1x1x1", "yellow", -2.5, 3, -34.5],
			["platform_1x1x1", "yellow", 1, 3, -38],
			["platform_4x4x1", "blue", 0, 3, -50],
			["platform_1x1x1", "yellow", -3, 5, -55],
			["platform_1x1x1", "yellow", 1.5, 5, -58.5],
			["platform_1x1x1", "yellow", -1.5, 5, -62],
			["platform_1x1x1", "yellow", 1.5, 5, -65.5],
			["platform_6x6x1", "red", 0, 5, -85],
			["platform_1x1x1", "yellow", 2, 5, -92],
			["platform_1x1x1", "yellow", -1, 6, -96],
			["platform_1x1x1", "yellow", 1.5, 7, -100],
			["platform_2x2x1", "blue", 0, 7, -104.5],
			["platform_2x2x1", "red", 0, 10, -114],
			["platform_1x1x1", "yellow", -2, 10, -118.5],
			["platform_1x1x1", "yellow", 1.5, 11, -122],
			["platform_6x6x1", "red", 0, 11, -128],
			# Rama derecha temprana: un corazon y vuelta al camino por otro lado.
			["platform_1x1x1", "yellow", 4.5, 1, -22.5],
			["platform_1x1x1", "green", 8, 2, -24.5],
			["platform_2x2x1", "blue", 8.5, 2, -29],
			["platform_1x1x1", "yellow", 4, 1, -28],
			# Rama izquierda: Super salto y, 3 m mas arriba, la gema. Se baja
			# a un bloque que devuelve al camino de bloques 1x1.
			["platform_1x1x1", "yellow", -5.5, 3, -50],
			["platform_2x2x1", "green", -9.5, 4, -52],
			["platform_2x2x1", "red", -11.5, 7, -58],
			["platform_1x1x1", "yellow", -5.5, 4, -61],
			# Ruta del cielo: el resorte de la plataforma grande sube a una
			# hilera de bloques que salta el ascensor y llega a la torre.
			["platform_2x2x1", "yellow", -2, 11, -92],
			["platform_1x1x1", "yellow", -4, 11, -96.5],
			["platform_1x1x1", "yellow", -4, 11, -100.5],
			["platform_1x1x1", "yellow", -3, 11, -104.5],
			["platform_1x1x1", "yellow", -2, 11, -108.5],
		],
		"decor": [
			["cone", "neutral", -2.5, 1, 2.0, 0.0],
			["cone", "neutral", 2.5, 1, 2.0, 0.0],
			["cone", "neutral", -1.5, 4, -49.0, 0.0],
			["cone", "neutral", 1.5, 4, -49.0, 0.0],
			["cone", "neutral", -2.5, 6, -83.0, 0.0],
			["cone", "neutral", 2.5, 6, -83.0, 0.0],
			["cone", "neutral", -2.5, 12, -125.5, 0.0],
			["cone", "neutral", 2.5, 12, -125.5, 0.0],
		],
		"stars": [
			Vector3(-2, 2.3, -6),
			Vector3(2, 2.3, -10),
			Vector3(-2, 2.3, -14),
			Vector3(2, 3.3, -18),
			Vector3(0, 3.3, -22.5),
			Vector3(0, 5.3, -30.5),
			Vector3(-2.5, 5.3, -34.5),
			Vector3(0, 5.3, -43),
			Vector3(-3, 7.3, -55),
			Vector3(0, 7.3, -85),
			Vector3(2, 6.3, -92),
			Vector3(-1, 7.3, -96),
			Vector3(1.5, 8.3, -100),
			Vector3(0, 12.3, -109),
			Vector3(-2, 12.3, -118.5),
			Vector3(1.5, 13.3, -122),
			Vector3(4.5, 3.3, -22.5),
			Vector3(-5.5, 5.3, -50),
			Vector3(-2, 13.3, -92),
			Vector3(-4, 13.3, -100.5),
		],
		"items": [
			["heart", Vector3(8.5, 4.3, -29)],
			["power", Vector3(-9.5, 6.3, -52)],
			["gem", Vector3(-11.5, 9.3, -58)],
		],
		"springs": [
			Vector3(-2, 6, -86.5),
		],
		"checkpoints": [
			Vector3(0, 2.0, -22.5),
			Vector3(-0.6, 4.0, -50),
			Vector3(-1.5, 6.0, -84),
			Vector3(0, 8.0, -104.5),
		],
		"movers": [
			{
				"type": "platform_2x2x1", "color": "blue",
				"from": Vector3(0, 3, -43), "to": Vector3(3, 3, -43),
				"speed": 2.5,
			},
			{
				"type": "platform_2x2x1", "color": "blue",
				"from": Vector3(0, 5, -70), "to": Vector3(0, 5, -78),
				"speed": 3.5,
			},
			# Ascensor: sube de la altura del bloque azul a la de la torre.
			{
				"type": "platform_2x2x1", "color": "blue",
				"from": Vector3(0, 7, -109), "to": Vector3(0, 10, -109),
				"speed": 2.0,
			},
		],
		"goal": Vector3(0, 12.0, -130),
	}


# --- Contrarreloj 1: Marea Alta ----------------------------------------------
# Pasillo largo con Turbo de salida, tramos de bloques rojos que se rompen y
# una subida final. Dos desvios con aros de tiempo: uno lateral facil y otro
# con resorte, que cuesta segundos pero da mas de lo que cuesta.
static func _trial_1() -> Dictionary:
	return {
		"name": "Marea Alta",
		"difficulty": "Contrarreloj",
		"mode": "contrarreloj",
		# Medido con un bot que no falla: termina en ~19 s con ~12 s de sobra
		# por la ruta principal. Un humano tiene margen para una o dos caidas.
		"time_limit": 16.0,
		"time_bonus": 3.0,
		"checkpoint_bonus": 3.0,
		"fall_penalty": 3.0,
		"par_time": 22.0,
		# Atardecer encendido: cielo naranja, mar oscuro y niebla calida.
		"theme": {
			"sky_top": Color(0.55, 0.25, 0.32),
			"sky_horizon": Color(1, 0.55, 0.25),
			"ground_bottom": Color(0.5, 0.3, 0.3),
			"sun_color": Color(1, 0.6, 0.35),
			"sun_energy": 1.2,
			"sun_pitch": -22.0,
			"sun_yaw": 160.0,
			"ambient": Color(0.75, 0.55, 0.5),
			"ambient_energy": 1.0,
			"fog_color": Color(1, 0.6, 0.4),
			"fog_density": 0.006,
			"water_deep": Color(0.12, 0.08, 0.22),
			"water_crest": Color(0.65, 0.3, 0.3),
			"cloud_top": Color(1, 0.8, 0.65),
			"cloud_bottom": Color(0.85, 0.45, 0.45),
			"island_colors": ["red", "yellow"],
			"flag_color": "red",
		},
		"fall_y": -18.0,
		"spawn": Vector3(0, 1.2, 1.5),
		# Cada flecha lleva a un "salto turbo": un hueco de 6 m que solo se
		# cruza con el impulso, y una plataforma grande para aterrizar.
		"blocks": [
			["platform_6x6x1", "blue", 0, 0, 0],
			["platform_arrow_4x4x1", "yellow", 0, 0, -5],
			["platform_4x4x1", "blue", 0, 0, -9],
			["platform_6x6x1", "green", 0, 1, -20],
			["platform_4x4x1", "green", 0, 2, -40],
			["platform_2x2x1", "yellow", 6, 2, -40],
			["platform_arrow_4x4x1", "yellow", 0, 2, -44],
			["platform_4x4x1", "blue", 0, 2, -48],
			["platform_6x6x1", "blue", 0, 2, -59],
			["platform_4x4x1", "green", 0, 4, -79.5],
			["platform_2x2x1", "yellow", -6, 4, -79.5],
			["platform_2x2x1", "blue", 2, 5, -85],
			["platform_2x2x1", "blue", -1, 6, -89.5],
			["platform_2x2x1", "blue", 2, 7, -94],
			["platform_6x6x1", "yellow", 0, 7, -101],
		],
		"crumbles": [
			["platform_2x2x1", "red", 2, 1, -26],
			["platform_2x2x1", "red", -1, 1, -30.5],
			["platform_2x2x1", "red", 2, 2, -35],
			["platform_2x2x1", "red", -2, 3, -64.5],
			["platform_2x2x1", "red", 1, 3, -69],
			["platform_2x2x1", "red", -1, 4, -73.5],
		],
		"boost_pads": [
			Vector3(0, 0, -5),
			Vector3(0, 2, -44),
		],
		"decor": [],
		"stars": [
			Vector3(0, 3.3, -20),
			Vector3(2, 3.3, -26),
			Vector3(-1, 3.3, -30.5),
			Vector3(2, 4.3, -35),
			Vector3(0, 4.3, -59),
			Vector3(1, 5.3, -69),
			Vector3(2, 7.3, -85),
			Vector3(2, 9.3, -94),
		],
		"items": [
			["time", Vector3(0, 2.8, -14)],
			["time", Vector3(6, 4.3, -40)],
			["time", Vector3(0, 4.6, -53)],
			["time", Vector3(-0.5, 6.4, -76)],
			["time", Vector3(-6, 11.0, -79.5)],
		],
		"springs": [
			Vector3(-6, 5, -79.5),
		],
		"checkpoints": [
			Vector3(-1.2, 3.0, -40),
			Vector3(1.2, 5.0, -79.5),
		],
		"movers": [],
		"goal": Vector3(0, 8.0, -103),
	}


# --- Contrarreloj 2: Tormenta -------------------------------------------------
# Bloques 1x1 que se rompen, plataforma movil lateral y un ascensor lento. El
# resorte junto al segundo checkpoint es un atajo: salta el ascensor si se
# apunta bien.
static func _trial_2() -> Dictionary:
	return {
		"name": "Tormenta",
		"difficulty": "Contrarreloj",
		"mode": "contrarreloj",
		# Bot sin fallos con el atajo del resorte: ~21 s, ~9 s de sobra.
		"time_limit": 16.0,
		"time_bonus": 3.0,
		"checkpoint_bonus": 4.0,
		"fall_penalty": 3.0,
		"par_time": 24.0,
		# Noche de tormenta: cielo plomizo, lluvia y relampagos.
		"theme": {
			"sky_top": Color(0.08, 0.1, 0.18),
			"sky_horizon": Color(0.35, 0.38, 0.48),
			"ground_bottom": Color(0.15, 0.17, 0.24),
			"sun_color": Color(0.75, 0.8, 1),
			"sun_energy": 0.7,
			"sun_pitch": -60.0,
			"sun_yaw": 20.0,
			"ambient": Color(0.45, 0.5, 0.65),
			"ambient_energy": 0.9,
			"fog_color": Color(0.3, 0.33, 0.42),
			"fog_density": 0.012,
			"water_deep": Color(0.02, 0.05, 0.1),
			"water_crest": Color(0.25, 0.32, 0.42),
			"cloud_top": Color(0.55, 0.58, 0.66),
			"cloud_bottom": Color(0.22, 0.24, 0.32),
			"island_colors": ["blue", "red"],
			"flag_color": "red",
			"storm": true,
		},
		"fall_y": -18.0,
		"spawn": Vector3(0, 1.2, 1.5),
		"blocks": [
			["platform_6x6x1", "red", 0, 0, 0],
			["platform_4x4x1", "blue", 0, 2, -22],
			["platform_1x1x1", "yellow", -5, 2, -22],
			["platform_arrow_4x4x1", "yellow", 0, 2, -26],
			["platform_6x6x1", "blue", 0, 2, -38],
			["platform_1x1x1", "yellow", 0, 3, -49],
			["platform_4x4x1", "blue", 0, 4, -61.5],
			["platform_2x2x1", "red", 0, 8, -71],
			["platform_6x6x1", "yellow", 0, 9, -88.5],
		],
		"crumbles": [
			["platform_1x1x1", "red", 2, 0, -6],
			["platform_1x1x1", "red", -1, 1, -9.5],
			["platform_1x1x1", "red", 2, 1, -13],
			["platform_1x1x1", "red", 0, 2, -16.5],
			["platform_1x1x1", "red", -2, 3, -52.5],
			["platform_1x1x1", "red", 1, 4, -56],
			["platform_1x1x1", "red", 2, 8, -75],
			["platform_1x1x1", "red", -1, 9, -78.5],
			["platform_1x1x1", "red", 1.5, 9, -82],
		],
		"boost_pads": [
			Vector3(0, 2, -26),
		],
		"decor": [],
		"stars": [
			Vector3(2, 2.3, -6),
			Vector3(-1, 3.3, -9.5),
			Vector3(2, 3.3, -13),
			Vector3(0, 4.3, -16.5),
			Vector3(0, 4.3, -38),
			Vector3(0, 5.3, -49),
			Vector3(1, 6.3, -56),
			Vector3(0, 10.3, -71),
			Vector3(1.5, 11.3, -82),
		],
		"items": [
			["time", Vector3(-5, 4.3, -22)],
			["time", Vector3(0, 4.3, -31.5)],
			["time", Vector3(0, 9.5, -66.5)],
			["time", Vector3(-1, 10.8, -80.3)],
		],
		"springs": [
			Vector3(1.5, 5, -63),
		],
		"checkpoints": [
			Vector3(-1.2, 3.0, -22),
			Vector3(-1.2, 5.0, -61),
		],
		"movers": [
			{
				"type": "platform_2x2x1", "color": "red",
				"from": Vector3(-3, 2, -45), "to": Vector3(3, 2, -45),
				"speed": 3.0,
			},
			# Ascensor lento: o se espera, o se usa el resorte.
			{
				"type": "platform_2x2x1", "color": "blue",
				"from": Vector3(0, 4, -66.5), "to": Vector3(0, 8, -66.5),
				"speed": 2.2,
			},
		],
		"goal": Vector3(0, 10.0, -90.5),
	}


# --- Utilidades de rutas y medidas -------------------------------------------

# Ruta res:// del modelo. Los colores disponibles del pack son
# blue / red / green / yellow, mas "neutral" (sin sufijo de color).
static func asset_path(type_name: String, color: String) -> String:
	if color == "neutral":
		return BASE + "neutral/" + type_name + ".gltf"
	return BASE + color + "/" + type_name + "_" + color + ".gltf"


# Tamano real del bloque en metros.
# El nombre codifica {X}x{Z}x{Y}: el tercer numero es el ALTO.
static func block_size(type_name: String) -> Vector3:
	var parts := type_name.split("_")
	var dims := parts[parts.size() - 1].split("x")
	if dims.size() == 3 and dims[0].is_valid_int() and dims[1].is_valid_int() and dims[2].is_valid_int():
		return Vector3(float(dims[0]), float(dims[2]), float(dims[1]))
	return Vector3(1, 1, 1)
