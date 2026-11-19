# -*- coding: utf-8 -*-
"""
Deduplicación SEIS x SIGESAPOL - Intervenciones quirúrgicas, octubre 2026.

Objetivo: contar cada intervención una sola vez (no sumar los dos reportes).

Entradas: los reportes exportados desde las apps (se leen directo del .xlsx):
  --seis  recursos*_intervenciones_seis.xlsx      (SEIS, menú de intervenciones)
  --sig   reporte_intervenciones_*_sigesapol.xlsx  (SIGESAPOL)

Cobertura oct-2026: SEIS solo trae Leguía (00016094); SIGESAPOL trae Leguía y
Arequipa (00011794). Leguía carga las mismas cirugías en los dos sistemas.

⚠ Ninguno de los dos reportes trae la FECHA de la intervención, así que la
llave no puede usar el día (en egresos sí). Se asume que ambos reportes son
del mismo mes.

Estado (el consolidado pide ejecutadas y suspendidas por separado):
  - SEIS: EJECUTADA / SUSPENDIDA según ESTADO DE PROGRAMACION. Una suspendida
    que luego se realizó cuenta una vez en cada columna (son dos IDs).
  - SIGESAPOL: todo cuenta como EJECUTADA (indicación del usuario). Su reporte
    sale de cqx_atenciones (acto quirúrgico realizado; estados 4, 6 y 7, todos
    con horas de acto): las suspensiones de SIGESAPOL viven en
    cqx_intervenciones.is_suspended y NO vienen en este reporte.
  - Solo se emparejan EJECUTADAS entre sí; las suspendidas de SEIS no tienen
    contraparte en el reporte de SIGESAPOL y se conservan todas.

Limpieza previa:
  - SIGESAPOL: filas repetidas con el mismo id_atencion (defecto de la
    exportación) -> se deja una.
  - El mismo paciente con el mismo CPT dos veces en un sistema NO se elimina:
    sin fecha no se distingue de una reintervención (p. ej. un paciente con
    dos cirugías de 1.1 h y 2.2 h y dos estancias distintas en octubre).

Regla de cruce, dentro de cada DNI (sin ceros a la izquierda) + IPRESS,
emparejando 1 a 1 en este orden:
  1. PAR_CPT  mismo código CPT.
  2. PAR_CIE  mismo diagnóstico (CIE10 completo). El mismo acto viene a menudo
              con CPT distinto en cada sistema (52000 cistoscopía vs 52601 RTU
              de próstata, ambos con N40.X).
  NO se empareja solo por paciente: en oct-2026 el único caso así era un
  pterigión en SEIS y una catarata en SIGESAPOL, dos cirugías distintas.
  Lo que no forma par es una intervención que solo registró un sistema.
  De cada par se conserva el registro de SIGESAPOL (prima desde 202605).

Salidas:
  - datos/intervenciones_dedup_2026_10.csv   detalle deduplicado (con DNI)
  - resumen_intervenciones_2026_10.csv       conteos por IPRESS (agregado)
"""
import argparse
import importlib.util
from pathlib import Path

import pandas as pd

BASE = Path(__file__).resolve().parent
DATOS = BASE / 'datos'
_spec = importlib.util.spec_from_file_location('conv', BASE / '00_convertir_reportes_app.py')
conv = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(conv)

ap = argparse.ArgumentParser()
ap.add_argument('--seis', default=str(BASE / 'recursos20261105-194539937_intervenciones_seis.xlsx'))
ap.add_argument('--sig', default=str(BASE / 'reporte_intervenciones_20261105_194644_sigesapol.xlsx'))
ap.add_argument('--etiqueta', default='2026_10')
args = ap.parse_args()


def leer_seis(ruta):
    df = conv.leer_xlsx(ruta).iloc[1:]  # cabecera con nombres repetidos (DNI, COLEGIO): por posición
    c = df.columns
    return pd.DataFrame({
        'FUENTE': 'SEIS', 'ID_ATENCION': df[c[2]], 'CODIGO_IPRESS': df[c[0]], 'IPRESS': df[c[1]],
        'DNI': df[c[3]], 'PACIENTE': df[c[4]], 'EDAD': df[c[5]], 'SEXO': df[c[6]], 'UPS': df[c[11]],
        'CIE10': df[c[21]], 'DIAGNOSTICO': df[c[22]], 'CPT': df[c[23]], 'PROCEDIMIENTO': df[c[24]],
        'TIPO_CIRUGIA': df[c[25]].str.upper(), 'TIPO_PROGRAMACION': df[c[26]].str.upper(),
        'TIPO_ANESTESIA': df[c[28]], 'HORAS_ACTO_QX': df[c[29]], 'ESTADO_ORIGEN': df[c[32]]})


def leer_sig(ruta):
    df = conv.leer_xlsx(ruta)
    df.columns = df.iloc[0].str.strip()
    df = df.iloc[1:]
    return pd.DataFrame({
        'FUENTE': 'SIGESAPOL', 'ID_ATENCION': df['id_atencion'], 'CODIGO_IPRESS': df['codigo_ipres'],
        'IPRESS': df['nombre_ipress'], 'DNI': df['dni'], 'PACIENTE': df['ape_nom'], 'EDAD': df['edad'],
        'SEXO': df['sexo'], 'UPS': df['upss_servicio'], 'CIE10': df['cie10'], 'DIAGNOSTICO': df['diagnostico'],
        'CPT': df['codigp_cpt'], 'PROCEDIMIENTO': df['nombre_cpt'], 'TIPO_CIRUGIA': df['tipo_cirugia'].str.upper(),
        'TIPO_PROGRAMACION': df['tipo_programacion'].str.upper(), 'TIPO_ANESTESIA': df['tipo_anestecia'],
        'HORAS_ACTO_QX': df['horas_acto_qx'], 'ESTADO_ORIGEN': df['estado_programcion']})


