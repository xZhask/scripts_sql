"""Inconsistencias de registro sobre la sábana de data_general_atenciones.sql (CSV).

Para meses que no están en el backup local (ej. octubre 2026, extraído de
producción). Aplica las reglas de inconsistencias_atenciones.sql que el CSV
permite y escribe el resultado con las mismas columnas. Incluye el documento
del paciente: la salida debe llamarse extraccion_*.csv para que no se versione.

    python inconsistencias_csv_atenciones.py extraccion_atenciones_oct26.csv extraccion_inconsistencias_oct2026.csv

Reglas aplicadas: P1, P2, P3, P6, A3, E1, E3 y E4 (propia del CSV).
P6: en ambulatorio la cantidad debe ser 1, salvo odontología (CPMS D/E) e
imágenes (CPMS 7). P7: en emergencia, el total de un procedimiento no debe
superar los días calendario de estancia (el CSV no trae fechas de
hospitalización, así que hospitalización sigue con P3). P3 solo evalúa lo
que P6 y P7 no cubren.
No aplicables con el CSV:
  - P4 procedimiento repetido: el GROUP BY de la sábana une las filas repetidas
    con la misma cantidad, así que no se pueden contar.
  - P5 / D1 sexo, A1 fecha de registro, A2 cita, A4 signos vitales: el CSV no
    trae esas columnas.
  - E1 / E3 se evalúan por fecha (sin hora): el CSV no trae hora_alta_medica y
    fecha_alta_medica viene a las 00:00.
"""
import csv
import math
import sys
from collections import defaultdict
from datetime import datetime

COLUMNAS = [
    "SEVERIDAD", "REGLA", "INCONSISTENCIA", "DETALLE", "ID_ATENCION",
    "TIPO_DOC_PACIENTE", "NRO_DOC_PACIENTE", "ID_EMERGENCIA",
    "ID_PRESTACION_PROCEDIMIENTO", "IDS_RELACIONADOS", "FECHA_ATENCION", "TIPO_ATENCION",
    "CODIGO_IPRESS", "IPRESS", "CONSULTORIO", "CODIGO", "DESCRIPCION", "CANTIDAD",
    "PROFESIONAL", "REGISTRADO_EL",
]
TIPOS = {"1": "AMBULATORIO", "2": "EMERGENCIA", "3": "HOSPITALIZACION", "7": "URGENCIA"}


def fecha(texto):
    return datetime.strptime(texto[:19], "%Y-%m-%d %H:%M:%S") if texto else None


def base(fila):
    return {
        "ID_ATENCION": fila["ID ATENCION"],
        "NRO_DOC_PACIENTE": fila["dni"],
        "FECHA_ATENCION": fila["fecha_atencion"][:10],
        "TIPO_ATENCION": TIPOS.get(fila["TIPO ATENCION"], fila["TIPO ATENCION"]),
        "CODIGO_IPRESS": fila["CODIGO IPRESS"],
        "IPRESS": fila["ipress"],
        "CONSULTORIO": fila["CONSULTORIO"],
        "PROFESIONAL": " ".join(filter(None, [fila["paterno_profesional"], fila["materno_profesional"], fila["nombre_profesional"]])),
    }


