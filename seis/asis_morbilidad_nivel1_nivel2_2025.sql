-- =============================================================================
-- ASIS 2025 · TOP 20 DIAGNÓSTICOS MÁS FRECUENTES (SOLO NIVEL I Y NIVEL II)
-- Base de Datos: sgcoresys (MariaDB)
-- Fuente del layout: "ASIS INFORMACIÓN ESTADISTICA PARA ASIS 2025 v2.xlsx"
--
-- Este script cubre las 5 hojas que agrupan por NIVEL I / NIVEL II
-- (la columna "NIVEL III" de cada hoja NO proviene de sgcoresys, por eso
-- no se genera aquí; la clasificación NIVEL I/II usada replica la ya
-- usada en morbilidad_agrupada.sql y el resto de reportes del repo).
--
--   Bloque A -> Hoja MORB_EME         (EMERGENCIA, por SEXO)
--   Bloque B -> Hoja MORB_EME_EDADES  (EMERGENCIA, por GRUPO ETARIO)
--   Bloque C -> Hoja MORB_EME_BENEF   (EMERGENCIA, por TIPO DE BENEFICIARIO)
--   Bloque D -> Hoja MORB_HOSP_EDADES (HOSPITALIZACIÓN, por GRUPO ETARIO)
--   Bloque E -> Hoja MORB_HOSP_BENEF  (HOSPITALIZACIÓN, por TIPO DE BENEFICIARIO)
--
-- Nota: no existe hoja "MORB_HOSP" (por sexo) en el Excel, por lo que no se
-- genera ese bloque para hospitalización.
--
-- CRITERIOS APLICADOS:
--   - a.ESTADO = 'A'
--   - ad.id_secuencia = 1           -> diagnóstico principal de la atención
--   - ad.id_tipo_diagnostico = '02' -> diagnóstico definitivo
--   - Periodo: año 2025 completo (FECHA_ATENCION >= 2025-01-01 y < 2026-01-01)
--   - NIVEL II: ID_IPRESS IN ('00011794','00014718','00016094','00011833')
--               resto -> NIVEL I
--   - TITULAR: p.ID_BENEFICIARIO IN ('1','01')  |  resto -> FAMILIAR
--     (la hoja Excel llama "FAMILIAR" a lo que la documentación llama
--     "DERECHOHABIENTE"; es el mismo concepto)
--
--   - MÉTRICA = ATENCIONES (no atendidos): cada fila cuenta atenciones
--     (a.id_atencion) con ese diagnóstico principal, no pacientes distintos.
--     Un mismo paciente con 3 visitas y el mismo CIE-10 en el año suma 3.
--
--   - CÓDIGOS Z (Z00-Z99, tamizaje / contacto con servicios de salud):
--     NO se excluyen de la data ni del TOTAL_GENERAL, pero se excluyen del
--     ranking de "top 20" (nunca ocupan un puesto 1-20) y su cantidad se sepulta
--     dentro de la fila "OTRAS ENFERMEDADES", tal como se maneja en la
--     institución.
--
-- CÓMO USAR EL RESULTADO:
--   Cada bloque devuelve, ya ordenado por NIVEL_IPRESS y la dimensión
--   correspondiente, las filas 1-20 (top 20, sin códigos Z), la fila
--   "OTRAS ENFERMEDADES" (resto de diagnósticos no-Z fuera del top 20 + todos
--   los códigos Z) y la fila "TOTAL GENERAL". Filtrar por
--   NIVEL_IPRESS = 'NIVEL I' o 'NIVEL II' y por la dimensión (sexo / grupo
--   etario / tipo de beneficiario) para pegar cada bloque de 22 filas en su
--   tabla correspondiente del Excel.
-- =============================================================================


