-- =============================================================================
-- FUENTE 1 · SEIS · ATENCIONES CON DIAGNÓSTICOS · ENERO - SETIEMBRE 2026
-- Base: bdseis_agosto26 (Laragon MySQL, puerto 3306)
--
-- Salida: 1 fila por (atención, diagnóstico). Columnas IDÉNTICAS a
-- 02_sigesapol_atenciones_dx_ene_set_2026.sql para unir ambas fuentes y
-- deduplicar con 03_cruce_seis_sigesapol.py.
--
-- Criterios:
--   - Atenciones activas (ESTADO = 'A').
--   - Tipos AM (ambulatoria), EM (emergencia, incluye urgencias) y HO
--     (hospitalización).
--   - Fecha de atención entre 2026-01-01 y 2026-09-30. Se filtra también por
--     ID_PERIODO para usar el índice atencion_idx_01.
--   - Pacientes de 18 años a más, edad calculada a la fecha de la atención
--     desde personamast.FECHANACIMIENTO (mismo criterio que en SIGESAPOL;
--     PACIENTE_EDAD difiere en ~2% de casos por redondeo de SEIS).
--   - Solo IPRESS de nivel I y II: se excluye el HOSPITAL NACIONAL PNP LUIS N.
--     SAENZ (00013591, nivel III).
--   - Solo diagnósticos DEFINITIVOS (ID_TIPO_DIAGNOSTICO = '02'), incluidos
--     los códigos Z.
--
-- Limpieza de diagnósticos (la misma que en SIGESAPOL):
--   - ~60% de las filas 'DIA' de atencion_diagnostico están vacías
--     (ID_DIAGNOSTICO y ID_CPT nulos): se descartan.
--   - Una sola fila por atención y diagnóstico (hay CIE10 repetidos con
--     distinta secuencia).
--   - DX_ORDEN se renumera 1, 2, 3... según ID_SECUENCIA entre los
--     definitivos; el 1 hace de diagnóstico principal.
--   - Una atención sin diagnóstico definitivo sale igual, en una fila con
--     DX_ORDEN = 1 y diagnóstico vacío: cuenta para atenciones/atendidos y
--     para el cruce, no para morbilidad.
--
-- Homologación con SIGESAPOL:
--   - TIPO_ATENCION: AM / EM / HO.
--   - TIPO_BENEFICIARIO: TITULAR, CONYUGE, HIJO, PADRES, SOBREVIVIENTE, OTROS.
--     En SEIS es el dato actual del paciente (personamast.ID_BENEFICIARIO).
--   - DNI: se entrega tal cual; SEIS rellena con ceros a la izquierda y el
--     script de cruce los quita.
--   - UPS: código y nombre del catálogo ups. SEIS no tiene consultorio
--     aparte, CONSULTORIO va vacío.
--
-- ⚠ bdseis_agosto26 es la restauración de agosto: setiembre 2026 trae solo
--   ~750 atenciones AM/EM/HO. No afecta el cruce porque desde 202605 prima
--   SIGESAPOL, que sí tiene setiembre completo.
-- =============================================================================

