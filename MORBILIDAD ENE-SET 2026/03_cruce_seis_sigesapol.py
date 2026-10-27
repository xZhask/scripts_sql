# -*- coding: utf-8 -*-
"""
Cruce y deduplicación SEIS x SIGESAPOL - Enero a Setiembre 2026.

Entradas (carpeta datos/, NO versionada porque trae DNI):
  - extraccion_seis_ene_set_2026.tsv       <- 01_seis_atenciones_dx_ene_set_2026.sql
  - extraccion_sigesapol_ene_set_2026.csv  <- 02_sigesapol_atenciones_dx_ene_set_2026.sql
Ambas: 1 fila por (atención, diagnóstico definitivo), mismas columnas.

Regla de cruce, a nivel de ATENCIÓN:
  1. Llave = DNI sin ceros a la izquierda + fecha (día) + código IPRESS.
     Si la llave existe en un solo sistema, sus atenciones se conservan
     todas (los dos sistemas se SUMAN).
  2. Si existe en ambos, se forman pares SEIS-SIGESAPOL:
       a. UNICA: cada sistema tiene una sola atención con esa llave -> par,
          aunque la UPS difiera (en ~6% de estos pares el mismo servicio
          viene con otro código UPS, p. ej. emergencia prioridad 3 vs 4).
       b. UPS:   si hay varias, se emparejan las de igual código UPS, en
          orden de ID (la hora no sirve: 98% de SIGESAPOL viene en 00:00).
       c. TIPO:  las que quedan, por igual tipo de atención (AM/EM/HO).
     Lo que no forma par se conserva como atención distinta.
  3. De cada par se conserva la atención de un solo sistema, con todos sus
     diagnósticos (no se mezclan: el diagnóstico principal coincide solo en
     ~74% de los pares):
       - periodo <= 202604: prima SEIS
       - periodo >= 202605: prima SIGESAPOL

Salidas:
  - datos/atenciones_dedup_ene_set_2026.csv  detalle deduplicado (con DNI)
  - resumen_cruce_ene_set_2026.csv           conteos por periodo y fuente (agregado)

Columna CRUCE del detalle:
  SOLO_SEIS / SOLO_SIGESAPOL  la llave existe en un solo sistema
  PAR_UNICA / PAR_UPS / PAR_TIPO  atención emparejada (se conserva la que prima)
  SIN_PAR  la llave existe en ambos pero esta atención no encontró pareja
"""
import pandas as pd
from pathlib import Path

BASE = Path(__file__).resolve().parent
DATOS = BASE / 'datos'
PERIODO_SIGESAPOL = '202605'  # desde este periodo prima SIGESAPOL


def emparejar(pool, cols, metodo):
    """Pares SEIS-SIGESAPOL con igual valor en cols, en orden de ID."""
    pool = pool.dropna(subset=cols).sort_values('ID_NUM')
    pool = pool.assign(RANGO=pool.groupby(cols + ['FUENTE']).cumcount())
    seis = pool[pool['FUENTE'] == 'SEIS']
    sig = pool[pool['FUENTE'] == 'SIGESAPOL']
    pares = seis.merge(sig, on=cols + ['RANGO'], suffixes=('_SEIS', '_SIG'))
    return pares[['ID_ATENCION_SEIS', 'ID_ATENCION_SIG', 'PERIODO_SEIS']].assign(CRUCE=metodo)


seis = pd.read_csv(DATOS / 'extraccion_seis_ene_set_2026.tsv', sep='\t', dtype=str,
                   na_values=['NULL'], keep_default_na=False)
sig = pd.read_csv(DATOS / 'extraccion_sigesapol_ene_set_2026.csv', dtype=str,
                  na_values=[''], keep_default_na=False)
sig.columns = sig.columns.str.upper()  # psql devuelve los alias en minúscula

det = pd.concat([seis, sig], ignore_index=True)
det['DNI_CRUCE'] = det['DNI'].str.strip().str.lstrip('0')
det['LLAVE'] = det['DNI_CRUCE'] + '|' + det['FECHA_ATENCION'] + '|' + det['CODIGO_IPRESS']

# --- una fila por atención ---
aten = det.drop_duplicates(['FUENTE', 'ID_ATENCION'])[
    ['FUENTE', 'ID_ATENCION', 'PERIODO', 'LLAVE', 'CODIGO_UPS', 'TIPO_ATENCION']].copy()
aten['ID_NUM'] = aten['ID_ATENCION'].astype('int64')

n = aten.pivot_table(index='LLAVE', columns='FUENTE', values='ID_ATENCION',
                     aggfunc='count', fill_value=0)