def main(entrada, salida):
    with open(entrada, encoding="utf-8-sig", newline="") as archivo:
        filas = list(csv.DictReader(archivo))
    hallazgos = []

    # P1 / P2 / P6 / P3 cantidades (P6: ambulatorio salvo odontología D/E e imágenes 7)
    def unitario(f):
        return f["TIPO ATENCION"] == "1" and not f["cpms"].startswith(("D", "E", "7"))

    def por_estancia(f):
        return f["TIPO ATENCION"] == "2" and bool(f["fecha_registro_ingreso"])

    por_cpms = defaultdict(list)
    for f in filas:
        if f["cpms"] and int(f["CANTIDAD PROCEDIMIENTOS"]) > 0 and not unitario(f) and not por_estancia(f):
            por_cpms[f["cpms"]].append(int(f["CANTIDAD PROCEDIMIENTOS"]))
    maximo = {}
    for cpms, valores in por_cpms.items():
        if len(valores) >= 30:
            valores.sort()
            maximo[cpms] = max(valores[math.ceil(len(valores) * 0.99) - 1], 1)
        else:
            maximo[cpms] = 9
    for f in filas:
        if not f["cpms"]:
            continue
        cantidad = int(f["CANTIDAD PROCEDIMIENTOS"])
        tope = maximo.get(f["cpms"], 9)
        if cantidad < 0:
            regla, nombre, severidad, detalle = "P1", "CANTIDAD NEGATIVA", "ERROR", ""
        elif cantidad == 0:
            regla, nombre, severidad, detalle = "P2", "CANTIDAD CERO", "ERROR", ""
        elif unitario(f) and cantidad > 1:
            regla, nombre, severidad = "P6", "CANTIDAD MAYOR A 1 EN ATENCION AMBULATORIA", "ERROR"
            detalle = f"Cantidad {cantidad}; en ambulatorio debe ser 1 (salvo odontología e imágenes)"
        elif not unitario(f) and not por_estancia(f) and cantidad > tope:
            regla, nombre, severidad = "P3", "CANTIDAD ATIPICA", "REVISAR"
            detalle = f"Cantidad {cantidad}; lo habitual para este CPMS es hasta {tope}"
        else:
            continue
        hallazgos.append({**base(f), "SEVERIDAD": severidad, "REGLA": regla, "INCONSISTENCIA": nombre,
                          "DETALLE": detalle, "CODIGO": f["cpms"], "DESCRIPCION": f["DESCRIPCIÓN PROCEDIMIENTO"],
                          "CANTIDAD": cantidad})

    # P7 emergencia: total del procedimiento vs días calendario de estancia
    fin_periodo = max(fecha(f["fecha_atencion"]) for f in filas).date()
    totales = defaultdict(int)
    for f in filas:
        if f["cpms"] and por_estancia(f) and int(f["CANTIDAD PROCEDIMIENTOS"]) > 0:
            totales[(f["ID ATENCION"], f["cpms"])] += int(f["CANTIDAD PROCEDIMIENTOS"])
    vistos = set()
    for f in filas:
        clave = (f["ID ATENCION"], f["cpms"])
        if clave not in totales or clave in vistos:
            continue
        vistos.add(clave)
        ingreso = fecha(f["fecha_registro_ingreso"]).date()
        alta = fecha(f["fecha_alta_medica"]).date() if f["fecha_alta_medica"] else fin_periodo
        alta = max(alta, ingreso)
        dias = (alta - ingreso).days + 1
        if totales[clave] > dias:
            sin_alta = "" if f["fecha_alta_medica"] else ", sin alta: contado hasta fin del periodo"
            hallazgos.append({**base(f), "SEVERIDAD": "REVISAR", "REGLA": "P7",
                              "INCONSISTENCIA": "CANTIDAD MAYOR A LOS DIAS DE ESTANCIA",
                              "DETALLE": f"Total {totales[clave]} en {dias} día(s) de estancia "
                                         f"({ingreso:%d/%m/%Y} al {alta:%d/%m/%Y}{sin_alta})",
                              "ID_EMERGENCIA": f["id_emergencia"], "CODIGO": f["cpms"],
                              "DESCRIPCION": f["DESCRIPCIÓN PROCEDIMIENTO"], "CANTIDAD": totales[clave]})

    # Una fila por atención para las reglas de atención y emergencia
    atenciones = {}
    for f in filas:
        atenciones.setdefault(f["ID ATENCION"], f)

    # A3 posible duplicado: mismo paciente, día, IPRESS, profesional y tipo
    grupos = defaultdict(list)
    for id_atencion, f in atenciones.items():
        grupos[(f["dni"], f["fecha_atencion"][:10], f["CODIGO IPRESS"], f["dni_profesional"], f["TIPO ATENCION"])].append(id_atencion)
    for ids in grupos.values():
        if len(ids) > 1:
            relacionados = ", ".join(sorted(ids, key=int))
            for id_atencion in ids:
                hallazgos.append({**base(atenciones[id_atencion]), "SEVERIDAD": "REVISAR", "REGLA": "A3",
                                  "INCONSISTENCIA": "POSIBLE ATENCION DUPLICADA",
                                  "DETALLE": f"{len(ids)} atenciones el mismo día, mismo paciente, IPRESS, profesional y tipo",
                                  "IDS_RELACIONADOS": relacionados})

    # E1 / E3 / E4 emergencias
    for id_atencion, f in atenciones.items():
        if f["TIPO ATENCION"] != "2" or not f["id_emergencia"]:
            continue
        ingreso, alta = fecha(f["fecha_registro_ingreso"]), fecha(f["fecha_alta_medica"])
        detalle = f"Ingreso {f['fecha_registro_ingreso'][:19]}; alta (solo fecha) {f['fecha_alta_medica'][:10] or '-'}"
        regla = None
        if f["estado_emergencia"] == "0":
            regla, nombre, severidad = "E4", "ATENCION ACTIVA DE UNA EMERGENCIA ANULADA", "ERROR"
            detalle = f"Emergencia en estado 0 (anulada/eliminada) con prestación activa. {detalle}"
        elif ingreso and alta and alta.date() < ingreso.date():
            regla, nombre, severidad = "E1", "ALTA ANTERIOR AL INGRESO", "ERROR"
        elif ingreso and alta and (alta.date() - ingreso.date()).days > 7:
            regla, nombre, severidad = "E3", "ESTANCIA EN EMERGENCIA MAYOR A 7 DIAS", "REVISAR"
        if regla:
            hallazgos.append({**base(f), "SEVERIDAD": severidad, "REGLA": regla, "INCONSISTENCIA": nombre,
                              "DETALLE": detalle, "ID_EMERGENCIA": f["id_emergencia"]})

    hallazgos.sort(key=lambda h: (h["SEVERIDAD"], h["REGLA"], h["CODIGO_IPRESS"], int(h["ID_ATENCION"])))
    with open(salida, "w", encoding="utf-8-sig", newline="") as archivo:
        escritor = csv.DictWriter(archivo, fieldnames=COLUMNAS)
        escritor.writeheader()
        escritor.writerows(hallazgos)
    print(f"{salida}: {len(hallazgos)} filas")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
