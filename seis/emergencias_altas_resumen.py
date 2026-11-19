"""Cuadros de emergencias con alta y pendientes de alta, junio-diciembre 2025 (SEIS).

Ejecuta emergencias_altas_2025_jun_dic.sql y genera, en esta misma carpeta:

  extraccion_emergencias_altas_2025_jun_dic.csv        1 fila por atención (no se versiona)
  resumen_emergencias_altas_2025_jun_dic_por_mes.csv
  resumen_emergencias_altas_2025_jun_dic_por_ipress.csv
  resumen_emergencias_altas_2025_jun_dic_por_mes_ipress.csv
  resumen_emergencias_altas_2025_jun_dic_por_condicion.csv

Los promedios, la mediana y el percentil 90 usan solo CALIDAD_ESTANCIA = 'VALIDA'.
Las columnas RANGO_* suman ESTANCIAS_VALIDAS.
"""
import csv
import math
import statistics
import subprocess
from collections import defaultdict
from pathlib import Path

MYSQL = r"C:\laragon\bin\mysql\mysql-8.4.3-winx64\bin\mysql.exe"
BASE = "seis_setiembre26"
CARPETA = Path(__file__).resolve().parent
SQL = CARPETA / "emergencias_altas_2025_jun_dic.sql"
PREFIJO = "emergencias_altas_2025_jun_dic"

RANGOS = [
    ("RANGO_HASTA_1H", 60),
    ("RANGO_1H_A_6H", 360),
    ("RANGO_6H_A_24H", 1440),
    ("RANGO_1D_A_3D", 4320),
    ("RANGO_3D_A_7D", 10080),
    ("RANGO_7D_A_30D", 43200),
]


def extraer():
    salida = subprocess.run(
        [MYSQL, "-uroot", "-h127.0.0.1", "-P3306", BASE,
         "--default-character-set=utf8mb4", "--batch"],
        input=SQL.read_bytes(), capture_output=True, check=True,
    ).stdout.decode("utf-8")
    lineas = salida.splitlines()
    columnas = lineas[0].split("\t")
    filas = []
    for linea in lineas[1:]:
        fila = dict(zip(columnas, linea.split("\t")))
        filas.append({k: ("" if v == "NULL" else v) for k, v in fila.items()})
    return columnas, filas


def p90(valores):
    return sorted(valores)[math.ceil(len(valores) * 0.9) - 1]


def resumir(filas):
    total = len(filas)
    pendientes = sum(f["ESTADO_ALTA"] == "PENDIENTE" for f in filas)
    validas = [int(f["MINUTOS"]) for f in filas if f["CALIDAD_ESTANCIA"] == "VALIDA"]
    calendario = [int(f["DIAS_CALENDARIO"]) for f in filas if f["CALIDAD_ESTANCIA"] == "VALIDA"]
    resumen = {
        "EMERGENCIAS": total,
        "CON_ALTA": total - pendientes,
        "PENDIENTES": pendientes,
        "PCT_PENDIENTE": round(100 * pendientes / total, 2) if total else "",
        "ALTA_IGUAL_INGRESO": sum(f["CALIDAD_ESTANCIA"] == "ALTA_IGUAL_INGRESO" for f in filas),
        "FECHA_FUTURA": sum(f["CALIDAD_ESTANCIA"] == "FECHA_FUTURA" for f in filas),
        "MAYOR_30_DIAS": sum(f["CALIDAD_ESTANCIA"] == "MAYOR_30_DIAS" for f in filas),
        "ESTANCIAS_VALIDAS": len(validas),
        "PROM_MINUTOS": round(statistics.mean(validas), 1) if validas else "",
        "PROM_HORAS": round(statistics.mean(validas) / 60, 2) if validas else "",
        "PROM_DIAS": round(statistics.mean(validas) / 1440, 3) if validas else "",
        "MEDIANA_MINUTOS": statistics.median(validas) if validas else "",
        "P90_MINUTOS": p90(validas) if validas else "",
        "MAX_DIAS": round(max(validas) / 1440, 2) if validas else "",
        "PROM_DIAS_CALENDARIO": round(statistics.mean(calendario), 3) if calendario else "",
    }
    desde = 0
    for nombre, hasta in RANGOS:
        resumen[nombre] = sum(desde < m <= hasta for m in validas)
        desde = hasta
    return resumen


def guardar(sufijo, claves, grupos, total=None):
    ruta = CARPETA / f"resumen_{PREFIJO}_{sufijo}.csv"
    filas = []
    for clave, grupo in sorted(grupos.items()):
        filas.append({**dict(zip(claves, clave)), **resumir(grupo)})
    if total is not None:
        etiqueta = {claves[0]: "TOTAL"}
        filas.append({**{c: "" for c in claves}, **etiqueta, **resumir(total)})
    with ruta.open("w", newline="", encoding="utf-8-sig") as archivo:
        escritor = csv.DictWriter(archivo, fieldnames=list(filas[0]))
        escritor.writeheader()
        escritor.writerows(filas)
    print(f"{ruta.name}: {len(filas)} filas")


def agrupar(filas, *columnas):
    grupos = defaultdict(list)
    for fila in filas:
        grupos[tuple(fila[c] for c in columnas)].append(fila)
    return grupos


def main():
    columnas, filas = extraer()

    ruta = CARPETA / f"extraccion_{PREFIJO}.csv"
    with ruta.open("w", newline="", encoding="utf-8-sig") as archivo:
        escritor = csv.DictWriter(archivo, fieldnames=columnas)
        escritor.writeheader()
        escritor.writerows(filas)
    print(f"{ruta.name}: {len(filas)} filas")

    guardar("por_mes", ["PERIODO"], agrupar(filas, "PERIODO"), filas)
    guardar("por_ipress", ["CODIGO_IPRESS", "IPRESS", "NIVEL"],
            agrupar(filas, "CODIGO_IPRESS", "IPRESS", "NIVEL"), filas)
    guardar("por_mes_ipress", ["PERIODO", "CODIGO_IPRESS", "IPRESS", "NIVEL"],
            agrupar(filas, "PERIODO", "CODIGO_IPRESS", "IPRESS", "NIVEL"))

    con_alta = [f for f in filas if f["ESTADO_ALTA"] == "CON ALTA"]
    guardar("por_condicion", ["CONDICION_ALTA"], agrupar(con_alta, "CONDICION_ALTA"), con_alta)


if __name__ == "__main__":
    main()