en_ambos = n.index[(n['SEIS'] > 0) & (n['SIGESAPOL'] > 0)]
unica = n.index[(n['SEIS'] == 1) & (n['SIGESAPOL'] == 1)]

# --- emparejamiento en tres pasos ---
pool = aten[aten['LLAVE'].isin(en_ambos)]
pares = []
for cols, metodo, filtro in ((['LLAVE'], 'PAR_UNICA', pool['LLAVE'].isin(unica)),
                             (['LLAVE', 'CODIGO_UPS'], 'PAR_UPS', None),
                             (['LLAVE', 'TIPO_ATENCION'], 'PAR_TIPO', None)):
    p = emparejar(pool if filtro is None else pool[filtro], cols, metodo)
    pares.append(p)
    usados = set(p['ID_ATENCION_SEIS']) | set(p['ID_ATENCION_SIG'])
    pool = pool[~pool['ID_ATENCION'].isin(usados)]
pares = pd.concat(pares, ignore_index=True)

# --- qué atención de cada par se descarta ---
prima_sig = pares['PERIODO_SEIS'] >= PERIODO_SIGESAPOL
descarte = pd.concat([
    pd.DataFrame({'FUENTE': 'SEIS', 'ID_ATENCION': pares.loc[prima_sig, 'ID_ATENCION_SEIS']}),
    pd.DataFrame({'FUENTE': 'SIGESAPOL', 'ID_ATENCION': pares.loc[~prima_sig, 'ID_ATENCION_SIG']}),
])
cruce = pd.concat([
    pares[['ID_ATENCION_SEIS', 'CRUCE']].rename(columns={'ID_ATENCION_SEIS': 'ID_ATENCION'}).assign(FUENTE='SEIS'),
    pares[['ID_ATENCION_SIG', 'CRUCE']].rename(columns={'ID_ATENCION_SIG': 'ID_ATENCION'}).assign(FUENTE='SIGESAPOL'),
])

aten = aten.merge(cruce, on=['FUENTE', 'ID_ATENCION'], how='left')
aten['CRUCE'] = aten['CRUCE'].fillna(
    aten['LLAVE'].isin(en_ambos).map({True: 'SIN_PAR', False: None})).fillna('SOLO_' + aten['FUENTE'])
aten = aten.merge(descarte.assign(DESCARTADA=True), on=['FUENTE', 'ID_ATENCION'], how='left')
aten['DESCARTADA'] = aten['DESCARTADA'].fillna(False).astype(bool)

# --- detalle final ---
final = det.merge(aten[['FUENTE', 'ID_ATENCION', 'CRUCE', 'DESCARTADA']], on=['FUENTE', 'ID_ATENCION'])
final = final[~final['DESCARTADA']].drop(columns=['DESCARTADA', 'LLAVE'])
final.to_csv(DATOS / 'atenciones_dedup_ene_set_2026.csv', index=False, encoding='utf-8-sig')

# --- resumen de control ---
resumen = (
    aten.groupby(['PERIODO', 'FUENTE'])
        .agg(ATENCIONES_EXTRAIDAS=('ID_ATENCION', 'size'),
             EMPAREJADAS=('CRUCE', lambda c: c.str.startswith('PAR_').sum()),
             SIN_PAR=('CRUCE', lambda c: c.eq('SIN_PAR').sum()),
             DESCARTADAS_DUPLICADAS=('DESCARTADA', 'sum'))
        .assign(ATENCIONES_FINALES=lambda d: d['ATENCIONES_EXTRAIDAS'] - d['DESCARTADAS_DUPLICADAS'])
        .reset_index()
)
resumen.to_csv(BASE / 'resumen_cruce_ene_set_2026.csv', index=False, encoding='utf-8-sig')

af = final.drop_duplicates(['FUENTE', 'ID_ATENCION'])
pd.set_option('display.width', 200)
print(resumen.to_string(index=False))
print()
print('Pares por método:', pares['CRUCE'].value_counts().to_dict())
print('Atenciones extraídas :', len(aten))
print('Descartadas (dup)    :', int(aten['DESCARTADA'].sum()))
print('ATENCIONES FINALES   :', len(af))
print('ATENDIDOS (DNI)      :', af['DNI_CRUCE'].nunique())
print('IPRESS               :', af['CODIGO_IPRESS'].nunique())
print('Atenciones sin dx definitivo:', int(final.groupby(['FUENTE', 'ID_ATENCION'])['CIE10'].count().eq(0).sum()))
