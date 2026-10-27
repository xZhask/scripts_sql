# -*- coding: utf-8 -*-
"""
Limpieza de CIE10 y descripciones del detalle deduplicado - Enero a Setiembre 2026.

Entrada:  atenciones_dedup_ene_set_2026.csv        <- 03_cruce_seis_sigesapol.py
Salida:   atenciones_dedup_ene_set_2026_limpio.csv  (mismas filas y columnas)

Por qué: el mismo CIE10 llega con descripciones distintas según la fuente
(SEIS en minúsculas/con tildes, SIGESAPOL en mayúsculas sin tildes), y algunos
códigos de SEIS traen espacios al final ('A64.X9 '), lo que en una tabla
dinámica los separa en filas distintas.

Reglas:
  - CIE10: sin espacios y en mayúsculas.
  - DIAGNOSTICO: una sola descripción por CIE10.
      1. La de SIGESAPOL (la más frecuente si hubiera varias). Se prefiere
         porque el catálogo de SEIS tiene errores, p. ej. E11.0 "insulino-
         dependiente" (es NO insulinodependiente) o N18.5 "estadio 4".
      2. Si el código no aparece en SIGESAPOL, la de SEIS más frecuente.
     En ambos casos en MAYÚSCULAS, sin tildes y con espacios simples
     (la Ñ se conserva).
  - Atenciones sin diagnóstico definitivo: CIE10 y DIAGNOSTICO quedan vacíos.

Solo usa la librería estándar (no requiere pandas).
"""
import csv
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path

BASE = Path(__file__).resolve().parent
ENTRADA = BASE / 'atenciones_dedup_ene_set_2026.csv'
SALIDA = BASE / 'atenciones_dedup_ene_set_2026_limpio.csv'


def normalizar(texto):
    """Mayúsculas, sin tildes (conserva Ñ) y espacios simples."""
    texto = texto.strip().upper().replace('Ñ', '\0')
    texto = ''.join(ch for ch in unicodedata.normalize('NFKD', texto)
                    if not unicodedata.combining(ch))
    return ' '.join(texto.replace('\0', 'Ñ').split())


# --- 1ra pasada: frecuencia de cada descripción por código y fuente ---
frec = defaultdict(lambda: {'SIGESAPOL': Counter(), 'SEIS': Counter()})
with open(ENTRADA, encoding='utf-8-sig', newline='') as fh:
    for r in csv.DictReader(fh):
        cie10 = r['CIE10'].strip().upper()
        if cie10:
            frec[cie10][r['FUENTE']][normalizar(r['DIAGNOSTICO'])] += 1

descripcion = {
    cie10: (f['SIGESAPOL'] or f['SEIS']).most_common(1)[0][0]
    for cie10, f in frec.items()
}

# --- 2da pasada: escribir el detalle limpio ---
filas = cambiadas = 0
with open(ENTRADA, encoding='utf-8-sig', newline='') as fin, \
        open(SALIDA, 'w', encoding='utf-8-sig', newline='') as fout:
    lector = csv.DictReader(fin)
    escritor = csv.DictWriter(fout, fieldnames=lector.fieldnames)
    escritor.writeheader()
    for r in lector:
        cie10 = r['CIE10'].strip().upper()
        nueva = descripcion.get(cie10, '')
        cambiadas += (cie10 != r['CIE10']) or (nueva != r['DIAGNOSTICO'])
        r['CIE10'], r['DIAGNOSTICO'] = cie10, nueva
        escritor.writerow(r)
        filas += 1

print('Filas                 :', filas)
print('Filas modificadas     :', cambiadas)
print('CIE10 distintos       :', len(descripcion))
print('Salida                :', SALIDA.name)
