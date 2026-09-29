-- =============================================================================
-- DETALLE DE ATENCIONES DE PROCEDIMIENTOS (PR) DE UN PACIENTE
-- Base: bdseis_agosto26 (SEIS)
--
-- Salida: 1 fila por procedimiento, con los diagnósticos de la atención en
-- columnas (DX1..DX3).
--   ID_ATENCION | FECHA_ATENCION | ID_IPRESS | IPRESS | ID_UPS | UPS |
--   DNI | PACIENTE | DX1 | DX1_DESCRIPCION | DX1_TIPO | DX2... | DX3... |
--   SECUENCIA | TIPO_DETALLE | CPMS | DESCRIPCION_CPMS
--
-- Parámetros (bloque SET):
--   @dni     -> personamast.documento
--   @ipress  -> atencion.ID_IPRESS (= ac_sucursal.SUCURSAL). Para ubicar el
--               código de una IPRESS:
--               SELECT SUCURSAL, DESCRIPCIONLOCAL FROM ac_sucursal
--               WHERE DESCRIPCIONLOCAL LIKE '%LEGUIA%';
--   @periodo -> atencion.ID_PERIODO en formato YYYYMM
--
-- Criterios:
--   - a.ID_TIPO_ATENCION = 'PR' y a.ESTADO = 'A'.
--   - Se filtra por tipo + periodo + IPRESS para usar el índice
--     atencion_idx_01; atencion.PACIENTE_ID no tiene índice. El filtro por
--     paciente se aplica sobre ese subconjunto (~40k atenciones PR de Leguía
--     en 202507), por eso el periodo y la IPRESS son obligatorios.
--   - OJO: las columnas de `atencion` son latin1 y las variables @ llegan en
--     utf8mb4. Sin el CONVERT(... USING latin1) el motor convierte la columna
--     y el índice solo se usa por ID_TIPO_ATENCION (~11M filas, ~11 s en vez
--     de ~2 s).
--   - Se busca al paciente por documento sin fijar TIPODOCUMENTO: hay
--     personas registradas dos veces con el mismo documento y distinto
--     NUMHIJO. Así se traen ambos registros.
--   - Cada atención PR guarda 3 espacios de diagnóstico (ID_TIPO_DETALLE =
--     'DIA', secuencias 1-3), muchos vacíos. Solo se numeran los que tienen
--     diagnóstico, en orden de secuencia. En 202507 ninguna atención PR tuvo
--     más de 3 diagnósticos (146,094 con 1 | 17,848 con 2 | 5,663 con 3).
--   - Los procedimientos son ID_TIPO_DETALLE 'PRO' (procedimiento) y 'QUI'
--     (quirúrgico). LEFT JOIN: una atención PR sin procedimientos igual
--     aparece, con las columnas de procedimiento en NULL.
--
-- Ejemplo validado (2026-09-16): DNI 74710347, HOSPITAL PNP AUGUSTO B. LEGUIA
-- (00016094), 202507 -> 20 atenciones PR, casi todas con S82.6 (fractura del
-- maléolo externo). El 27792 (QUI) está en la atención 22941166 y el 99246
-- en la 22993980 (con Z00.0).
-- =============================================================================

SET @dni     = '74710347';
SET @ipress  = '00016094';   -- HOSPITAL PNP AUGUSTO B. LEGUIA
SET @periodo = '202507';

