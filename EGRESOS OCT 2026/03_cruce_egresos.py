# -*- coding: utf-8 -*-
"""
Cruce y deduplicación SEIS x SIGESAPOL - Egresos hospitalarios, octubre 2026.

Por qué hace falta: San José (00014718) y Leguía (00016094) cargan las MISMAS
estancias en los dos sistemas (agosto 2026: 31 de 33 en San José y 162 de 164
de Leguía en SIGESAPOL también están en SEIS). Arequipa (00011794) registra en
SIGESAPOL desde feb-2026 y Chiclayo (00011833) solo en SIGESAPOL. Sumar los dos
sistemas sin cruzar duplica la mayoría de egresos de San José y Leguía.

Entradas (carpeta datos/, NO versionada porque trae DNI):
  - extraccion_seis_egresos_oct_2026.csv       <- 01_seis_egresos_oct_2026.sql (Adminer)
  - extraccion_sigesapol_egresos_oct_2026.csv  <- 02_sigesapol_egresos_oct_2026.sql (psql --csv)

Objetivo: contar cada ESTANCIA una sola vez (deduplicar, no sumar reportes).

Regla de cruce (por estancia):
  0. Duplicados internos: la misma estancia cargada dos veces en un sistema
     (mismo DNI + IPRESS + día de ingreso, p. ej. SEIS 24709488/24718106 en
     agosto) -> se deja el registro de ID más alto. Ojo: los reportes de las
     apps SÍ los cuentan, por eso SEIS_MES/SIGESAPOL_MES pueden ser mayores.
  1. Candidatos: mismo DNI (sin ceros a la izquierda) + misma IPRESS, y las
     estancias se SOLAPAN (ingreso_A <= alta_B y ingreso_B <= alta_A, por día).
     No se exige la misma fecha de alta: en agosto 24 de los 186 pares traían
     el alta 1-3 días distinta (casi siempre +1 día en SIGESAPOL).
  2. Emparejamiento 1 a 1, primero el candidato más parecido
     (|dif. ingreso| + |dif. alta| en días). Lo que no forma par se conserva:
     es una estancia que solo registró un sistema.
  3. Absorbidos: un registro sin pareja que se solapa con una estancia del
     otro sistema ya emparejada es parte de esa misma estancia y se descarta
     (oct-2026: SIGESAPOL 2-9 oct vs SEIS 2 oct y SEIS 9 oct).
  4. De cada par se conserva un solo registro: desde 202605 prima SIGESAPOL
     (antes, SEIS).
  5. Recién al final se cuentan los egresos del MES por la fecha de alta del
     registro conservado.

Estancias del mismo paciente que NO se solapan (alta 1-oct y reingreso
12-oct) son reingresos reales y se cuentan por separado.

Uso:
  py 03_cruce_egresos.py                       # octubre 2026, archivos por defecto
  py 03_cruce_egresos.py --mes 2026-08 --seis datos/x.csv --sig datos/y.csv

Salidas:
  - datos/egresos_dedup_<mes>.csv     detalle deduplicado (con DNI)
  - resumen_egresos_<mes>.csv         conteos por IPRESS (agregado, versionable)
"""
import argparse
from pathlib import Path

import pandas as pd

BASE = Path(__file__).resolve().parent
DATOS = BASE / 'datos'
PERIODO_SIGESAPOL = '202605'  # desde este periodo prima SIGESAPOL
COLS = ['FUENTE', 'ID_ATENCION', 'CODIGO_IPRESS', 'IPRESS', 'DNI', 'PACIENTE', 'SEXO', 'EDAD',
        'FECHA_INGRESO', 'FECHA_ALTA', 'DIAS_ESTANCIA', 'CODIGO_SERVICIO', 'SERVICIO',
        'MOTIVO_ALTA', 'PERIODO_ORIGEN']

ap = argparse.ArgumentParser()
ap.add_argument('--mes', default='2026-10')
ap.add_argument('--seis', default=str(DATOS / 'extraccion_seis_egresos_oct_2026.csv'))
ap.add_argument('--sig', default=str(DATOS / 'extraccion_sigesapol_egresos_oct_2026.csv'))
args = ap.parse_args()