-- =============================================================================
-- BLOQUE A · Hoja MORB_EME — Top 20 diagnósticos en EMERGENCIA por SEXO
-- =============================================================================
WITH base AS (
    SELECT DISTINCT
        CASE
            WHEN a.ID_IPRESS IN ('00011794','00014718','00016094','00011833') THEN 'NIVEL II'
            ELSE 'NIVEL I'
        END AS NIVEL_IPRESS,
        CASE
            WHEN p.SEXO = 'M' THEN 'MASCULINO'
            WHEN p.SEXO = 'F' THEN 'FEMENINO'
            ELSE 'SIN DATO'
        END AS SEXO,
        a.id_atencion,
        dx.CodigoDiagnostico AS CIE10,
        UPPER(dx.nombre) AS DESCRIPCION
    FROM ATENCION a
    INNER JOIN atencion_diagnostico ad ON ad.id_atencion = a.id_atencion
    INNER JOIN ss_ge_diagnostico dx    ON dx.idDiagnostico = ad.id_diagnostico
    INNER JOIN personamast p           ON p.persona = a.paciente_id
    WHERE a.id_tipo_atencion = 'EM'
      AND a.ESTADO = 'A'
      AND ad.id_secuencia = 1
      AND ad.id_tipo_diagnostico = '02'
      AND a.FECHA_ATENCION >= '2025-01-01' AND a.FECHA_ATENCION < '2026-01-01'
),
counted AS (
    SELECT NIVEL_IPRESS, SEXO, CIE10, MIN(DESCRIPCION) AS DESCRIPCION, COUNT(*) AS CANTIDAD
    FROM base
    GROUP BY NIVEL_IPRESS, SEXO, CIE10
),
totals AS (
    SELECT NIVEL_IPRESS, SEXO, SUM(CANTIDAD) AS TOTAL_GENERAL
    FROM counted
    GROUP BY NIVEL_IPRESS, SEXO
),
ranked AS (
    SELECT c.*, t.TOTAL_GENERAL,
           ROW_NUMBER() OVER (PARTITION BY c.NIVEL_IPRESS, c.SEXO ORDER BY c.CANTIDAD DESC, c.CIE10) AS RN
    FROM counted c
    INNER JOIN totals t ON t.NIVEL_IPRESS = c.NIVEL_IPRESS AND t.SEXO = c.SEXO
    WHERE c.CIE10 NOT LIKE 'Z%'
),
otras AS (
    SELECT NIVEL_IPRESS, SEXO, SUM(CANTIDAD) AS CANTIDAD_OTRAS
    FROM (
        SELECT NIVEL_IPRESS, SEXO, CANTIDAD FROM ranked WHERE RN > 20
        UNION ALL
        SELECT NIVEL_IPRESS, SEXO, CANTIDAD FROM counted WHERE CIE10 LIKE 'Z%'
    ) u
    GROUP BY NIVEL_IPRESS, SEXO
)
SELECT NIVEL_IPRESS, SEXO, RN AS N, CIE10, DESCRIPCION, CANTIDAD,
       ROUND(CANTIDAD / TOTAL_GENERAL, 6) AS PORCENTAJE
FROM ranked
WHERE RN <= 20

UNION ALL

SELECT t.NIVEL_IPRESS, t.SEXO, 21 AS N, NULL, 'OTRAS ENFERMEDADES',
       COALESCE(o.CANTIDAD_OTRAS, 0),
       ROUND(COALESCE(o.CANTIDAD_OTRAS, 0) / t.TOTAL_GENERAL, 6)
FROM totals t
LEFT JOIN otras o ON o.NIVEL_IPRESS = t.NIVEL_IPRESS AND o.SEXO = t.SEXO

UNION ALL

SELECT NIVEL_IPRESS, SEXO, 22 AS N, NULL, 'TOTAL GENERAL', TOTAL_GENERAL, 1
FROM totals

ORDER BY NIVEL_IPRESS, SEXO, N;


