# -*- coding: utf-8 -*-
"""
Consolidado de MORTALIDAD DE HOSPITALIZACION ene-ago 2026,
deduplicado SEIS x SIGESAPOL.

FUENTES (ambas solo hospitalizacion, alcance equivalente):
  - SEIS      : reporte_mortalidad_paciente_20260904_100700.xlsx
                hoja "mortalidad2026_seis"  (36 defunciones)
  - SIGESAPOL : reporte_mortalidad_paciente_2026hosp.xlsx
                hoja "Reporte"              (59 defunciones)

  OJO: el archivo ...20260904_100700.xlsx tiene tambien una hoja
  "mortalidad2026_sigesapol" que NO se usa: incluye emergencia ademas de
  hospitalizacion, por lo que no es comparable con el lado SEIS.

Decisiones tomadas por el usuario (2026-09-04):
  - CAUSA DE MUERTE = columna "final" LITERAL de cada sistema, con fallback
    a intermedio y luego basico cuando "final" viene vacia.
    Precedencia cuando la defuncion esta en ambos sistemas: SEIS primero.
    NOTA: el analisis mostro que la columna "final" de SEIS equivale mas
    seguido a la columna "basico" de SIGESAPOL (causa terminal) que a su
    propia columna "final"; con este criterio literal se mezclan ambos
    conceptos. Queda documentado a pedido del usuario.
  - PERIODO recortado a 2026-01-01 .. 2026-08-31 para que ambas fuentes
    cubran la misma ventana.
"""
# openpyxl no puede abrir el xlsx de sigesapol (margenes de pagina vacios);
# se hace tolerante la conversion a float antes de importar openpyxl.
import openpyxl.descriptors.base as _b
_orig_convert = _b._convert
_b._convert = lambda t, v: 0.0 if (v == '' and t is float) else _orig_convert(t, v)

import openpyxl, unicodedata, re, difflib, csv
from collections import Counter

XLSX_SEIS = 'reporte_mortalidad_paciente_20260904_100700.xlsx'
HOJA_SEIS = 'mortalidad2026_seis'
XLSX_SIG = 'reporte_mortalidad_paciente_2026hosp.xlsx'
HOJA_SIG = 'Reporte'

NIVEL_II = {'00011794', '00014718', '00016094', '00011833'}
STOP = {'VDA', 'VIUDA', 'DE', 'DEL', 'LA', 'LAS', 'LOS', 'Y'}
C = ['ipress','nom_ip','id','fecha','pac','basico','nb','intermedio','ni','final','nf',
     'edad_meses','edad','ben','grado','sit']
DESDE, HASTA = '2026-01-01', '2026-08-31'


def na(v):
    if v is None:
        return ''
    return unicodedata.normalize('NFKD', str(v)).encode('ascii', 'ignore').decode('ascii').strip()


def nn(v):
    s = na(v).upper()
    s = re.sub(r'[^A-Z ]', ' ', s)
    return ' '.join(sorted(t for t in s.split() if t and t not in STOP))


def fec(v):
    return na(v)[:10]


def leer(path, hoja):
    wb = openpyxl.load_workbook(path, data_only=True)
    return [dict(zip(C, r)) for r in list(wb[hoja].iter_rows(values_only=True))[1:]]


seis = leer(XLSX_SEIS, HOJA_SEIS)
sig = leer(XLSX_SIG, HOJA_SIG)
for d in seis + sig:
    d['_k'] = nn(d['pac'])

print('FUENTES (solo hospitalizacion)')
print('  SEIS     :', len(seis), 'defunciones')
print('  SIGESAPOL:', len(sig), 'defunciones')

# --- emparejar: misma IPRESS + nombre exacto o difuso (>=0.85) ---
pares, solo_seis, usados = [], [], set()
for d in seis:
    cands = [s for s in sig if na(s['ipress']) == na(d['ipress']) and id(s) not in usados]
    m = next((s for s in cands if s['_k'] == d['_k']), None)
    modo = 'EXACTO'
    if m is None:
        best, sc = None, 0.0
        for s in cands:
            r = difflib.SequenceMatcher(None, d['_k'], s['_k']).ratio()
            if r > sc:
                best, sc = s, r
        if best is not None and sc >= 0.85:
            m, modo = best, 'DIFUSO(%.2f)' % sc
    if m is None:
        solo_seis.append(d)
    else:
        usados.add(id(m))
        pares.append((d, m, modo))
solo_sig = [s for s in sig if id(s) not in usados]

print()
print('--- CRUCE ---')
print('  En AMBOS sistemas:', len(pares),
      '( exactos:', sum(1 for p in pares if p[2] == 'EXACTO'),
      '/ difusos:', sum(1 for p in pares if p[2] != 'EXACTO'), ')')
for d, s, modo in pares:
    if modo != 'EXACTO':
        print('      difuso:', na(d['pac']), '<->', na(s['pac']), modo)
print('  Solo SEIS     :', len(solo_seis))
for d in solo_seis:
    print('      ', na(d['pac']), fec(d['fecha']))
print('  Solo SIGESAPOL:', len(solo_sig))
print('  TOTAL UNICAS (antes del recorte):', len(pares) + len(solo_seis) + len(solo_sig))
print('  Suma ingenua sin deduplicar     :', len(seis) + len(sig),
      '-> sobreconteo evitado:', len(pares))


