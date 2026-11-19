-- =============================================================================
-- SEIS · ATENCIONES Y ATENDIDOS CON DIAGNÓSTICO DE CÁNCER (lista CIE-10 dada)
-- Periodo: 2021 - 2025 (por fecha de atención)
-- Base: bdseis_agosto26 (Laragon MySQL, puerto 3306)
--
-- Criterios:
--   - Atenciones activas (ESTADO = 'A'), tipos AM, EM y HO.
--   - Solo IPRESS de nivel I y II: se excluye el HOSPITAL NACIONAL PNP
--     LUIS N. SAENZ (00013591, nivel III).
--   - La atención cuenta si registró AL MENOS UNO de los CIE-10 de la lista,
--     en cualquier posición y cualquier tipo de diagnóstico (presuntivo,
--     definitivo o repetido). Se informa aparte el conteo solo definitivos.
--   - Atendidos = DNI distintos (personamast.DOCUMENTO).
--   - Una atención con dos tipos de cáncer cuenta una vez en cada tipo, pero
--     una sola vez en el total.
--   - Nivel II = 00011794 (Arequipa), 00014718 (San José), 00016094 (Leguía),
--     00011833 (Chiclayo); el resto es nivel I.
--
-- Salidas (formato largo, columnas NIVEL, TIPO_ATENCION, TIPO_CANCER, AÑO):
--   1. Por nivel, tipo de atención, tipo de cáncer y año, con subtotal
--      '2021-2025' por tipo de cáncer.
--   2. TOTAL de los 7 cánceres por nivel, tipo de atención y año (DNI y
--      atenciones sin duplicar), con subtotal '2021-2025'.
--   Los atendidos son DNI distintos dentro de cada fila: no se pueden sumar
--   entre filas (una persona puede ir por AM y EM, o a nivel I y II).
-- =============================================================================

DROP TEMPORARY TABLE IF EXISTS tmp_dx_cancer;
CREATE TEMPORARY TABLE tmp_dx_cancer (
    idDiagnostico INT PRIMARY KEY,
    cie10         VARCHAR(10),
    tipo_cancer   VARCHAR(30)
);

INSERT INTO tmp_dx_cancer
SELECT d.idDiagnostico, d.CodigoDiagnostico,
       CASE LEFT(d.CodigoDiagnostico, 3)
            WHEN 'C16' THEN 'Estómago'
            WHEN 'C34' THEN 'Bronquio/Pulmón'
            WHEN 'C50' THEN 'Mama'
            WHEN 'C43' THEN 'Melanoma'
            WHEN 'C53' THEN 'Cuello uterino'
            WHEN 'C18' THEN 'Colon'
            WHEN 'C61' THEN 'Próstata'
       END
FROM ss_ge_diagnostico d
WHERE d.CodigoDiagnostico IN (
    'C16.0','C16.1','C16.2','C16.3','C16.4','C16.5','C16.6','C16.8','C16.9',
    'C34.0','C34.1','C34.2','C34.3','C34.8','C34.9',
    'C50.0','C50.1','C50.2','C50.3','C50.4','C50.5','C50.6','C50.8','C50.9',
    'C43.0','C43.1','C43.2','C43.3','C43.4','C43.5','C43.6','C43.7','C43.8','C43.9',
    'C53.0','C53.1','C53.8','C53.9',
    'C18.0','C18.1','C18.2','C18.3','C18.4','C18.5','C18.6','C18.7','C18.8','C18.9',
    'C61.X'
);

-- Evita "The total number of locks exceeds the lock table size" en CREATE ... SELECT
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- Paso 1: filas de diagnóstico con los CIE-10 de la lista (1 barrido de
-- atencion_diagnostico; no tiene índice por ID_DIAGNOSTICO)
DROP TEMPORARY TABLE IF EXISTS tmp_ad_cancer;
CREATE TEMPORARY TABLE tmp_ad_cancer AS
SELECT
    ad.ID_ATENCION,
    x.tipo_cancer,
    MAX(ad.ID_TIPO_DIAGNOSTICO = '02') AS es_definitivo
