# -*- coding: utf-8 -*-
"""
Cruce y deduplicación SEIS (sgcoresys) x SIGESAPOL - Enero a Agosto 2026.

Lógica:
  1. SEIS ya viene con 1 fila por atención (diagnóstico principal, id_secuencia=1).
     Se toma como fuente autoritativa: todo lo que ya está en SEIS se cuenta
     desde SEIS y NO se vuelve a contar si aparece también en SIGESAPOL.
  2. SIGESAPOL trae varias filas por atención (múltiples diagnósticos por
     "prestacion", sin restricción a diagnóstico principal) y además tiene
     filas duplicadas exactas (mismo id_atencion + mismo CIE10 repetido).
     Primero se eliminan esas filas exactamente duplicadas.
  3. Se identifica qué ATENCIONES (no filas) de SIGESAPOL corresponden a una
     atención que YA está en SEIS, usando como llave: mismo DNI + mismo DÍA
     (no hora) + mismo ID_IPRESS + mismo TIPO_ATENCION. El código de
     consultorio NO se usa como llave dura (el usuario confirmó que a veces
     varía ligeramente entre sistemas); se usa solo para reportar qué tan
     seguido coincide, como control de calidad del criterio de match.
  4. Toda atención de SIGESAPOL cuya llave coincide con una atención SEIS se
     descarta por completo (todas sus filas/diagnósticos, incluyendo Z), para
     no duplicar el conteo. Lo que NO coincide se conserva integro (incluye
     códigos Z, ya que se necesitan para otro tipo de conteos aparte del top).
  5. Resultado final = SEIS completo + SIGESAPOL no emparejado.
  6. Se arma el resumen: ATENCIONES y ATENDIDOS por NIVEL_IPRESS,
     TIPO_ATENCION y CIE10.

Salidas (en esta misma carpeta):
  - atenciones_dedup_ene_ago_2026.csv   (detalle fila a fila, ya deduplicado)
  - resumen_nivel_tipo_cie10_ene_ago_2026.csv (agregado final)
"""
import pandas as pd

SEIS_NOZ = 'atenciones_seis_dx_noz.csv'
SEIS_Z = 'atenciones_seis_dx_z.csv'
SIGESAPOL = 'atenciones_sigesapol_26.csv'

COLS = ['DNI', 'FECHA_ATENCION', 'ID_ATENCION', 'TIPO_ATENCION', 'ID_IPRESS',
        'NIVEL_IPRESS', 'ID_UPS', 'UPS_DESCRIPCION', 'CIE10', 'DESCRIPCION_CIE10']

print('Cargando SEIS...')
seis = pd.concat([
    pd.read_csv(SEIS_NOZ, sep=';', dtype=str),
    pd.read_csv(SEIS_Z, sep=';', dtype=str),
], ignore_index=True)
seis['SOURCE'] = 'SEIS'
print('  SEIS filas:', len(seis), '| atenciones distintas:', seis['ID_ATENCION'].nunique())

print('Cargando SIGESAPOL (puede tardar)...')
sig = pd.read_csv(SIGESAPOL, dtype=str)
sig['SOURCE'] = 'SIGESAPOL'
print('  SIGESAPOL filas crudas:', len(sig))

# --- 2. quitar filas exactamente duplicadas dentro de sigesapol ---
antes = len(sig)
sig = sig.drop_duplicates(subset=COLS)
print(f'  SIGESAPOL tras quitar {antes - len(sig)} filas exactamente duplicadas: {len(sig)}')
print('  SIGESAPOL atenciones distintas:', sig['ID_ATENCION'].nunique())

# --- 3. llave de match a nivel de ATENCION (no de fila/diagnostico) ---
for df in (seis, sig):
    df['DIA'] = df['FECHA_ATENCION'].str[:10]
    df['MATCH_KEY'] = (df['DNI'].str.strip() + '|' + df['DIA'] + '|'
                        + df['ID_IPRESS'].str.strip() + '|' + df['TIPO_ATENCION'].str.strip())

seis_keys = set(seis['MATCH_KEY'])