def causa(d_seis, d_sig):
    nom_col = {'final': 'nf', 'intermedio': 'ni', 'basico': 'nb'}
    for d, etiqueta in ((d_seis, 'SEIS'), (d_sig, 'SIGESAPOL')):
        if not d:
            continue
        for c in ('final', 'intermedio', 'basico'):
            if na(d[c]):
                return na(d[c]), na(d[nom_col[c]]).upper(), etiqueta + '.' + c
    return 'SIN DATO', 'SIN DATO', '-'


registros = ([(a, b, 'AMBOS') for a, b, _ in pares]
             + [(a, None, 'SOLO_SEIS') for a in solo_seis]
             + [(None, b, 'SOLO_SIGESAPOL') for b in solo_sig])

filas, fuera = [], 0
for d_seis, d_sig, fuente in registros:
    ref = d_seis or d_sig
    f = fec(ref['fecha'])
    if not (DESDE <= f <= HASTA):
        fuera += 1
        continue
    ip = na(ref['ipress'])
    cod, desc, origen = causa(d_seis, d_sig)
    filas.append({
        'FUENTE': fuente,
        'NIVEL_DE_IPRESS': 'NIVEL II' if ip in NIVEL_II else 'NIVEL I',
        'IPRESS': ip,
        'NOMBRE_IPRESS': na(ref['nom_ip']),
        'FECHA_DEFUNCION': f,
        'PACIENTE': na(ref['pac']),
        'EDAD': na(ref['edad']),
        'BENEFICIARIO': na(ref['ben']).upper(),
        'SITUACION': na(ref['sit']).upper(),
        'CIE10': cod,
        'DESCRIPCION_CIE10': desc,
        'ORIGEN_DIAGNOSTICO': origen,
        'ES_DX_Z': 'SI' if cod.startswith('Z') else 'NO',
        'SEIS_BASICO': na(d_seis['basico']) if d_seis else '',
        'SEIS_INTERMEDIO': na(d_seis['intermedio']) if d_seis else '',
        'SEIS_FINAL': na(d_seis['final']) if d_seis else '',
        'SIG_BASICO': na(d_sig['basico']) if d_sig else '',
        'SIG_INTERMEDIO': na(d_sig['intermedio']) if d_sig else '',
        'SIG_FINAL': na(d_sig['final']) if d_sig else '',
    })
filas.sort(key=lambda r: (r['IPRESS'], r['FECHA_DEFUNCION']))

with open('mortalidad_dedup_ene_ago_2026.csv', 'w', newline='', encoding='utf-8-sig') as f:
    w = csv.DictWriter(f, fieldnames=list(filas[0].keys()))
    w.writeheader()
    w.writerows(filas)

agg = Counter((r['NIVEL_DE_IPRESS'], r['CIE10'], r['DESCRIPCION_CIE10'], r['ES_DX_Z']) for r in filas)
cons = [{'NIVEL_DE_IPRESS': k[0], 'CIE10': k[1], 'DESCRIPCION_CIE10': k[2],
         'CANTIDAD_DE_DEFUNCIONES': v, 'ES_DX_Z': k[3]} for k, v in agg.items()]
cons.sort(key=lambda r: (r['NIVEL_DE_IPRESS'], -r['CANTIDAD_DE_DEFUNCIONES'], r['CIE10']))
with open('consolidado_mortalidad_ene_ago_2026.csv', 'w', newline='', encoding='utf-8-sig') as f:
    w = csv.DictWriter(f, fieldnames=list(cons[0].keys()))
    w.writeheader()
    w.writerows(cons)

agg2 = Counter((r['NIVEL_DE_IPRESS'], r['IPRESS'], r['NOMBRE_IPRESS'], r['CIE10'],
                r['DESCRIPCION_CIE10'], r['ES_DX_Z']) for r in filas)
cons2 = [{'NIVEL_DE_IPRESS': k[0], 'IPRESS': k[1], 'NOMBRE_IPRESS': k[2], 'CIE10': k[3],
          'DESCRIPCION_CIE10': k[4], 'CANTIDAD_DE_DEFUNCIONES': v, 'ES_DX_Z': k[5]}
         for k, v in agg2.items()]
cons2.sort(key=lambda r: (r['IPRESS'], -r['CANTIDAD_DE_DEFUNCIONES'], r['CIE10']))
with open('consolidado_mortalidad_por_ipress_ene_ago_2026.csv', 'w', newline='', encoding='utf-8-sig') as f:
    w = csv.DictWriter(f, fieldnames=list(cons2[0].keys()))
    w.writeheader()
    w.writerows(cons2)

print()
print('--- PERIODO', DESDE, 'a', HASTA, '---')
print('  Descartadas por fuera de periodo:', fuera)
print('  DEFUNCIONES UNICAS FINALES:', len(filas))
print('  por fuente:', dict(Counter(r['FUENTE'] for r in filas)))
print('  por ipress:')
for k, v in Counter((r['IPRESS'], r['NOMBRE_IPRESS']) for r in filas).most_common():
    print('     ', k, '->', v)
print('  pacientes distintos (control):', len({nn(r['PACIENTE']) for r in filas}))
print('  origen del diagnostico:', dict(Counter(r['ORIGEN_DIAGNOSTICO'] for r in filas)))
print()
print('--- TOP 10 CAUSAS ---')
for r in cons[:10]:
    print('   %-7s %-54s %3d' % (r['CIE10'], r['DESCRIPCION_CIE10'][:54], r['CANTIDAD_DE_DEFUNCIONES']))
print()
print('  Codigos CIE10 distintos:', len(cons))
