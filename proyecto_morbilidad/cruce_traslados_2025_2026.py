# -*- coding: utf-8 -*-
"""
Cruce y deduplicación SEIS x SIGESAPOL — CPMS de traslado y transporte asistido.
Periodo: 2025-01 a 2026-09.

Códigos evaluados:
  99441     Traslado sin riesgo potencial para la vida
  99441.02  Traslado sin riesgo, 30 min adicionales
  99442     Transporte asistido con asistencia médica básica
  99442.01  Transporte asistido básico, 30 min adicionales
  99443     Transporte asistido en estado crítico (asistencia avanzada)
  99443.01  Transporte asistido avanzado, 30 min adicionales

Reglas fijas del proyecto:
  - Solo IPRESS de nivel I y II. Se excluye SIEMPRE el HOSPITAL NACIONAL PNP
    LUIS N. SAENZ ('00013591'), que es nivel III. El filtro ya viene aplicado
    en ambas extracciones.
  - Corte del periodo: 202501 a 202608. Septiembre 2026 NO se considera (mes
    incompleto en ambas bases).
  - Los dos sistemas se SUMAN. La precedencia solo decide cuál registro se
    conserva cuando la MISMA prestación está cargada en ambos; nunca descarta
    registros que existen en un solo sistema.
  - Precedencia por periodo (indicación del usuario, 2026-09-28):
        hasta 202604  -> prima SEIS
        desde 202605  -> prima SIGESAPOL

Llave de EVENTO: DNI + FECHA (día) + IPRESS

  Si un mismo evento aparece en ambos sistemas, se conservan SOLO las filas del
  sistema que prima en ese periodo y se descartan todas las del otro (incluidos
  los códigos complementarios .01/.02 de ese evento).

  El CPMS NO entra en la llave a propósito: se comprobó que un mismo traslado
  puede venir codificado distinto en cada sistema (SEIS 99441/99442 vs
  SIGESAPOL 99443 en Leguía). Con el CPMS dentro de la llave esos casos se
  contaban dos veces.

  El TIPO_ATENCION tampoco entra, a diferencia de
  proyecto_morbilidad/deduplicar_cruce.py: en SEIS estos traslados son
  atenciones de tipo 'PR' (procedimiento), mientras que en SIGESAPOL el mismo
  traslado cuelga de la prestación ambulatoria o de emergencia
  (id_tipo_atencion 1/2/3). Usarlo como llave dura impediría cualquier match.

Entradas (TSV, generados con las consultas de la sesión):
  seis_extraccion.tsv       DNI, FECHA, IPRESS, CPMS, ID_ATENCION, TIPO_ATENCION, TIPO_DETALLE
  sigesapol_extraccion.tsv  DNI, FECHA, IPRESS, CPMS, ID_PRESTACION, TIPO_ATENCION, CANTIDAD

Salidas:
  traslados_dedup_2025_2026.csv    detalle deduplicado, una fila por traslado
  traslados_resumen_2025_2026.csv  agregado por periodo, nivel, CPMS y fuente
"""
import pathlib
import sys
import pandas as pd

SAENZ = '00013591'
NIVEL_II = {'00011794', '00014718', '00016094', '00011833'}
CODIGOS = ['99441', '99441.02', '99442', '99442.01', '99443', '99443.01']
# Etiqueta corta para tablas y gráficos: la descripción oficial de los códigos
# .01/.02 pasa de 200 caracteres y no entra en una dinámica.
CPMS_CORTO = {
    '99441':    'Traslado sin riesgo',
    '99441.02': 'Traslado sin riesgo (30 min adic.)',
    '99442':    'Transporte asistido básico',
    '99442.01': 'Transporte asistido básico (30 min adic.)',
    '99443':    'Transporte asistido avanzado',
    '99443.01': 'Transporte asistido avanzado (30 min adic.)',
}
PERIODO_INI = '202501'
PERIODO_FIN = '202608'        # setiembre 2026 queda fuera: mes incompleto
CORTE_SIGESAPOL = '202605'    # desde este periodo prima SIGESAPOL; antes, SEIS

