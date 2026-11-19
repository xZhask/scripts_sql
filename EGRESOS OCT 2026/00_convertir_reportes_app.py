# -*- coding: utf-8 -*-
"""
Convierte los reportes de egresos exportados desde las aplicaciones al formato
de entrada de 03_cruce_egresos.py (alternativa a correr 01/02 en las bases).

  SEIS      -> menú Reporte de Egresos Hospitalarios  (reporteEgresosHospitalarios*.xlsx)
  SIGESAPOL -> reporte de egresos hospitalarios       (reporte_egresos_hospi_*.xlsx)

Se pueden pasar VARIOS archivos de cada sistema (p. ej. SIGESAPOL de setiembre
y de octubre): se juntan y se quitan repetidos por ID de atención.

Limpieza:
  - Se descartan las filas sin fecha de alta (siguen hospitalizados).
  - SIGESAPOL repite filas idénticas en la exportación (23 en oct-2026): se
    deja una por id_atencion.
  - ⚠ El reporte de SIGESAPOL filtra por FECHA DE INGRESO: para tener todos los
    egresos de un mes hay que exportar también el mes (o meses) anterior.
    El reporte de SEIS ya trae las estancias de meses anteriores.

Uso:
  py 00_convertir_reportes_app.py --seis rep_seis.xlsx --sig rep_sig_set.xlsx rep_sig_oct.xlsx
Salida: datos/extraccion_seis_egresos_oct_2026.csv y
        datos/extraccion_sigesapol_egresos_oct_2026.csv
"""
import argparse
import re
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

import pandas as pd

BASE = Path(__file__).resolve().parent
DATOS = BASE / 'datos'
COLS = ['FUENTE', 'ID_ATENCION', 'CODIGO_IPRESS', 'IPRESS', 'DNI', 'PACIENTE', 'SEXO', 'EDAD',
        'FECHA_INGRESO', 'FECHA_ALTA', 'DIAS_ESTANCIA', 'CODIGO_SERVICIO', 'SERVICIO',
        'MOTIVO_ALTA', 'PERIODO_ORIGEN']


def leer_xlsx(ruta):
    """Primera hoja como DataFrame de texto, sin cabecera. Se lee el XML directo
    porque la exportación de SIGESAPOL trae <pageMargins> vacíos que openpyxl
    rechaza."""
    ns = '{http://schemas.openxmlformats.org/spreadsheetml/2006/main}'
    with zipfile.ZipFile(ruta) as z:
        ss = []
        if 'xl/sharedStrings.xml' in z.namelist():
            for si in ET.fromstring(z.read('xl/sharedStrings.xml')).iter(ns + 'si'):
                ss.append(''.join(t.text or '' for t in si.iter(ns + 't')))
        hoja = ET.fromstring(z.read('xl/worksheets/sheet1.xml'))
    filas = []
    for row in hoja.iter(ns + 'row'):
        vals = {}
        for c in row.iter(ns + 'c'):
            col = 0
            for ch in re.match(r'[A-Z]+', c.get('r')).group():
                col = col * 26 + ord(ch) - 64
            v = c.find(ns + 'v')
            if c.get('t') == 's' and v is not None:
                vals[col] = ss[int(v.text)]
            elif c.get('t') == 'inlineStr':
                vals[col] = ''.join(t.text or '' for t in c.iter(ns + 't'))
            elif v is not None:
                vals[col] = v.text
        if any(x not in (None, '') for x in vals.values()):
            filas.append(vals)
    ancho = max(max(f) for f in filas)
    df = pd.DataFrame([[f.get(i) for i in range(1, ancho + 1)] for f in filas], dtype=str)
    return df.replace('', None).dropna(axis=1, how='all')


def fecha(s):
    # SEIS guarda las fechas como número de serie de Excel; SIGESAPOL como texto ISO.
    num = pd.to_numeric(s, errors='coerce')
    serie = pd.to_datetime(num, unit='D', origin='1899-12-30')
    texto = pd.to_datetime(s.where(num.isna()), errors='coerce', format='ISO8601')
    return serie.fillna(texto).dt.strftime('%Y-%m-%d %H:%M')


def seis(ruta):
    # Encabezados repetidos (COLEGIO, CIE I...) -> se lee por posición.
    # La cabecera viene en la fila 2 y la columna A está vacía.
    df = leer_xlsx(ruta).iloc[1:]  # quita la fila de cabecera
    c = df.columns
    return pd.DataFrame({
        'FUENTE': 'SEIS', 'ID_ATENCION': df[c[2]], 'CODIGO_IPRESS': df[c[0]], 'IPRESS': df[c[1]],
        'DNI': df[c[3]], 'PACIENTE': df[c[4]], 'SEXO': df[c[6]], 'EDAD': df[c[5]],
        'FECHA_INGRESO': fecha(df[c[33]]), 'FECHA_ALTA': fecha(df[c[34]]), 'DIAS_ESTANCIA': df[c[32]],
        'CODIGO_SERVICIO': None, 'SERVICIO': df[c[10]], 'MOTIVO_ALTA': df[c[35]], 'PERIODO_ORIGEN': None})


def sigesapol(ruta):
    df = leer_xlsx(ruta)
    df.columns = df.iloc[0].str.strip()
    df = df.iloc[1:]
    return pd.DataFrame({
        'FUENTE': 'SIGESAPOL', 'ID_ATENCION': df['id_atencion'], 'CODIGO_IPRESS': df['codigo_ipress'],
        'IPRESS': df['nombre_ipress'], 'DNI': df['dni_beneficiario'], 'PACIENTE': df['apellidos_nombres'],
        'SEXO': df['sexo'], 'EDAD': df['edad'], 'FECHA_INGRESO': fecha(df['fecha_ingreso']),
        'FECHA_ALTA': fecha(df['fecha_alta']), 'DIAS_ESTANCIA': df['estancias'], 'CODIGO_SERVICIO': None,
        'SERVICIO': df['upss_procedencia'].str.strip(), 'MOTIVO_ALTA': df['motivo_alta'], 'PERIODO_ORIGEN': None})


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--seis', nargs='+', default=[])
    ap.add_argument('--sig', nargs='+', default=[])
    args = ap.parse_args()

    DATOS.mkdir(exist_ok=True)
    for nombre, rutas, lector in (('seis', args.seis, seis), ('sigesapol', args.sig, sigesapol)):
        if not rutas:
            continue
        df = pd.concat([lector(r) for r in rutas], ignore_index=True)
        total = len(df)
        df = df[df['FECHA_ALTA'].notna()].drop_duplicates('ID_ATENCION')
        df[COLS].to_csv(DATOS / f'extraccion_{nombre}_egresos_oct_2026.csv', index=False, encoding='utf-8-sig')
        print(f'{nombre}: {total} filas leídas -> {len(df)} egresos únicos con alta')