seis, sig = leer_seis(args.seis), leer_sig(args.sig)
seis['ESTADO'] = seis['ESTADO_ORIGEN'].str.strip().str.upper()
sig['ESTADO'] = 'EJECUTADA'
sig_rep = sig[sig.duplicated('ID_ATENCION')]
sig = sig.drop(sig_rep.index)

det = pd.concat([seis, sig], ignore_index=True)
det['CODIGO_IPRESS'] = det['CODIGO_IPRESS'].str.strip().str.zfill(8)
det = det[det['CODIGO_IPRESS'] != '00013591']  # regla: sin Hosp. Luis N. Sáenz (nivel III)
det['DNI_CRUCE'] = det['DNI'].fillna('').str.strip().str.lstrip('0')
det['UID'] = det['FUENTE'] + ':' + det['ID_ATENCION']
det['ID_NUM'] = pd.to_numeric(det['ID_ATENCION'], errors='coerce')

# --- emparejamiento 1 a 1 en dos pasos (solo ejecutadas) ---
pool = det[(det['DNI_CRUCE'] != '') & (det['ESTADO'] == 'EJECUTADA')].copy()
pares = []
for col, metodo in (('CPT', 'PAR_CPT'), ('CIE10', 'PAR_CIE')):
    p = pool.dropna(subset=[col]).sort_values('ID_NUM')
    llave = ['DNI_CRUCE', 'CODIGO_IPRESS', col]
    p = p.assign(RANGO=p.groupby(llave + ['FUENTE']).cumcount())
    m = p[p['FUENTE'] == 'SEIS'].merge(p[p['FUENTE'] == 'SIGESAPOL'], on=llave + ['RANGO'],
                                       suffixes=('_S', '_G'))
    pares.append(m[['UID_S', 'UID_G']].assign(CRUCE=metodo))
    pool = pool[~pool['UID'].isin(set(m['UID_S']) | set(m['UID_G']))]
pares = pd.concat(pares, ignore_index=True)

cruce = pd.concat([pares[['UID_S', 'CRUCE']].rename(columns={'UID_S': 'UID'}),
                   pares[['UID_G', 'CRUCE']].rename(columns={'UID_G': 'UID'})])
det = det.merge(cruce, on='UID', how='left')
det['CRUCE'] = det['CRUCE'].fillna('SOLO_' + det['FUENTE'])
pareja = dict(zip(pares['UID_S'], pares['UID_G'])) | dict(zip(pares['UID_G'], pares['UID_S']))
det['ID_PAR'] = det['UID'].map(pareja).str.split(':').str[1]
# de cada par se conserva SIGESAPOL (oct-2026 >= 202605)
final = det[~(det['CRUCE'].str.startswith('PAR_') & (det['FUENTE'] == 'SEIS'))]

etq = args.etiqueta
final.drop(columns=['UID', 'ID_NUM']).sort_values(['CODIGO_IPRESS', 'DNI_CRUCE']).to_csv(
    DATOS / f'intervenciones_dedup_{etq}.csv', index=False, encoding='utf-8-sig')

# --- resumen por IPRESS ---
g = lambda d: d.groupby(d['CODIGO_IPRESS'].str.strip().str.zfill(8)).size()
eje = final[final['ESTADO'] == 'EJECUTADA']
resumen = pd.DataFrame({
    'SEIS_REPORTE': g(seis),
    'SIGESAPOL_REPORTE': g(pd.concat([sig, sig_rep])),
    'SIGESAPOL_FILAS_REPETIDAS_QUITADAS': g(sig_rep),
    'EJECUTADAS_EN_AMBOS': g(eje[eje['CRUCE'].str.startswith('PAR_')]),
    'EJECUTADAS_SOLO_SEIS': g(eje[eje['CRUCE'] == 'SOLO_SEIS']),
    'EJECUTADAS_SOLO_SIGESAPOL': g(eje[eje['CRUCE'] == 'SOLO_SIGESAPOL']),
    'EJECUTADAS': g(eje),
    'SUSPENDIDAS': g(final[final['ESTADO'] == 'SUSPENDIDA']),
    'TOTAL_INTERVENCIONES': g(final),
}).fillna(0).astype(int)
resumen.insert(0, 'IPRESS', det.groupby('CODIGO_IPRESS')['IPRESS'].first().reindex(resumen.index))
resumen = resumen.reset_index().rename(columns={'index': 'CODIGO_IPRESS'})
resumen.loc[len(resumen)] = ['TOTAL', ''] + resumen.iloc[:, 2:].sum().tolist()
resumen.to_csv(BASE / f'resumen_intervenciones_{etq}.csv', index=False, encoding='utf-8-sig')

pd.set_option('display.width', 250)
print(resumen.to_string(index=False))
print('\nPares por método:', pares['CRUCE'].value_counts().to_dict())
# mismo paciente en ambos sistemas pero sin par: posibles cirugías distintas, para revisar
sueltos = final[final['CRUCE'].str.startswith('SOLO_') & (final['DNI_CRUCE'] != '')]
rev = sueltos[sueltos.duplicated(['DNI_CRUCE', 'CODIGO_IPRESS'], keep=False)
              & sueltos.groupby(['DNI_CRUCE', 'CODIGO_IPRESS'])['FUENTE'].transform('nunique').gt(1)]
if len(rev):
    print('\nMismo paciente en ambos sistemas sin par (revisar):')
    print(rev.sort_values(['DNI_CRUCE', 'FUENTE'])[['DNI_CRUCE', 'FUENTE', 'ID_ATENCION', 'CPT', 'CIE10',
                                                     'PROCEDIMIENTO']].to_string(index=False))