-- =============================================================================
-- BLOQUE B · Hoja MORB_EME_EDADES — Top 20 diagnósticos en EMERGENCIA
-- por GRUPO ETARIO (0-11 / 12-17 / 18-49 / 50-59 / 60+)
-- =============================================================================
WITH base AS (
    SELECT DISTINCT
        CASE
            WHEN a.ID_IPRESS IN ('00011794','00014718','00016094','00011833') THEN 'NIVEL II'
            ELSE 'NIVEL I'
        END AS NIVEL_IPRESS,
        CASE
            WHEN COALESCE(a.PACIENTE_EDAD, TIMESTAMPDIFF(YEAR, p.FECHANACIMIENTO, a.FECHA_ATENCION)) BETWEEN 0 AND 11  THEN '0 A 11 AÑOS'
            WHEN COALESCE(a.PACIENTE_EDAD, TIMESTAMPDIFF(YEAR, p.FECHANACIMIENTO, a.FECHA_ATENCION)) BETWEEN 12 AND 17 THEN '12 A 17 AÑOS'
            WHEN COALESCE(a.PACIENTE_EDAD, TIMESTAMPDIFF(YEAR, p.FECHANACIMIENTO, a.FECHA_ATENCION)) BETWEEN 18 AND 49 THEN '18 A 49 AÑOS'
            WHEN COALESCE(a.PACIENTE_EDAD, TIMESTAMPDIFF(YEAR, p.FECHANACIMIENTO, a.FECHA_ATENCION)) BETWEEN 50 AND 59 THEN '50 A 59 AÑOS'
            WHEN COALESCE(a.PACIENTE_EDAD, TIMESTAMPDIFF(YEAR, p.FECHANACIMIENTO, a.FECHA_ATENCION)) >= 60             THEN 'MAYORES DE 60 AÑOS'
            ELSE 'SIN DATO'
        END AS GRUPO_ETARIO,
        a.id_atencion,
        dx.CodigoDiagnostico AS CIE10,
        UPPER(dx.nombre) AS DESCRIPCION
    FROM ATENCION a
    INNER JOIN atencion_diagnostico ad ON ad.id_atencion = a.id_atencion
    INNER JOIN ss_ge_diagnostico dx    ON dx.idDiagnostico = ad.id_diagnostico
    INNER JOIN personamast p           ON p.persona = a.paciente_id
    WHERE a.id_tipo_atencion = 'EM'
      AND a.ESTADO = 'A'
      AND ad.id_secuencia = 1
      AND ad.id_tipo_diagnostico = '02'
      AND a.FECHA_ATENCION >= '2025-01-01' AND a.FECHA_ATENCION < '2026-01-01'
),
counted AS (
    SELECT NIVEL_IPRESS, GRUPO_ETARIO, CIE10, MIN(DESCRIPCION) AS DESCRIPCION, COUNT(*) AS CANTIDAD
    FROM base
    GROUP BY NIVEL_IPRESS, GRUPO_ETARIO, CIE10
),
totals AS (
    SELECT NIVEL_IPRESS, GRUPO_ETARIO, SUM(CANTIDAD) AS TOTAL_GENERAL
    FROM counted
    GROUP BY NIVEL_IPRESS, GRUPO_ETARIO
),
ranked AS (
    SELECT c.*, t.TOTAL_GENERAL,
           ROW_NUMBER() OVER (PARTITION BY c.NIVEL_IPRESS, c.GRUPO_ETARIO ORDER BY c.CANTIDAD DESC, c.CIE10) AS RN
    FROM counted c
    INNER JOIN totals t ON t.NIVEL_IPRESS = c.NIVEL_IPRESS AND t.GRUPO_ETARIO = c.GRUPO_ETARIO
    WHERE c.CIE10 NOT LIKE 'Z%'
),
otras AS (
    SELECT NIVEL_IPRESS, GRUPO_ETARIO, SUM(CANTIDAD) AS CANTIDAD_OTRAS
    FROM (
        SELECT NIVEL_IPRESS, GRUPO_ETARIO, CANTIDAD FROM ranked WHERE RN > 20
        UNION ALL
        SELECT NIVEL_IPRESS, GRUPO_ETARIO, CANTIDAD FROM counted WHERE CIE10 LIKE 'Z%'
    ) u
    GROUP BY NIVEL_IPRESS, GRUPO_ETARIO
)
SELECT NIVEL_IPRESS, GRUPO_ETARIO, RN AS N, CIE10, DESCRIPCION, CANTIDAD,
       ROUND(CANTIDAD / TOTAL_GENERAL, 6) AS PORCENTAJE
