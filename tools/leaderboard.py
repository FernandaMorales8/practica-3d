#!/usr/bin/env python3
"""Consulta la tabla de records de Aventura de Estrellas fuera del juego.

La base la crea el juego en user://aventura.db. Uso:

    python3 tools/leaderboard.py                     # top 10 de cada nivel y general
    python3 tools/leaderboard.py nivel 2             # records del nivel 2 (4 y 5 = contrarreloj)
    python3 tools/leaderboard.py nivel 2 --orden estrellas
    python3 tools/leaderboard.py jugador Pablo       # records e historial de un jugador
    python3 tools/leaderboard.py intentos --limite 30
    python3 tools/leaderboard.py sql "SELECT * FROM v_records"   # consulta libre (solo lectura)
    python3 tools/leaderboard.py ruta                # muestra donde esta la base

Opcion global: --db RUTA para usar otro archivo.
"""
import argparse
import os
import sqlite3
import sys
from pathlib import Path

APP_NAME = "IA"  # config/name de project.godot
DB_FILE = "aventura.db"
LEVELS = 5          # 1-3 aventura, 4-5 contrarreloj
GEM_LEVELS = 3      # solo la aventura tiene gemas


def default_db_path() -> Path:
    """Ruta de user:// de Godot segun el sistema operativo."""
    if sys.platform.startswith("win"):
        base = Path(os.environ.get("APPDATA", Path.home() / "AppData" / "Roaming")) / "Godot"
    elif sys.platform == "darwin":
        base = Path.home() / "Library" / "Application Support" / "Godot"
    else:
        base = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local" / "share")) / "godot"
    return base / "app_userdata" / APP_NAME / DB_FILE


def fmt_time(ms) -> str:
    ms = int(ms or 0)
    return f"{ms // 60000}:{(ms // 1000) % 60:02d}.{(ms % 1000) // 10:02d}"


def print_table(headers, rows):
    rows = [[("" if c is None else str(c)) for c in r] for r in rows]
    widths = [max([len(h)] + [len(r[i]) for r in rows]) for i, h in enumerate(headers)]
    line = "  ".join(h.ljust(w) for h, w in zip(headers, widths))
    print(line)
    print("-" * len(line))
    for r in rows:
        print("  ".join(c.ljust(w) for c, w in zip(r, widths)))
    if not rows:
        print("(sin registros)")


def level_board(con, nivel, orden="tiempo", limite=10):
    order = "tiempo_ms ASC, estrellas DESC, id ASC"
    if orden == "estrellas":
        order = "estrellas DESC, gema DESC, tiempo_ms ASC, id ASC"
    rows = con.execute(
        f"""SELECT nickname, tiempo_ms, medalla, numero, intentos_totales, estrellas,
                   estrellas_total, gema, caidas, fecha
            FROM v_records WHERE nivel = ? ORDER BY {order} LIMIT ?""",
        (nivel, limite),
    ).fetchall()
    name = con.execute("SELECT nivel_nombre FROM intentos WHERE nivel = ? LIMIT 1", (nivel,)).fetchone()
    print(f"\n== Nivel {nivel}{' - ' + name[0] if name else ''} (por {orden}) ==")
    print_table(
        ["#", "Jugador", "Tiempo", "Medalla", "Intentos hasta record", "Estrellas", "Gema", "Caidas", "Fecha"],
        [
            [i + 1, r[0], fmt_time(r[1]), r[2] or "-", f"{r[3]} de {r[4]}", f"{r[5]}/{r[6]}",
             "Si" if r[7] else "-", r[8], r[9]]
            for i, r in enumerate(rows)
        ],
    )


def general_board(con, limite=10):
    rows = con.execute(
        """WITH mejor AS (
               SELECT jugador_id, nivel, MIN(tiempo_ms) t, MAX(estrellas) e, MAX(gema) g
               FROM intentos WHERE resultado = 'completado' GROUP BY jugador_id, nivel
           ), total AS (
               SELECT jugador_id, COUNT(*) n, SUM(caidas) c FROM intentos GROUP BY jugador_id
           )
           SELECT j.nickname, COUNT(m.nivel), COALESCE(SUM(m.t), 0), COALESCE(SUM(m.e), 0),
                  COALESCE(SUM(m.g), 0), t.n, t.c
           FROM jugadores j JOIN total t ON t.jugador_id = j.id
           LEFT JOIN mejor m ON m.jugador_id = j.id
           GROUP BY j.id
           ORDER BY 2 DESC, 4 DESC, 5 DESC, 3 ASC LIMIT ?""",
        (limite,),
    ).fetchall()
    print("\n== General ==")
    print_table(
        ["#", "Jugador", "Niveles", "Suma mejores tiempos", "Estrellas", "Gemas", "Intentos", "Caidas"],
        [[i + 1, r[0], f"{r[1]}/{LEVELS}", fmt_time(r[2]) if r[1] else "-", r[3], f"{r[4]}/{GEM_LEVELS}", r[5], r[6]]
         for i, r in enumerate(rows)],
    )