WITH aten AS (
    SELECT
        a.id_atencion,
        a.ID_PERIODO,
        a.FECHA_ATENCION,
        a.ID_TIPO_ATENCION,
        a.ID_IPRESS,
        a.ID_UPS,
        a.PACIENTE_ID,
        TIMESTAMPDIFF(YEAR, p.FECHANACIMIENTO, DATE(a.FECHA_ATENCION)) AS EDAD
    FROM atencion a
    INNER JOIN personamast p
        ON p.PERSONA = a.PACIENTE_ID
    WHERE a.ID_TIPO_ATENCION IN ('AM', 'EM', 'HO')
      AND a.ID_PERIODO BETWEEN '202601' AND '202609'
      AND a.FECHA_ATENCION >= '2026-01-01'
      AND a.FECHA_ATENCION <  '2026-10-01'
      AND a.ESTADO = 'A'
      AND TIMESTAMPDIFF(YEAR, p.FECHANACIMIENTO, DATE(a.FECHA_ATENCION)) >= 18
      AND a.ID_IPRESS <> '00013591'  -- EXCLUIR HOSPITAL NACIONAL PNP LUIS N. SAENZ (nivel III)
),
dx_aten AS (
    -- 1 fila por atención y diagnóstico definitivo
    SELECT
        ad.ID_ATENCION,
        ad.ID_DIAGNOSTICO,
        MIN(ad.ID_SECUENCIA) AS primera_secuencia
    FROM aten a
    INNER JOIN atencion_diagnostico ad
        ON  ad.ID_ATENCION     = a.id_atencion
        AND ad.ID_TIPO_DETALLE = 'DIA'
    WHERE ad.ID_DIAGNOSTICO IS NOT NULL
      AND ad.ID_TIPO_DIAGNOSTICO = '02'  -- DEFINITIVO
    GROUP BY ad.ID_ATENCION, ad.ID_DIAGNOSTICO
),
dx_orden AS (
    SELECT
        d.*,
        ROW_NUMBER() OVER (PARTITION BY d.ID_ATENCION ORDER BY d.primera_secuencia) AS dx_orden
    FROM dx_aten d
)
SELECT
    'SEIS'                                          AS FUENTE,
    a.id_atencion                                   AS ID_ATENCION,
    DATE_FORMAT(a.FECHA_ATENCION, '%Y%m')           AS PERIODO,  -- desde la fecha, como en SIGESAPOL
    DATE(a.FECHA_ATENCION)                          AS FECHA_ATENCION,
    a.ID_TIPO_ATENCION                              AS TIPO_ATENCION_ORIGEN,
    a.ID_TIPO_ATENCION                              AS TIPO_ATENCION,

    -- Paciente
    p.TIPODOCUMENTO                                 AS TIPO_DOCUMENTO,
    TRIM(p.documento)                               AS DNI,
    p.SEXO                                          AS SEXO,
    a.EDAD                                          AS EDAD,
    be.DESCRIPCIONLOCAL                             AS TIPO_BENEFICIARIO_ORIGEN,
    CASE p.ID_BENEFICIARIO
        WHEN '01' THEN 'TITULAR'
        WHEN '02' THEN 'CONYUGE'
        WHEN '03' THEN 'HIJO'
        WHEN '04' THEN 'PADRES'
        WHEN '05' THEN 'SOBREVIVIENTE'
        ELSE 'OTROS'
    END                                             AS TIPO_BENEFICIARIO,

    -- IPRESS
    a.ID_IPRESS                                     AS CODIGO_IPRESS,
    TRIM(s.DESCRIPCIONLOCAL)                        AS IPRESS,
    CASE
        WHEN a.ID_IPRESS IN ('00011794','00014718','00016094','00011833') THEN 'II'
        ELSE 'I'
    END                                             AS NIVEL_IPRESS,

    -- UPS
    a.ID_UPS                                        AS CODIGO_UPS,
    u.NOMBRE                                        AS UPS,
    NULL                                            AS CONSULTORIO,

    -- Diagnóstico
    COALESCE(d.dx_orden, 1)                         AS DX_ORDEN,
    dx.CodigoDiagnostico                            AS CIE10,
    dx.Nombre                                       AS DIAGNOSTICO

FROM aten a

INNER JOIN personamast p
    ON p.PERSONA = a.PACIENTE_ID

LEFT JOIN dx_orden d
    ON d.ID_ATENCION = a.id_atencion

LEFT JOIN ss_ge_diagnostico dx
    ON dx.IdDiagnostico = d.ID_DIAGNOSTICO

LEFT JOIN ac_sucursal s
    ON s.SUCURSAL = a.ID_IPRESS

LEFT JOIN ups u
    ON u.CODIGOUPS = a.ID_UPS

LEFT JOIN ma_miscelaneosdetalle be
    ON be.CODIGOTABLA = 'BENEFIC' AND be.CODIGOELEMENTO = p.ID_BENEFICIARIO

ORDER BY a.FECHA_ATENCION, a.id_atencion, d.dx_orden;