FROM ranked
WHERE RN <= 20

UNION ALL

SELECT t.NIVEL_IPRESS, t.GRUPO_ETARIO, 21 AS N, NULL, 'OTRAS ENFERMEDADES',
       COALESCE(o.CANTIDAD_OTRAS, 0),
       ROUND(COALESCE(o.CANTIDAD_OTRAS, 0) / t.TOTAL_GENERAL, 6)
FROM totals t
LEFT JOIN otras o ON o.NIVEL_IPRESS = t.NIVEL_IPRESS AND o.GRUPO_ETARIO = t.GRUPO_ETARIO

UNION ALL

SELECT NIVEL_IPRESS, GRUPO_ETARIO, 22 AS N, NULL, 'TOTAL GENERAL', TOTAL_GENERAL, 1
FROM totals

ORDER BY NIVEL_IPRESS,
         FIELD(GRUPO_ETARIO, '0 A 11 AÑOS','12 A 17 AÑOS','18 A 49 AÑOS','50 A 59 AÑOS','MAYORES DE 60 AÑOS','SIN DATO'),
         N;


-- =============================================================================
-- BLOQUE C · Hoja MORB_EME_BENEF — Top 20 diagnósticos en EMERGENCIA
-- por TIPO DE BENEFICIARIO (TITULAR / FAMILIAR)
-- =============================================================================
WITH base AS (
    SELECT DISTINCT
        CASE
            WHEN a.ID_IPRESS IN ('00011794','00014718','00016094','00011833') THEN 'NIVEL II'
            ELSE 'NIVEL I'
        END AS NIVEL_IPRESS,
        CASE
            WHEN p.ID_BENEFICIARIO IN ('1','01') THEN 'TITULAR'
            ELSE 'FAMILIAR'
        END AS TIPO_BENEFICIARIO,
        a.id_atencion,
        dx.CodigoDiagnostico AS CIE10,
        UPPER(dx.nombre) AS DESCRIPCION
    FROM ATENCION a
    INNER JOIN atencion_diagnostico ad ON ad.id_atencion = a.id_atencion
    INNER JOIN ss_ge_diagnostico dx    ON dx.idDiagnostico = ad.id_diagnostico
    INNER JOIN personamast p           ON p.persona = a.paciente_id
    WHERE a.id_tipo_atencion = 'EM'
      AND a.ESTADO = 'A'
      AND ad.id_secuencia = 1
      AND ad.id_tipo_diagnostico = '02'
      AND a.FECHA_ATENCION >= '2025-01-01' AND a.FECHA_ATENCION < '2026-01-01'
),
counted AS (
    SELECT NIVEL_IPRESS, TIPO_BENEFICIARIO, CIE10, MIN(DESCRIPCION) AS DESCRIPCION, COUNT(*) AS CANTIDAD
    FROM base
    GROUP BY NIVEL_IPRESS, TIPO_BENEFICIARIO, CIE10
),
totals AS (
    SELECT NIVEL_IPRESS, TIPO_BENEFICIARIO, SUM(CANTIDAD) AS TOTAL_GENERAL
    FROM counted
    GROUP BY NIVEL_IPRESS, TIPO_BENEFICIARIO
),
ranked AS (
    SELECT c.*, t.TOTAL_GENERAL,
           ROW_NUMBER() OVER (PARTITION BY c.NIVEL_IPRESS, c.TIPO_BENEFICIARIO ORDER BY c.CANTIDAD DESC, c.CIE10) AS RN
    FROM counted c
    INNER JOIN totals t ON t.NIVEL_IPRESS = c.NIVEL_IPRESS AND t.TIPO_BENEFICIARIO = c.TIPO_BENEFICIARIO
    WHERE c.CIE10 NOT LIKE 'Z%'
),
otras AS (
    SELECT NIVEL_IPRESS, TIPO_BENEFICIARIO, SUM(CANTIDAD) AS CANTIDAD_OTRAS
    FROM (
        SELECT NIVEL_IPRESS, TIPO_BENEFICIARIO, CANTIDAD FROM ranked WHERE RN > 20
        UNION ALL
        SELECT NIVEL_IPRESS, TIPO_BENEFICIARIO, CANTIDAD FROM counted WHERE CIE10 LIKE 'Z%'
    ) u
    GROUP BY NIVEL_IPRESS, TIPO_BENEFICIARIO
)
SELECT NIVEL_IPRESS, TIPO_BENEFICIARIO, RN AS N, CIE10, DESCRIPCION, CANTIDAD,
       ROUND(CANTIDAD / TOTAL_GENERAL, 6) AS PORCENTAJE
