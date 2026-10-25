# Aventura de Estrellas

Plataformas 3D hecho con Godot 4.7 (renderer Compatibility). Corre por islas
sobre el mar, recoge estrellas, busca la gema secreta de cada nivel y no te
caigas al agua.

## Modos

- **Aventura (niveles 1-3):** Prado Verde, Canon Azul y Torre Roja. Tres vidas
  (hasta cinco con corazones), una gema secreta por nivel, Super salto y
  resortes en las rutas secundarias.
- **Contrarreloj (niveles 4-5):** Marea Alta y Tormenta. Hay "3, 2, 1, ¡YA!" y
  una cuenta atrás; mientras corre, la marea sube y al llegar a 0 se traga al
  jugador.
  - Los aros verdes dan +3 s y los checkpoints también suman tiempo. Cada caída
    resta 3 s.
  - Las flechas dan Turbo para cruzar los "saltos turbo" y los bloques rojos se
    rompen al pisarlos.
  - Con menos de 10 s suena el tic-tac, la música se acelera y los bordes de la
    pantalla laten en rojo.

Controles: WASD para moverse, Espacio para saltar, ratón para la cámara, P o
Esc para pausar y R para reiniciar.

## Records (SQLite)

Al empezar se pide un nickname. Cada intento queda guardado en
`user://aventura.db` mediante la extensión
[godot-sqlite](https://github.com/2shady4u/godot-sqlite) (`addons/godot-sqlite`).
Se registra el tiempo, el número de intento, las estrellas, la gema, los
corazones, las caídas, la medalla y el resultado.

Desde esta versión también se guardan, en segundo plano, la sesión de juego,
cada caída (dónde y si fue al agua o al vacío), los checkpoints, el tiempo de
oro y dónde termina cada intento.

- **En el juego:** la pantalla de inicio muestra el top 5 y "Ver tabla
  completa" abre las pestañas por nivel, General y Mi historial, con vista
  "Cerca de mí", divisiones por medalla o liga y lo que falta para pasar al
  siguiente. Pulsar un jugador (o "Mis estadísticas") abre sus estadísticas:
  resumen, gráfica de todos sus intentos en cada nivel y comparación con el
  líder o contigo.
- **Panel de diseño:** `python3 tools/dashboard.py --abrir` genera
  `tools/dashboard.html` con gráficas y tablas interactivas (dificultad por
  nivel, dónde se quedan los jugadores, mapa de caídas, reintentos, objetos
  en los records, avisos de qué revisar). Solo lee la base.
- **Fuera del juego:** `python3 tools/leaderboard.py --help`. Solo lee la base.

Ruta de la base: en Linux `~/.local/share/godot/app_userdata/IA/aventura.db`, en
Windows `%APPDATA%\Godot\app_userdata\IA\aventura.db`. En la versión web se
guarda en el almacenamiento del navegador (IndexedDB) de cada jugador.


## Ventana

La ventana se abre a 1080x920, se puede redimensionar y se adapta a cualquier
proporción:

- La interfaz se diseña sobre 1152x864 y se escala sin deformarse (stretch
  `canvas_items` + `expand`).
- En ventanas altas o estrechas la cámara abre su campo de visión horizontal
  para no dar sensación de zoom.

## Game Feel / Juice (Práctica 5)

Se implementaron cuatro elementos de *game feel* para hacer las acciones del
jugador más responsivas, claras y satisfactorias, sin afectar las
funcionalidades previas (base de datos, leaderboard, dashboard, modos de juego).

### 1. Input Buffering

Almacena temporalmente la acción de salto aunque el jugador presione el botón
justo antes de tocar el suelo, ejecutándola en cuanto el personaje aterriza.

| Parámetro | Valor | Descripción |
|-----------|-------|-------------|
| `jump_buffer_time` | **0.18 s** | Ventana de tiempo en que se guarda el salto anticipado |

**Script:** `scripts/player.gd`
**Comportamiento:** Si el jugador presiona Espacio hasta 0.18 s antes de
aterrizar, el salto se ejecuta automáticamente al hacer contacto con el suelo.

---

### 2. Coyote Time

Permite saltar durante un breve instante después de haber abandonado el borde
de una plataforma, haciendo el control más perdonador sin alterar la física.

| Parámetro | Valor | Descripción |
|-----------|-------|-------------|
| `coyote_time` | **0.18 s** | Tiempo tras dejar el suelo en que aún se puede saltar |

**Script:** `scripts/player.gd`
**Comportamiento:** Al separarse de una plataforma el contador `_coyote` se
inicializa a 0.18 s y disminuye cada frame. Si el jugador salta antes de que
llegue a 0, el salto se ejecuta normalmente.

---

### 3. Screenshake

Vibración de cámara con sistema de *trauma* (0–1) que escala cuadráticamente,
combinando desplazamiento y rotación con ruido de tiempo.

| Parámetro | Valor | Descripción |
|-----------|-------|-------------|
| `trauma_decay` | **1.6 /s** | Velocidad de disminución del trauma por segundo |
| `max_shake_offset` | **X 0.25 m, Y 0.22 m, Z 0.15 m** | Desplazamiento máximo de la cámara |
| `max_shake_rot_deg` | **pitch 2°, yaw 2°, roll 3.5°** | Rotación máxima de la cámara |
| `shake_frequency` | **36 Hz** | Frecuencia del ruido de vibración |

**Intensidades de trauma por evento:**

| Evento | Trauma añadido |
|--------|---------------|
| Muerte / caída al agua | 0.60 |
| Tiempo agotado | 0.50 |
| Rayo (lightning) | 0.55 |
| Resorte (spring/bounce) | 0.30 |
| Turbo (boost) | 0.25 |
| Bloque rompible (crumble) | 0.20 |
| Aterrizaje fuerte | 0.15–0.35 proporcional |
| Todas las estrellas recogidas | 0.70 |

**Scripts:** `scripts/camera_rig.gd` (método `add_trauma`),
llamadas desde `scripts/main.gd` y `scripts/player.gd`.

---

### 4. Feedback Visual, Sonoro y de Interfaz

#### Feedback Visual
| Elemento | Evento |
|----------|--------|
| Flash rojo en pantalla | Daño, muerte, tiempo agotado, rayo, caída al agua |
| Pulso dorado de estrellas en HUD | Recolección de estrella |
| Sacudida de iconos de corazón | Pérdida de vida |
| Burst de partículas 3D | Recolección de cualquier ítem |
| Etiqueta flotante 3D | Recolección de ítem (sube y desaparece) |

#### Feedback Sonoro
| Sonido | Evento | Pitch variable |
|--------|--------|----------------|
| `sfx_jump` | Salto | Sí (±5 %) |
| `sfx_land` | Aterrizaje fuerte | Sí (según velocidad) |
| `sfx_hurt` | Daño / muerte | No |
| `sfx_star` | Estrella recogida | Sí (sube con combo, hasta +50 %) |
| `sfx_spring` | Resorte | No |
| `sfx_boost` | Turbo | No |

**Combo de estrellas:** recoger estrellas en menos de 2 s incrementa el pitch
y al completar todas se añade screenshake máximo (trauma 0.70).

---

### Compatibilidad con funcionalidades previas

Todos los elementos de *game feel* son aditivos y no modifican la lógica de
física, colisiones, base de datos, leaderboard ni dashboard. Los parámetros
se pueden ajustar desde el Inspector de Godot (`@export`) sin recompilar.