sig_visits = sig.drop_duplicates(subset=['ID_ATENCION'])[['ID_ATENCION', 'MATCH_KEY', 'ID_UPS', 'UPS_DESCRIPCION']]
sig_visits = sig_visits.merge(
    seis[['MATCH_KEY', 'ID_UPS', 'UPS_DESCRIPCION']].drop_duplicates(subset=['MATCH_KEY']),
    on='MATCH_KEY', how='left', suffixes=('_SIG', '_SEIS')
)
sig_visits['ES_DUPLICADO'] = sig_visits['MATCH_KEY'].isin(seis_keys)

matched = sig_visits[sig_visits['ES_DUPLICADO']]
consultorio_coincide = (matched['ID_UPS_SIG'] == matched['ID_UPS_SEIS']).sum()
descripcion_coincide = (matched['UPS_DESCRIPCION_SIG'] == matched['UPS_DESCRIPCION_SEIS']).sum()

print()
print('--- Resultado del cruce (a nivel de ATENCION) ---')
print('  Atenciones SIGESAPOL que coinciden con una atencion SEIS (mismo DNI+dia+IPRESS+TIPO_ATENCION):', len(matched), 'de', len(sig_visits))
print('  De esas coincidencias, con MISMO codigo de consultorio (ID_UPS):', consultorio_coincide)
print('  De esas coincidencias, con MISMA descripcion de UPS:', descripcion_coincide)

# --- 4. descartar del lado SIGESAPOL las atenciones ya cubiertas por SEIS ---
dup_ids = set(matched['ID_ATENCION'])
sig_unico = sig[~sig['ID_ATENCION'].isin(dup_ids)].copy()
print()
print('  Filas SIGESAPOL descartadas por duplicadas con SEIS:', len(sig) - len(sig_unico))
print('  Filas SIGESAPOL que se conservan (unicas, incluye Z):', len(sig_unico))

# --- 5. dataset final deduplicado ---
final = pd.concat([seis[COLS + ['SOURCE']], sig_unico[COLS + ['SOURCE']]], ignore_index=True)
final.to_csv('atenciones_dedup_ene_ago_2026.csv', index=False, encoding='utf-8-sig')

print()
print('--- DATASET FINAL DEDUPLICADO ---')
print('  Total filas (atencion+diagnostico):', len(final))
print('  Total atenciones distintas (SOURCE+ID_ATENCION):', final.drop_duplicates(subset=['SOURCE', 'ID_ATENCION']).shape[0])
print('  Total pacientes distintos (DNI):', final['DNI'].nunique())
print('  Por SOURCE:')
print(final.groupby('SOURCE').apply(lambda d: pd.Series({
    'filas': len(d),
    'atenciones': d['ID_ATENCION'].nunique(),
    'pacientes': d['DNI'].nunique(),
})))

# --- 6. resumen atenciones y atendidos por NIVEL, TIPO_ATENCION y CIE10 ---
resumen = (
    final.assign(ATENCION_UID=final['SOURCE'] + '|' + final['ID_ATENCION'])
         .groupby(['NIVEL_IPRESS', 'TIPO_ATENCION', 'CIE10'], as_index=False)
         .agg(
             DESCRIPCION_CIE10=('DESCRIPCION_CIE10', 'first'),
             CANTIDAD_ATENCIONES=('ATENCION_UID', 'nunique'),
             CANTIDAD_ATENDIDOS=('DNI', 'nunique'),
         )
         .sort_values(['NIVEL_IPRESS', 'TIPO_ATENCION', 'CANTIDAD_ATENCIONES'], ascending=[True, True, False])
)
resumen.to_csv('resumen_nivel_tipo_cie10_ene_ago_2026.csv', index=False, encoding='utf-8-sig')

print()
print('--- RESUMEN FINAL (nivel + tipo_atencion) ---')
print(resumen.groupby(['NIVEL_IPRESS', 'TIPO_ATENCION'])[['CANTIDAD_ATENCIONES', 'CANTIDAD_ATENDIDOS']].sum())
print()
print('Filas en el resumen por CIE10:', len(resumen))
print('Listo:')
print('  - atenciones_dedup_ene_ago_2026.csv')
print('  - resumen_nivel_tipo_cie10_ene_ago_2026.csv')
