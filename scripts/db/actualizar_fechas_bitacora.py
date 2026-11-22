#!/usr/bin/env python3
"""
Actualiza la columna de fecha (executedAt) de la tabla bitacora en Supabase/PostgreSQL,
repartiendo los registros uniformemente entre ayer y hoy.

Los registros se ordenan por id ASC (1 a 65) y se les asigna una fecha distribuida
de forma pareja entre ayer 00:00:00 UTC y hoy 23:59:59.999999 UTC.

Requisitos:
    pip install psycopg2-binary python-dotenv

Archivo .env (en la misma carpeta que este script):
    PG_HOST=db.xxx.supabase.co
    PG_PORT=5432
    PG_DB=postgres
    PG_USER=postgres
    PG_PASSWORD=tu_contraseña
    PG_TABLE=gmm.bitacora      # nombre de la tabla (ajusta si es distinto)
    PG_COL=executedAt          # nombre de la columna fecha
    PG_ID_COL=id               # nombre de la columna id
"""

import os
import sys
import argparse
from datetime import datetime, timedelta, timezone

try:
    import psycopg2
    from psycopg2.extras import RealDictCursor
except ImportError:
    print("Falta instalar dependencias: pip install psycopg2-binary python-dotenv", file=sys.stderr)
    sys.exit(1)

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass


def obtener_conexion():
    return psycopg2.connect(
        host=os.getenv("PG_HOST"),
        port=os.getenv("PG_PORT", "5432"),
        dbname=os.getenv("PG_DB"),
        user=os.getenv("PG_USER"),
        password=os.getenv("PG_PASSWORD"),
        sslmode="require",
    )


def descubrir_columna_fecha(conn, tabla):
    """
    Busca automáticamente columnas de tipo timestamp/timestamptz en la tabla.
    Devuelve el nombre de la primera encontrada o None.
    """
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT column_name, data_type
            FROM information_schema.columns
            WHERE table_name = %s
              AND data_type IN ('timestamp without time zone', 'timestamp with time zone')
            ORDER BY ordinal_position
            """,
            (tabla.split('.')[-1],),  # usar solo el nombre de la tabla, sin esquema
        )
        filas = cur.fetchall()
    if filas:
        return filas[0][0]
    return None


def listar_columnas(conn, tabla):
    """Lista todas las columnas de la tabla para diagnóstico."""
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT column_name, data_type
            FROM information_schema.columns
            WHERE table_name = %s
            ORDER BY ordinal_position
            """,
            (tabla.split('.')[-1],),
        )
        return cur.fetchall()


def main():
    parser = argparse.ArgumentParser(description="Redistribuye fechas de bitacora entre ayer y hoy")
    parser.add_argument("--yes", "-y", action="store_true", help="Confirma sin pedir entrada interactiva")
    args = parser.parse_args()

    tabla = os.getenv("PG_TABLE", "gmm.bitacora")
    col_id = os.getenv("PG_ID_COL", "id")
    col_fecha_env = os.getenv("PG_COL")

    print(f"Conectando a {os.getenv('PG_HOST')}...")
    conn = obtener_conexion()

    try:
        # Mostrar columnas disponibles
        columnas = listar_columnas(conn, tabla)
        print(f"\nColumnas de la tabla '{tabla}':")
        for nombre, tipo in columnas:
            print(f"  - {nombre} ({tipo})")

        # Determinar columna de fecha
        col_fecha = col_fecha_env
        if not col_fecha:
            col_fecha = descubrir_columna_fecha(conn, tabla)

        if not col_fecha:
            print("\nNo se pudo determinar la columna de fecha.")
            print("Especifícala con PG_COL en el archivo .env")
            return

        print(f"\nUsando columna de fecha: {col_fecha}")

        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                f'SELECT {col_id} as id, "{col_fecha}" as fecha FROM {tabla} ORDER BY {col_id} ASC'
            )
            filas = cur.fetchall()

        n = len(filas)
        print(f"Registros encontrados: {n}")
        if n == 0:
            print("No hay nada que actualizar.")
            return

        # Rango: ayer 08:00:00 UTC a hoy 18:00:00 UTC
        hoy = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
        ayer = hoy - timedelta(days=1)
        inicio_dia = hoy.replace(hour=8, minute=0, second=0, microsecond=0)
        fin_dia = hoy.replace(hour=18, minute=0, second=0, microsecond=0)
        fecha_inicio = ayer.replace(hour=8, minute=0, second=0, microsecond=0)
        fecha_fin = fin_dia

        if n == 1:
            nuevas_fechas = [fecha_inicio]
        else:
            paso = (fecha_fin - fecha_inicio) / (n - 1)
            nuevas_fechas = [fecha_inicio + i * paso for i in range(n)]

        # Mostrar vista previa
        print("\nVista previa (primeros 5 y últimos 5):")
        print(f"{'id':>4} | {'fecha actual':>32} | {'fecha nueva':>32}")
        print("-" * 74)
        for fila in filas[:5]:
            print(f"{fila['id']:>4} | {str(fila['fecha']):>32} | {nuevas_fechas[filas.index(fila)].isoformat():>32}")
        if n > 10:
            print("    ...")
        for fila in filas[-5:]:
            idx = filas.index(fila)
            print(f"{fila['id']:>4} | {str(fila['fecha']):>32} | {nuevas_fechas[idx].isoformat():>32}")

        print(f"\nRango nuevo: {nuevas_fechas[0].isoformat()}  ->  {nuevas_fechas[-1].isoformat()}")

        if args.yes:
            confirm = "SI"
        else:
            confirm = input("\n¿Deseas aplicar estos cambios? (escribe SI para confirmar): ").strip()
        if confirm != "SI":
            print("Operación cancelada.")
            return

        with conn.cursor() as cur:
            for fila, nueva_fecha in zip(filas, nuevas_fechas):
                cur.execute(
                    f'UPDATE {tabla} SET "{col_fecha}" = %s WHERE {col_id} = %s',
                    (nueva_fecha, fila["id"]),
                )
        conn.commit()
        print(f"\nSe actualizaron {n} registros correctamente.")

    finally:
        conn.close()


if __name__ == "__main__":
    main()