FROM ranked
WHERE RN <= 20

UNION ALL

SELECT t.NIVEL_IPRESS, t.TIPO_BENEFICIARIO, 21 AS N, NULL, 'OTRAS ENFERMEDADES',
       COALESCE(o.CANTIDAD_OTRAS, 0),
       ROUND(COALESCE(o.CANTIDAD_OTRAS, 0) / t.TOTAL_GENERAL, 6)
FROM totals t
LEFT JOIN otras o ON o.NIVEL_IPRESS = t.NIVEL_IPRESS AND o.TIPO_BENEFICIARIO = t.TIPO_BENEFICIARIO

UNION ALL

SELECT NIVEL_IPRESS, TIPO_BENEFICIARIO, 22 AS N, NULL, 'TOTAL GENERAL', TOTAL_GENERAL, 1
FROM totals

ORDER BY NIVEL_IPRESS, FIELD(TIPO_BENEFICIARIO, 'TITULAR','FAMILIAR'), N;


-- =============================================================================
-- BLOQUE D · Hoja MORB_HOSP_EDADES — Top 20 diagnósticos en HOSPITALIZACIÓN
-- por GRUPO ETARIO (0-11 / 12-17 / 18-49 / 50-59 / 60+)
-- =============================================================================
WITH base AS (
    SELECT DISTINCT
        CASE
            WHEN a.ID_IPRESS IN ('00011794','00014718','00016094','00011833') THEN 'NIVEL II'
            ELSE 'NIVEL I'
        END AS NIVEL_IPRESS,
        CASE
            WHEN COALESCE(a.PACIENTE_EDAD, TIMESTAMPDIFF(YEAR, p.FECHANACIMIENTO, a.FECHA_ATENCION)) BETWEEN 0 AND 11  THEN '0 A 11 AÑOS'
            WHEN COALESCE(a.PACIENTE_EDAD, TIMESTAMPDIFF(YEAR, p.FECHANACIMIENTO, a.FECHA_ATENCION)) BETWEEN 12 AND 17 THEN '12 A 17 AÑOS'
            WHEN COALESCE(a.PACIENTE_EDAD, TIMESTAMPDIFF(YEAR, p.FECHANACIMIENTO, a.FECHA_ATENCION)) BETWEEN 18 AND 49 THEN '18 A 49 AÑOS'
            WHEN COALESCE(a.PACIENTE_EDAD, TIMESTAMPDIFF(YEAR, p.FECHANACIMIENTO, a.FECHA_ATENCION)) BETWEEN 50 AND 59 THEN '50 A 59 AÑOS'
            WHEN COALESCE(a.PACIENTE_EDAD, TIMESTAMPDIFF(YEAR, p.FECHANACIMIENTO, a.FECHA_ATENCION)) >= 60             THEN 'MAYORES DE 60 AÑOS'
            ELSE 'SIN DATO'
        END AS GRUPO_ETARIO,
        a.id_atencion,
        dx.CodigoDiagnostico AS CIE10,
        UPPER(dx.nombre) AS DESCRIPCION
    FROM ATENCION a
    INNER JOIN atencion_diagnostico ad ON ad.id_atencion = a.id_atencion
    INNER JOIN ss_ge_diagnostico dx    ON dx.idDiagnostico = ad.id_diagnostico
    INNER JOIN personamast p           ON p.persona = a.paciente_id
    WHERE a.id_tipo_atencion = 'HO'
      AND a.ESTADO = 'A'
      AND ad.id_secuencia = 1
      AND ad.id_tipo_diagnostico = '02'
      AND a.FECHA_ATENCION >= '2025-01-01' AND a.FECHA_ATENCION < '2026-01-01'
),
counted AS (
    SELECT NIVEL_IPRESS, GRUPO_ETARIO, CIE10, MIN(DESCRIPCION) AS DESCRIPCION, COUNT(*) AS CANTIDAD
    FROM base
    GROUP BY NIVEL_IPRESS, GRUPO_ETARIO, CIE10
),
totals AS (
    SELECT NIVEL_IPRESS, GRUPO_ETARIO, SUM(CANTIDAD) AS TOTAL_GENERAL
    FROM counted
    GROUP BY NIVEL_IPRESS, GRUPO_ETARIO
),
ranked AS (
    SELECT c.*, t.TOTAL_GENERAL,
           ROW_NUMBER() OVER (PARTITION BY c.NIVEL_IPRESS, c.GRUPO_ETARIO ORDER BY c.CANTIDAD DESC, c.CIE10) AS RN
    FROM counted c
    INNER JOIN totals t ON t.NIVEL_IPRESS = c.NIVEL_IPRESS AND t.GRUPO_ETARIO = c.GRUPO_ETARIO
    WHERE c.CIE10 NOT LIKE 'Z%'
),
otras AS (
    SELECT NIVEL_IPRESS, GRUPO_ETARIO, SUM(CANTIDAD) AS CANTIDAD_OTRAS
    FROM (
        SELECT NIVEL_IPRESS, GRUPO_ETARIO, CANTIDAD FROM ranked WHERE RN > 20
        UNION ALL
        SELECT NIVEL_IPRESS, GRUPO_ETARIO, CANTIDAD FROM counted WHERE CIE10 LIKE 'Z%'
    ) u
    GROUP BY NIVEL_IPRESS, GRUPO_ETARIO
)
SELECT NIVEL_IPRESS, GRUPO_ETARIO, RN AS N, CIE10, DESCRIPCION, CANTIDAD,
       ROUND(CANTIDAD / TOTAL_GENERAL, 6) AS PORCENTAJE