seis_path, sig_path, out_dir = sys.argv[1], sys.argv[2], sys.argv[3]

seis = pd.read_csv(seis_path, sep='\t', dtype=str).rename(columns={'ID_ATENCION': 'ID_ORIGEN'})
sig = pd.read_csv(sig_path, sep='\t', dtype=str).rename(columns={'ID_PRESTACION': 'ID_ORIGEN'})
seis['FUENTE'] = 'SEIS'
sig['FUENTE'] = 'SIGESAPOL'
print(f'SEIS filas crudas: {len(seis)} | SIGESAPOL filas crudas: {len(sig)}')

# Guardia: la regla de nivel I/II debe venir aplicada desde el SQL.
for nombre, df in (('SEIS', seis), ('SIGESAPOL', sig)):
    intrusos = (df['IPRESS'] == SAENZ).sum()
    if intrusos:
        sys.exit(f'ERROR: {nombre} trae {intrusos} filas de Luis N. Saenz ({SAENZ}); revisar el WHERE.')

COLS = ['DNI', 'FECHA', 'IPRESS', 'CPMS', 'ID_ORIGEN', 'TIPO_ATENCION', 'FUENTE']
seis, sig = seis[COLS].copy(), sig[COLS].copy()

# 0) Recorte del periodo: 202501 a 202608.
for nombre in ('SEIS', 'SIGESAPOL'):
    df = seis if nombre == 'SEIS' else sig
    per = df['FECHA'].str[:4] + df['FECHA'].str[5:7]
    fuera = int(((per < PERIODO_INI) | (per > PERIODO_FIN)).sum())
    if fuera:
        print(f'  {nombre}: {fuera} filas fuera de {PERIODO_INI}-{PERIODO_FIN}, descartadas')
    if nombre == 'SEIS':
        seis = seis[(per >= PERIODO_INI) & (per <= PERIODO_FIN)].copy()
    else:
        sig = sig[(per >= PERIODO_INI) & (per <= PERIODO_FIN)].copy()

# 1) Filas exactamente duplicadas dentro de cada sistema (mismo registro cargado dos veces).
for nombre, df in (('SEIS', seis), ('SIGESAPOL', sig)):
    dup = df.duplicated(subset=['DNI', 'FECHA', 'IPRESS', 'CPMS', 'ID_ORIGEN']).sum()
    print(f'  {nombre}: {dup} filas exactamente duplicadas')
seis = seis.drop_duplicates(subset=['DNI', 'FECHA', 'IPRESS', 'CPMS', 'ID_ORIGEN'])
sig = sig.drop_duplicates(subset=['DNI', 'FECHA', 'IPRESS', 'CPMS', 'ID_ORIGEN'])

# 2) Llave de EVENTO (sin CPMS ni tipo de atención).
for df in (seis, sig):
    df['DNI'] = df['DNI'].str.strip().str.lstrip('0')
    df['PERIODO'] = df['FECHA'].str[:4] + df['FECHA'].str[5:7]
    df['EVENTO'] = (df['DNI'] + '|' + df['FECHA'].str[:10] + '|' + df['IPRESS'].str.strip())

# 3) Resolución de eventos presentes en AMBOS sistemas, por precedencia.
duplicados = set(seis['EVENTO']) & set(sig['EVENTO'])
prima_sig = {ev for ev in duplicados
             if seis.loc[seis['EVENTO'] == ev, 'PERIODO'].iloc[0] >= CORTE_SIGESAPOL}
prima_seis = duplicados - prima_sig
print(f'  Eventos en ambos sistemas: {len(duplicados)} '
      f'(prima SEIS en {len(prima_seis)}, prima SIGESAPOL en {len(prima_sig)})')