def leer(ruta):
    # Adminer puede exportar con ',' o ';' y con BOM: se detecta el separador.
    df = pd.read_csv(ruta, sep=None, engine='python', dtype=str, encoding='utf-8-sig',
                     keep_default_na=False, na_values=['', 'NULL'])
    df.columns = df.columns.str.strip().str.upper()  # psql devuelve alias en minúscula
    falta = set(COLS) - set(df.columns)
    if falta:
        raise SystemExit(f'{ruta}: faltan columnas {sorted(falta)}')
    return df[COLS]


det = pd.concat([leer(args.seis), leer(args.sig)], ignore_index=True)
det['CODIGO_IPRESS'] = det['CODIGO_IPRESS'].str.strip().str.zfill(8)
det = det[det['CODIGO_IPRESS'] != '00013591']  # regla: sin Hosp. Luis N. Sáenz
det['DNI_CRUCE'] = det['DNI'].fillna('').str.strip().str.lstrip('0')
det['ING'] = pd.to_datetime(det['FECHA_INGRESO'], format='ISO8601').dt.normalize()
det['ALTA'] = pd.to_datetime(det['FECHA_ALTA'], format='ISO8601').dt.normalize()
det = det[det['ALTA'].notna()]  # sin alta = sigue hospitalizado, no es egreso
det['UID'] = det['FUENTE'] + ':' + det['ID_ATENCION']

# --- duplicados internos: misma estancia cargada dos veces en un sistema ---
# (mismo DNI + IPRESS + día de ingreso). Se deja el registro de ID más alto,
# como en el cruce de morbilidad. Sin DNI no se puede saber: se conservan.
det['ID_NUM'] = pd.to_numeric(det['ID_ATENCION'])
det = det.sort_values(['FUENTE', 'ID_NUM'])
dup = det.duplicated(['FUENTE', 'DNI_CRUCE', 'CODIGO_IPRESS', 'ING'], keep='last') & (det['DNI_CRUCE'] != '')
dup_internos = det[dup]
det = det[~dup]

# --- candidatos: mismo DNI + IPRESS y estancias que se solapan ---
s = det[(det['FUENTE'] == 'SEIS') & (det['DNI_CRUCE'] != '')]
g = det[(det['FUENTE'] == 'SIGESAPOL') & (det['DNI_CRUCE'] != '')]
cand = s.merge(g, on=['DNI_CRUCE', 'CODIGO_IPRESS'], suffixes=('_S', '_G'))
cand = cand[(cand['ING_S'] <= cand['ALTA_G']) & (cand['ING_G'] <= cand['ALTA_S'])].copy()
cand['DIF'] = ((cand['ING_S'] - cand['ING_G']).abs() + (cand['ALTA_S'] - cand['ALTA_G']).abs()).dt.days
cand = cand.sort_values(['DIF', 'UID_S', 'UID_G'])

# --- emparejamiento 1 a 1, el más parecido primero ---
usados, pares = set(), []
for r in cand.itertuples():
    if r.UID_S in usados or r.UID_G in usados:
        continue
    usados.update((r.UID_S, r.UID_G))
    metodo = 'PAR_IGUAL' if r.DIF == 0 else ('PAR_MISMO_INGRESO' if r.ING_S == r.ING_G else 'PAR_SOLAPE')
    prima_sig = r.ALTA_S.strftime('%Y%m') >= PERIODO_SIGESAPOL
    pares.append((r.UID_S, r.UID_G, metodo, r.UID_G if prima_sig else r.UID_S))
pares = pd.DataFrame(pares, columns=['UID_S', 'UID_G', 'CRUCE', 'UID_CONSERVA'])

cruce = pd.concat([pares[['UID_S', 'CRUCE']].rename(columns={'UID_S': 'UID'}),
                   pares[['UID_G', 'CRUCE']].rename(columns={'UID_G': 'UID'})])