FROM ranked
WHERE RN <= 20

UNION ALL

SELECT t.NIVEL_IPRESS, t.GRUPO_ETARIO, 21 AS N, NULL, 'OTRAS ENFERMEDADES',
       COALESCE(o.CANTIDAD_OTRAS, 0),
       ROUND(COALESCE(o.CANTIDAD_OTRAS, 0) / t.TOTAL_GENERAL, 6)
FROM totals t
LEFT JOIN otras o ON o.NIVEL_IPRESS = t.NIVEL_IPRESS AND o.GRUPO_ETARIO = t.GRUPO_ETARIO

UNION ALL

SELECT NIVEL_IPRESS, GRUPO_ETARIO, 22 AS N, NULL, 'TOTAL GENERAL', TOTAL_GENERAL, 1
FROM totals

ORDER BY NIVEL_IPRESS,
         FIELD(GRUPO_ETARIO, '0 A 11 AÑOS','12 A 17 AÑOS','18 A 49 AÑOS','50 A 59 AÑOS','MAYORES DE 60 AÑOS','SIN DATO'),
         N;


-- =============================================================================
-- BLOQUE E · Hoja MORB_HOSP_BENEF — Top 20 diagnósticos en HOSPITALIZACIÓN
-- por TIPO DE BENEFICIARIO (TITULAR / FAMILIAR)
-- =============================================================================
WITH base AS (
    SELECT DISTINCT
        CASE
            WHEN a.ID_IPRESS IN ('00011794','00014718','00016094','00011833') THEN 'NIVEL II'
            ELSE 'NIVEL I'
        END AS NIVEL_IPRESS,
        CASE
            WHEN p.ID_BENEFICIARIO IN ('1','01') THEN 'TITULAR'
            ELSE 'FAMILIAR'
        END AS TIPO_BENEFICIARIO,
        a.id_atencion,
        dx.CodigoDiagnostico AS CIE10,
        UPPER(dx.nombre) AS DESCRIPCION
    FROM ATENCION a
    INNER JOIN atencion_diagnostico ad ON ad.id_atencion = a.id_atencion
    INNER JOIN ss_ge_diagnostico dx    ON dx.idDiagnostico = ad.id_diagnostico
    INNER JOIN personamast p           ON p.persona = a.paciente_id
    WHERE a.id_tipo_atencion = 'HO'
      AND a.ESTADO = 'A'
      AND ad.id_secuencia = 1
      AND ad.id_tipo_diagnostico = '02'
      AND a.FECHA_ATENCION >= '2025-01-01' AND a.FECHA_ATENCION < '2026-01-01'
),
counted AS (
    SELECT NIVEL_IPRESS, TIPO_BENEFICIARIO, CIE10, MIN(DESCRIPCION) AS DESCRIPCION, COUNT(*) AS CANTIDAD
    FROM base
    GROUP BY NIVEL_IPRESS, TIPO_BENEFICIARIO, CIE10
),
totals AS (
    SELECT NIVEL_IPRESS, TIPO_BENEFICIARIO, SUM(CANTIDAD) AS TOTAL_GENERAL
    FROM counted
    GROUP BY NIVEL_IPRESS, TIPO_BENEFICIARIO
),
ranked AS (
    SELECT c.*, t.TOTAL_GENERAL,
           ROW_NUMBER() OVER (PARTITION BY c.NIVEL_IPRESS, c.TIPO_BENEFICIARIO ORDER BY c.CANTIDAD DESC, c.CIE10) AS RN
    FROM counted c
    INNER JOIN totals t ON t.NIVEL_IPRESS = c.NIVEL_IPRESS AND t.TIPO_BENEFICIARIO = c.TIPO_BENEFICIARIO
    WHERE c.CIE10 NOT LIKE 'Z%'
),
otras AS (
    SELECT NIVEL_IPRESS, TIPO_BENEFICIARIO, SUM(CANTIDAD) AS CANTIDAD_OTRAS
    FROM (
        SELECT NIVEL_IPRESS, TIPO_BENEFICIARIO, CANTIDAD FROM ranked WHERE RN > 20
        UNION ALL
        SELECT NIVEL_IPRESS, TIPO_BENEFICIARIO, CANTIDAD FROM counted WHERE CIE10 LIKE 'Z%'
    ) u
    GROUP BY NIVEL_IPRESS, TIPO_BENEFICIARIO
)
SELECT NIVEL_IPRESS, TIPO_BENEFICIARIO, RN AS N, CIE10, DESCRIPCION, CANTIDAD,
       ROUND(CANTIDAD / TOTAL_GENERAL, 6) AS PORCENTAJE
FROM ranked
WHERE RN <= 20

UNION ALL

SELECT t.NIVEL_IPRESS, t.TIPO_BENEFICIARIO, 21 AS N, NULL, 'OTRAS ENFERMEDADES',
       COALESCE(o.CANTIDAD_OTRAS, 0),
       ROUND(COALESCE(o.CANTIDAD_OTRAS, 0) / t.TOTAL_GENERAL, 6)
FROM totals t
LEFT JOIN otras o ON o.NIVEL_IPRESS = t.NIVEL_IPRESS AND o.TIPO_BENEFICIARIO = t.TIPO_BENEFICIARIO

UNION ALL

SELECT NIVEL_IPRESS, TIPO_BENEFICIARIO, 22 AS N, NULL, 'TOTAL GENERAL', TOTAL_GENERAL, 1
FROM totals

ORDER BY NIVEL_IPRESS, FIELD(TIPO_BENEFICIARIO, 'TITULAR','FAMILIAR'), N;