WITH atenciones AS (
    SELECT a.id_atencion, a.FECHA_ATENCION, a.ID_IPRESS, a.ID_UPS, a.PACIENTE_ID
    FROM atencion a
    WHERE a.ID_TIPO_ATENCION = 'PR'
      AND a.ID_PERIODO = CONVERT(@periodo USING latin1)
      AND a.ID_IPRESS  = CONVERT(@ipress USING latin1)
      AND a.ESTADO     = 'A'
      AND a.PACIENTE_ID IN (SELECT p.PERSONA FROM personamast p WHERE p.documento = @dni)
),
diagnosticos AS (
    SELECT
        ad.ID_ATENCION,
        dx.CodigoDiagnostico,
        dx.Nombre,
        CASE ad.ID_TIPO_DIAGNOSTICO
            WHEN '01' THEN 'PRESUNTIVO'
            WHEN '02' THEN 'DEFINITIVO'
            WHEN '03' THEN 'REPETIDO'
            ELSE ad.ID_TIPO_DIAGNOSTICO
        END AS TIPO,
        ROW_NUMBER() OVER (PARTITION BY ad.ID_ATENCION ORDER BY ad.ID_SECUENCIA) AS N
    FROM atenciones at
    INNER JOIN atencion_diagnostico ad ON ad.ID_ATENCION = at.id_atencion
    INNER JOIN ss_ge_diagnostico dx    ON dx.IdDiagnostico = ad.ID_DIAGNOSTICO
    WHERE ad.ID_TIPO_DETALLE = 'DIA'
),
diagnosticos_columnas AS (
    SELECT
        ID_ATENCION,
        MAX(CASE WHEN N = 1 THEN CodigoDiagnostico END) AS DX1,
        MAX(CASE WHEN N = 1 THEN Nombre END)            AS DX1_DESCRIPCION,
        MAX(CASE WHEN N = 1 THEN TIPO END)              AS DX1_TIPO,
        MAX(CASE WHEN N = 2 THEN CodigoDiagnostico END) AS DX2,
        MAX(CASE WHEN N = 2 THEN Nombre END)            AS DX2_DESCRIPCION,
        MAX(CASE WHEN N = 2 THEN TIPO END)              AS DX2_TIPO,
        MAX(CASE WHEN N = 3 THEN CodigoDiagnostico END) AS DX3,
        MAX(CASE WHEN N = 3 THEN Nombre END)            AS DX3_DESCRIPCION,
        MAX(CASE WHEN N = 3 THEN TIPO END)              AS DX3_TIPO
    FROM diagnosticos
    GROUP BY ID_ATENCION
)
SELECT
    at.id_atencion                          AS ID_ATENCION,
    DATE(at.FECHA_ATENCION)                 AS FECHA_ATENCION,
    at.ID_IPRESS                            AS ID_IPRESS,
    s.DESCRIPCIONLOCAL                      AS IPRESS,
    at.ID_UPS                               AS ID_UPS,
    u.NOMBRE                                AS UPS,
    p.documento                             AS DNI,
    p.NOMBRECOMPLETO                        AS PACIENTE,
    dc.DX1, dc.DX1_DESCRIPCION, dc.DX1_TIPO,
    dc.DX2, dc.DX2_DESCRIPCION, dc.DX2_TIPO,
    dc.DX3, dc.DX3_DESCRIPCION, dc.DX3_TIPO,
    ad.ID_SECUENCIA                         AS SECUENCIA,
    ad.ID_TIPO_DETALLE                      AS TIPO_DETALLE,
    TRIM(ad.ID_CPT)                         AS CPMS,
    proc.NOMBRE                             AS DESCRIPCION_CPMS
FROM atenciones at
INNER JOIN personamast p                  ON p.PERSONA = at.PACIENTE_ID
LEFT JOIN ac_sucursal s                   ON s.SUCURSAL = at.ID_IPRESS
LEFT JOIN ups u                           ON u.CODIGOUPS = at.ID_UPS
LEFT JOIN diagnosticos_columnas dc        ON dc.ID_ATENCION = at.id_atencion
LEFT JOIN atencion_diagnostico ad         ON ad.ID_ATENCION = at.id_atencion
                                         AND ad.ID_TIPO_DETALLE IN ('PRO','QUI')
LEFT JOIN ss_ge_procedimientomedico proc  ON proc.CODIGOPROCEDIMIENTO = ad.ID_CPT
ORDER BY at.FECHA_ATENCION, at.id_atencion, ad.ID_SECUENCIA;
