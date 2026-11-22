#!/usr/bin/env python3
"""
Script para redistribuir las marcas de tiempo (timestamps) de una bitácora
entre ayer y hoy, en lugar de concentrarlas solo en la tarde de hoy.

Formato de entrada/salida:
    2026-11-22 20:47:37.213342+00

Uso:
    python repartir_fechas_bitacora.py entrada.txt salida.txt
    python repartir_fechas_bitacora.py entrada.txt  # imprime a stdout
"""

import sys
import os
from datetime import datetime, timedelta, timezone

FORMAT = "%Y-%m-%d %H:%M:%S.%f+00"


def parse_ts(s):
    """Convierte una cadena 'YYYY-MM-DD HH:MM:SS.ffffff+00' a datetime aware."""
    s = s.strip()
    if not s:
        return None
    # El '+00' no es un offset ISO válido directo para fromisoformat en Python <3.11,
    # así que lo parseamos manualmente.
    base = s[:-3]  # quita '+00'
    dt = datetime.strptime(base, "%Y-%m-%d %H:%M:%S.%f")
    dt = dt.replace(tzinfo=timezone.utc)
    return dt


def format_ts(dt):
    """Convierte datetime aware a cadena 'YYYY-MM-DD HH:MM:SS.ffffff+00'."""
    return dt.strftime(FORMAT)


def redistribuir(fechas, fecha_inicio, fecha_fin):
    """
    Reparte 'fechas' (lista de datetime) uniformemente entre fecha_inicio y fecha_fin.
    Conserva el orden original.
    """
    n = len(fechas)
    if n == 0:
        return []
    if n == 1:
        return [fecha_inicio]

    paso = (fecha_fin - fecha_inicio) / (n - 1)
    nuevas = [fecha_inicio + i * paso for i in range(n)]
    return nuevas


def main():
    if len(sys.argv) < 2:
        print("Uso: python repartir_fechas_bitacora.py <entrada> [salida]")
        sys.exit(1)

    ruta_entrada = sys.argv[1]
    ruta_salida = sys.argv[2] if len(sys.argv) > 2 else None

    # Leer timestamps
    with open(ruta_entrada, "r", encoding="utf-8") as f:
        lineas = f.readlines()

    fechas_originales = []
    for linea in lineas:
        dt = parse_ts(linea)
        if dt is not None:
            fechas_originales.append(dt)

    if not fechas_originales:
        print("No se encontraron timestamps válidos.", file=sys.stderr)
        sys.exit(1)

    # Definir rango: ayer a hoy (hora actual de hoy como tope)
    hoy = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
    ayer = hoy - timedelta(days=1)
    # Tope: fin de hoy (23:59:59.999999)
    fin_hoy = hoy + timedelta(days=1) - timedelta(microseconds=1)

    nuevas_fechas = redistribuir(fechas_originales, ayer, fin_hoy)

    lineas_salida = [format_ts(dt) + "\n" for dt in nuevas_fechas]

    if ruta_salida:
        with open(ruta_salida, "w", encoding="utf-8") as f:
            f.writelines(lineas_salida)
        print(f"Se escribieron {len(lineas_salida)} timestamps a {ruta_salida}")
        print(f"Rango: {format_ts(nuevas_fechas[0])}  ->  {format_ts(nuevas_fechas[-1])}")
    else:
        sys.stdout.writelines(lineas_salida)


if __name__ == "__main__":
    main()