FROM atencion_diagnostico ad
INNER JOIN tmp_dx_cancer x
    ON x.idDiagnostico = ad.ID_DIAGNOSTICO
WHERE ad.ID_TIPO_DETALLE = 'DIA'
GROUP BY ad.ID_ATENCION, x.tipo_cancer;
ALTER TABLE tmp_ad_cancer ADD INDEX (ID_ATENCION);

-- Paso 2: 1 fila por atención y tipo de cáncer, con filtros de la atención
DROP TEMPORARY TABLE IF EXISTS tmp_aten_cancer;
CREATE TEMPORARY TABLE tmp_aten_cancer AS
SELECT
    a.id_atencion,
    YEAR(a.FECHA_ATENCION) AS anio,
    CASE WHEN a.ID_IPRESS IN ('00011794', '00014718', '00016094', '00011833')
         THEN 'NIVEL II' ELSE 'NIVEL I' END AS nivel,
    a.ID_TIPO_ATENCION     AS tipo_atencion,
    p.DOCUMENTO            AS dni,
    ad.tipo_cancer,
    ad.es_definitivo
FROM tmp_ad_cancer ad
INNER JOIN atencion a
    ON  a.id_atencion = ad.ID_ATENCION
INNER JOIN personamast p
    ON  p.PERSONA = a.PACIENTE_ID
WHERE a.ID_TIPO_ATENCION IN ('AM', 'EM', 'HO')
  AND a.ID_PERIODO BETWEEN '202012' AND '202601'   -- usa atencion_idx_01
  AND a.FECHA_ATENCION >= '2021-01-01'
  AND a.FECHA_ATENCION <  '2026-01-01'
  AND a.ESTADO = 'A'
  AND a.ID_IPRESS <> '00013591';  -- EXCLUIR HOSPITAL NACIONAL PNP LUIS N. SAENZ (nivel III)

-- Resultado 1: por nivel, tipo de atención, tipo de cáncer y año
--              (+ subtotal 2021-2025 por tipo de cáncer)
SELECT
    nivel                                                AS `NIVEL`,
    tipo_atencion                                        AS `TIPO_ATENCION`,
    tipo_cancer                                          AS `TIPO_CANCER`,
    IF(GROUPING(anio), '2021-2025', CAST(anio AS CHAR))  AS `AÑO`,
    COUNT(DISTINCT id_atencion)                          AS atenciones,
    COUNT(DISTINCT dni)                                  AS atendidos,
    COUNT(DISTINCT CASE WHEN es_definitivo = 1 THEN id_atencion END) AS atenciones_dx_definitivo,
    COUNT(DISTINCT CASE WHEN es_definitivo = 1 THEN dni END)         AS atendidos_dx_definitivo
FROM tmp_aten_cancer
GROUP BY nivel, tipo_atencion, tipo_cancer, anio WITH ROLLUP
HAVING GROUPING(tipo_cancer) = 0;

-- Resultado 2: TOTAL de los 7 cánceres por nivel, tipo de atención y año
--              (sin duplicar atenciones ni personas)
SELECT
    nivel                                                AS `NIVEL`,
    tipo_atencion                                        AS `TIPO_ATENCION`,
    'TOTAL'                                              AS `TIPO_CANCER`,
    IF(GROUPING(anio), '2021-2025', CAST(anio AS CHAR))  AS `AÑO`,
    COUNT(DISTINCT id_atencion)                          AS atenciones,
    COUNT(DISTINCT dni)                                  AS atendidos,
    COUNT(DISTINCT CASE WHEN es_definitivo = 1 THEN id_atencion END) AS atenciones_dx_definitivo,
    COUNT(DISTINCT CASE WHEN es_definitivo = 1 THEN dni END)         AS atendidos_dx_definitivo
FROM tmp_aten_cancer
GROUP BY nivel, tipo_atencion, anio WITH ROLLUP
HAVING GROUPING(tipo_atencion) = 0;