seis_out = seis[~seis['EVENTO'].isin(prima_sig)].copy()
sig_out = sig[~sig['EVENTO'].isin(prima_seis)].copy()
print(f'  Filas descartadas por precedencia: SEIS {len(seis) - len(seis_out)}, '
      f'SIGESAPOL {len(sig) - len(sig_out)}')

for df in (seis_out, sig_out):
    df['CONTROL'] = ''
seis_out.loc[seis_out['EVENTO'].isin(prima_seis), 'CONTROL'] = 'EVENTO_TAMBIEN_EN_SIGESAPOL'
sig_out.loc[sig_out['EVENTO'].isin(prima_sig), 'CONTROL'] = 'EVENTO_TAMBIEN_EN_SEIS'

final = pd.concat([seis_out, sig_out], ignore_index=True)
final['NIVEL_IPRESS'] = final['IPRESS'].map(lambda c: 'NIVEL II' if c in NIVEL_II else 'NIVEL I')

# 4) Descripciones, para que el CSV se pueda reportar sin cruzar nada más.
# El nombre de IPRESS sale SOLO del catálogo de SEIS (ac_sucursal): SIGESAPOL
# escribe algunos distinto ("CUZCO" vs "CUSCO", tildes) y mezclarlos generaría
# dos etiquetas para la misma IPRESS en una tabla dinámica.
cat_dir = pathlib.Path(__file__).parent
ipress_cat = pd.read_csv(cat_dir / 'catalogo_ipress.tsv', sep='\t', dtype=str)
cpms_cat = pd.read_csv(cat_dir / 'catalogo_cpms.tsv', sep='\t', dtype=str)
ipress_cat['IPRESS_NOMBRE'] = ipress_cat['IPRESS_NOMBRE'].str.strip()

final = final.merge(ipress_cat, on='IPRESS', how='left').merge(cpms_cat, on='CPMS', how='left')
final['CPMS_RESUMEN'] = final['CPMS'].map(CPMS_CORTO)

faltan = final['IPRESS_NOMBRE'].isna().sum() + final['CPMS_DESCRIPCION'].isna().sum()
if faltan:
    print(f'  AVISO: {faltan} filas sin nombre de IPRESS o descripción de CPMS; '
          f'regenerar los catálogos .tsv')

final = final[['PERIODO', 'FECHA', 'DNI', 'IPRESS', 'IPRESS_NOMBRE', 'NIVEL_IPRESS',
               'CPMS', 'CPMS_RESUMEN', 'CPMS_DESCRIPCION', 'TIPO_ATENCION',
               'ID_ORIGEN', 'FUENTE', 'CONTROL']].sort_values(['FECHA', 'DNI', 'CPMS'])

resumen = (final.groupby(['PERIODO', 'NIVEL_IPRESS', 'IPRESS', 'IPRESS_NOMBRE',
                          'CPMS', 'CPMS_RESUMEN', 'FUENTE'])
                .agg(TRASLADOS=('ID_ORIGEN', 'count'), PACIENTES=('DNI', 'nunique'))
                .reset_index()
                .sort_values(['PERIODO', 'NIVEL_IPRESS', 'IPRESS', 'CPMS', 'FUENTE']))

final.to_csv(f'{out_dir}/traslados_dedup_2025_2026.csv', index=False, encoding='utf-8-sig')
resumen.to_csv(f'{out_dir}/traslados_resumen_2025_2026.csv', index=False, encoding='utf-8-sig')

print(f'\nTOTAL deduplicado: {len(final)} traslados | {final["DNI"].nunique()} pacientes')
print(final.groupby(['FUENTE'])['ID_ORIGEN'].count().to_string())
print('\nPor año y fuente:')
print(final.assign(ANIO=final['PERIODO'].str[:4]).pivot_table(
    index='ANIO', columns='FUENTE', values='ID_ORIGEN', aggfunc='count', fill_value=0).to_string())
print('\nPor CPMS y fuente:')
print(final.pivot_table(index='CPMS', columns='FUENTE', values='ID_ORIGEN',
                        aggfunc='count', fill_value=0).reindex(CODIGOS).to_string())