def player(con, nick, limite):
    found = con.execute("SELECT id, nickname, creado FROM jugadores WHERE nickname = ?", (nick,)).fetchone()
    if not found:
        print(f"No existe el jugador '{nick}'.")
        return
    print(f"\nJugador: {found[1]}  (registrado {found[2]})")
    recs = con.execute(
        """SELECT nivel, nivel_nombre, tiempo_ms, medalla, numero, intentos_totales, estrellas,
                  estrellas_total, gema
           FROM v_records WHERE jugador_id = ? ORDER BY nivel""",
        (found[0],),
    ).fetchall()
    print("\n-- Records --")
    print_table(
        ["Nivel", "Tiempo", "Medalla", "Intentos hasta record", "Estrellas", "Gema"],
        [[f"{r[0]}. {r[1]}", fmt_time(r[2]), r[3] or "-", f"{r[4]} de {r[5]}", f"{r[6]}/{r[7]}",
          "Si" if r[8] else "-"] for r in recs],
    )
    history(con, limite, found[0])


def history(con, limite, player_id=None):
    where, args = ("WHERE i.jugador_id = ?", (player_id, limite)) if player_id else ("", (limite,))
    rows = con.execute(
        f"""SELECT j.nickname, i.nivel, i.numero, i.resultado, i.tiempo_ms, i.estrellas,
                   i.estrellas_total, i.gema, i.corazones, i.caidas, i.fecha
            FROM intentos i JOIN jugadores j ON j.id = i.jugador_id
            {where} ORDER BY i.id DESC LIMIT ?""",
        args,
    ).fetchall()
    print("\n-- Ultimos intentos --")
    print_table(
        ["Jugador", "Nivel", "Intento", "Resultado", "Tiempo", "Estrellas", "Gema", "Corazones", "Caidas", "Fecha"],
        [[r[0], r[1], f"#{r[2]}", r[3], fmt_time(r[4]), f"{r[5]}/{r[6]}", "Si" if r[7] else "-", r[8], r[9], r[10]]
         for r in rows],
    )


def main():
    parser = argparse.ArgumentParser(description="Tabla de records de Aventura de Estrellas")
    parser.add_argument("--db", type=Path, default=None, help="ruta de aventura.db")
    sub = parser.add_subparsers(dest="cmd")
    p_lvl = sub.add_parser("nivel", help="records de un nivel")
    p_lvl.add_argument("numero", type=int, choices=range(1, LEVELS + 1))
    p_lvl.add_argument("--orden", choices=["tiempo", "estrellas"], default="tiempo")
    p_lvl.add_argument("--limite", type=int, default=50)
    p_gen = sub.add_parser("general", help="resumen por jugador")
    p_gen.add_argument("--limite", type=int, default=50)
    p_ply = sub.add_parser("jugador", help="records e historial de un jugador")
    p_ply.add_argument("nickname")
    p_ply.add_argument("--limite", type=int, default=20)
    p_hist = sub.add_parser("intentos", help="ultimos intentos de todos")
    p_hist.add_argument("--limite", type=int, default=20)
    p_sql = sub.add_parser("sql", help="consulta SQL libre de solo lectura")
    p_sql.add_argument("consulta")
    sub.add_parser("ruta", help="muestra la ruta de la base")
    args = parser.parse_args()

    path = args.db or default_db_path()
    if args.cmd == "ruta":
        print(path)
        return
    if not path.exists():
        sys.exit(f"No se encontro la base de datos en {path}\nJuega una partida primero o usa --db RUTA.")

    # Solo lectura: esta herramienta nunca modifica los records.
    con = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    try:
        if args.cmd == "nivel":
            level_board(con, args.numero, args.orden, args.limite)
        elif args.cmd == "general":
            general_board(con, args.limite)
        elif args.cmd == "jugador":
            player(con, args.nickname, args.limite)
        elif args.cmd == "intentos":
            history(con, args.limite)
        elif args.cmd == "sql":
            cur = con.execute(args.consulta)
            print_table([d[0] for d in cur.description or []], cur.fetchall())
        else:
            for n in range(1, LEVELS + 1):
                level_board(con, n)
            general_board(con)
    finally:
        con.close()


if __name__ == "__main__":
    main()