det = det.merge(cruce, on='UID', how='left')
det['CRUCE'] = det['CRUCE'].fillna('SOLO_' + det['FUENTE'])
pareja = dict(zip(pares['UID_S'], pares['UID_G'])) | dict(zip(pares['UID_G'], pares['UID_S']))
det['ID_PAR'] = det['UID'].map(pareja).str.split(':').str[1]
# --- absorbidos: registro sin pareja que cae dentro de una estancia del otro
# sistema que ya fue emparejada (p. ej. SIGESAPOL 2-9 oct vs SEIS 2 oct y 9 oct).
sueltos = det[det['CRUCE'].str.startswith('SOLO_') & (det['DNI_CRUCE'] != '')]
otros = det[det['CRUCE'].str.startswith('PAR_')]
x = sueltos.merge(otros, on=['DNI_CRUCE', 'CODIGO_IPRESS'], suffixes=('', '_O'))
x = x[(x['FUENTE'] != x['FUENTE_O']) & (x['ING'] <= x['ALTA_O']) & (x['ING_O'] <= x['ALTA'])]
det.loc[det['UID'].isin(x['UID']), 'CRUCE'] = 'ABSORBIDO'
det['ID_PAR'] = det['ID_PAR'].fillna(det['UID'].map(x.drop_duplicates('UID').set_index('UID')['ID_ATENCION_O']))

det['CONSERVADA'] = det['CRUCE'].str.startswith('SOLO_') | det['UID'].isin(pares['UID_CONSERVA'])

# --- egresos del mes por la fecha de alta del registro conservado ---
mes = pd.Period(args.mes, freq='M')
det['EN_MES'] = det['ALTA'].dt.to_period('M') == mes
final = det[det['CONSERVADA'] & det['EN_MES']]
etq = args.mes.replace('-', '_')
final.drop(columns=['ING', 'ALTA', 'UID', 'ID_NUM', 'CONSERVADA', 'EN_MES']).sort_values(
    ['CODIGO_IPRESS', 'FECHA_ALTA']).to_csv(DATOS / f'egresos_dedup_{etq}.csv', index=False,
                                           encoding='utf-8-sig')

# --- resumen por IPRESS ---
# SEIS_MES / SIGESAPOL_MES = lo que reporta cada app (antes de deduplicar).
crudo = pd.concat([det, dup_internos])
crudo = crudo[crudo['ALTA'].dt.to_period('M') == mes]
nombres = crudo.groupby('CODIGO_IPRESS')['IPRESS'].first()
dup_mes = dup_internos[dup_internos['ALTA'].dt.to_period('M') == mes]
abs_mes = det[(det['CRUCE'] == 'ABSORBIDO') & det['EN_MES']]
resumen = pd.DataFrame({
    'SEIS_MES': crudo[crudo['FUENTE'] == 'SEIS'].groupby('CODIGO_IPRESS').size(),
    'SIGESAPOL_MES': crudo[crudo['FUENTE'] == 'SIGESAPOL'].groupby('CODIGO_IPRESS').size(),
    'DUP_INTERNOS_QUITADOS': dup_mes.groupby('CODIGO_IPRESS').size(),
    'ABSORBIDOS_QUITADOS': abs_mes.groupby('CODIGO_IPRESS').size(),
    'EN_AMBOS': final[final['CRUCE'].str.startswith('PAR_')].groupby('CODIGO_IPRESS').size(),
    'SOLO_SEIS': final[final['CRUCE'] == 'SOLO_SEIS'].groupby('CODIGO_IPRESS').size(),
    'SOLO_SIGESAPOL': final[final['CRUCE'] == 'SOLO_SIGESAPOL'].groupby('CODIGO_IPRESS').size(),
    'EGRESOS_UNICOS': final.groupby('CODIGO_IPRESS').size(),
}).fillna(0).astype(int)
resumen.insert(0, 'IPRESS', nombres.reindex(resumen.index))
resumen = resumen.reset_index().rename(columns={'index': 'CODIGO_IPRESS'})
resumen.loc[len(resumen)] = ['TOTAL', ''] + resumen.iloc[:, 2:].sum().tolist()
resumen.to_csv(BASE / f'resumen_egresos_{etq}.csv', index=False, encoding='utf-8-sig')

pd.set_option('display.width', 200)
print(f'Egresos {args.mes}\n')
print(resumen.to_string(index=False))
print('\nPares por método:', pares['CRUCE'].value_counts().to_dict())
en_mes_uid = det.set_index('UID')['EN_MES']
print('Pares cuya alta cae en meses distintos según el sistema:',
      int((pares['UID_S'].map(en_mes_uid) != pares['UID_G'].map(en_mes_uid)).sum()))
