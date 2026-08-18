-- =============================================================================
-- ATENCIONES Y ATENDIDOS POR PROCEDIMIENTO (CPMS) Y DIAGNÓSTICO (CIE-10)
-- Periodo: 2023, 2024 y 2025 · Base de Datos: sgcoresys (MariaDB)
--
-- Códigos incluidos:
--   CPMS (solo atenciones id_tipo_atencion = 'PR'):
--     88141, 88141.01, 87621, 99386.03, 77057, 84152, 82270
--   CIE-10 (solo atenciones id_tipo_atencion IN ('AM','EM','HO')):
--     Z12.8
--
-- Estructura de salida = tabla objetivo del ASIS, sin las columnas
-- "RED DE SALUD" ni "DEPARTAMENTO" (esas se completan aparte con un cruce
-- externo por código de IPRESS):
--   IPRESS | TIPO_BENEFICIARIO | SEXO | EDAD | CPMS_O_CIE10 |
--   DESCRIPCION_CIE10_O_CPMS | ANIO | CANTIDAD
--
-- Criterios:
--   - a.ESTADO = 'A'
--   - EDAD = edad exacta del paciente en la atención (no agrupada por rangos)
--   - TITULAR: p.ID_BENEFICIARIO IN ('1','01')  |  resto -> FAMILIAR
--   - No se filtra por rango de edad de elegibilidad del tamizaje (a
--     diferencia de reporte_tamizajes_2021_2025.sql); se trae todo lo
--     registrado con esos códigos en el periodo.
--   - No se filtra id_secuencia / id_tipo_diagnostico para el CIE-10 Z12.8
--     (igual que reporte_atenciones_2025.sql), ya que es un código de
--     tamizaje que no necesariamente va como diagnóstico principal.
--
-- Bloque 1 -> CANTIDAD = ATENCIONES (COUNT DISTINCT id_atencion)
-- Bloque 2 -> CANTIDAD = ATENDIDOS  (COUNT DISTINCT documento del paciente)
-- =============================================================================


-- =============================================================================
-- BLOQUE 1 · ATENCIONES
-- =============================================================================
SELECT
    IPRESS, TIPO_BENEFICIARIO, SEXO, EDAD, CPMS_O_CIE10, DESCRIPCION_CIE10_O_CPMS, ANIO,
    COUNT(DISTINCT ID_ATENCION) AS CANTIDAD
FROM (
    SELECT
        a.id_atencion AS ID_ATENCION,
        a.ID_IPRESS   AS IPRESS,
        CASE WHEN p.ID_BENEFICIARIO IN ('1','01') THEN 'TITULAR' ELSE 'FAMILIAR' END AS TIPO_BENEFICIARIO,
        CASE WHEN p.SEXO = 'M' THEN 'MASCULINO' WHEN p.SEXO = 'F' THEN 'FEMENINO' ELSE 'SIN DATO' END AS SEXO,
        COALESCE(a.PACIENTE_EDAD, TIMESTAMPDIFF(YEAR, p.FECHANACIMIENTO, a.FECHA_ATENCION)) AS EDAD,
        ad.ID_CPT AS CPMS_O_CIE10,
        UPPER(COALESCE(proc.NOMBRE, 'SIN DESCRIPCION')) AS DESCRIPCION_CIE10_O_CPMS,
        YEAR(a.FECHA_ATENCION) AS ANIO
    FROM ATENCION a
    INNER JOIN atencion_diagnostico ad       ON ad.id_atencion = a.id_atencion
    INNER JOIN personamast p                 ON p.persona = a.paciente_id
    LEFT JOIN ss_ge_procedimientomedico proc ON proc.CODIGOPROCEDIMIENTO = ad.ID_CPT
    WHERE a.id_tipo_atencion = 'PR'
      AND a.ESTADO = 'A'
      AND ad.ID_TIPO_DETALLE IN ('PRO','QUI')
      AND ad.ID_CPT IN ('88141','88141.01','87621','99386.03','77057','84152','82270')
      AND a.FECHA_ATENCION >= '2023-01-01' AND a.FECHA_ATENCION < '2026-01-01'

    UNION ALL

    SELECT
        a.id_atencion AS ID_ATENCION,
        a.ID_IPRESS   AS IPRESS,
        CASE WHEN p.ID_BENEFICIARIO IN ('1','01') THEN 'TITULAR' ELSE 'FAMILIAR' END AS TIPO_BENEFICIARIO,
        CASE WHEN p.SEXO = 'M' THEN 'MASCULINO' WHEN p.SEXO = 'F' THEN 'FEMENINO' ELSE 'SIN DATO' END AS SEXO,
        COALESCE(a.PACIENTE_EDAD, TIMESTAMPDIFF(YEAR, p.FECHANACIMIENTO, a.FECHA_ATENCION)) AS EDAD,
        dx.CodigoDiagnostico AS CPMS_O_CIE10,
        UPPER(COALESCE(dx.nombre, 'SIN DESCRIPCION')) AS DESCRIPCION_CIE10_O_CPMS,
        YEAR(a.FECHA_ATENCION) AS ANIO
    FROM ATENCION a
    INNER JOIN atencion_diagnostico ad ON ad.id_atencion = a.id_atencion
    INNER JOIN personamast p           ON p.persona = a.paciente_id
    LEFT JOIN ss_ge_diagnostico dx     ON dx.idDiagnostico = ad.id_diagnostico
    WHERE a.id_tipo_atencion IN ('AM','EM','HO')
      AND a.ESTADO = 'A'
      AND ad.ID_TIPO_DETALLE = 'DIA'
      AND dx.CodigoDiagnostico = 'Z12.8'
      AND a.FECHA_ATENCION >= '2023-01-01' AND a.FECHA_ATENCION < '2026-01-01'
) base
GROUP BY IPRESS, TIPO_BENEFICIARIO, SEXO, EDAD, CPMS_O_CIE10, DESCRIPCION_CIE10_O_CPMS, ANIO
ORDER BY ANIO, IPRESS, CPMS_O_CIE10, EDAD;


-- =============================================================================
-- BLOQUE 2 · ATENDIDOS
-- =============================================================================
SELECT
    IPRESS, TIPO_BENEFICIARIO, SEXO, EDAD, CPMS_O_CIE10, DESCRIPCION_CIE10_O_CPMS, ANIO,
    COUNT(DISTINCT DOCUMENTO) AS CANTIDAD
FROM (
    SELECT
        p.documento  AS DOCUMENTO,
        a.ID_IPRESS  AS IPRESS,
        CASE WHEN p.ID_BENEFICIARIO IN ('1','01') THEN 'TITULAR' ELSE 'FAMILIAR' END AS TIPO_BENEFICIARIO,
        CASE WHEN p.SEXO = 'M' THEN 'MASCULINO' WHEN p.SEXO = 'F' THEN 'FEMENINO' ELSE 'SIN DATO' END AS SEXO,
        COALESCE(a.PACIENTE_EDAD, TIMESTAMPDIFF(YEAR, p.FECHANACIMIENTO, a.FECHA_ATENCION)) AS EDAD,
        ad.ID_CPT AS CPMS_O_CIE10,
        UPPER(COALESCE(proc.NOMBRE, 'SIN DESCRIPCION')) AS DESCRIPCION_CIE10_O_CPMS,
        YEAR(a.FECHA_ATENCION) AS ANIO
    FROM ATENCION a
    INNER JOIN atencion_diagnostico ad       ON ad.id_atencion = a.id_atencion
    INNER JOIN personamast p                 ON p.persona = a.paciente_id
    LEFT JOIN ss_ge_procedimientomedico proc ON proc.CODIGOPROCEDIMIENTO = ad.ID_CPT
    WHERE a.id_tipo_atencion = 'PR'
      AND a.ESTADO = 'A'
      AND ad.ID_TIPO_DETALLE IN ('PRO','QUI')
      AND ad.ID_CPT IN ('88141','88141.01','87621','99386.03','77057','84152','82270')
      AND a.FECHA_ATENCION >= '2023-01-01' AND a.FECHA_ATENCION < '2026-01-01'

    UNION ALL

    SELECT
        p.documento  AS DOCUMENTO,
        a.ID_IPRESS  AS IPRESS,
        CASE WHEN p.ID_BENEFICIARIO IN ('1','01') THEN 'TITULAR' ELSE 'FAMILIAR' END AS TIPO_BENEFICIARIO,
        CASE WHEN p.SEXO = 'M' THEN 'MASCULINO' WHEN p.SEXO = 'F' THEN 'FEMENINO' ELSE 'SIN DATO' END AS SEXO,
        COALESCE(a.PACIENTE_EDAD, TIMESTAMPDIFF(YEAR, p.FECHANACIMIENTO, a.FECHA_ATENCION)) AS EDAD,
        dx.CodigoDiagnostico AS CPMS_O_CIE10,
        UPPER(COALESCE(dx.nombre, 'SIN DESCRIPCION')) AS DESCRIPCION_CIE10_O_CPMS,
        YEAR(a.FECHA_ATENCION) AS ANIO
    FROM ATENCION a
    INNER JOIN atencion_diagnostico ad ON ad.id_atencion = a.id_atencion
    INNER JOIN personamast p           ON p.persona = a.paciente_id
    LEFT JOIN ss_ge_diagnostico dx     ON dx.idDiagnostico = ad.id_diagnostico
    WHERE a.id_tipo_atencion IN ('AM','EM','HO')
      AND a.ESTADO = 'A'
      AND ad.ID_TIPO_DETALLE = 'DIA'
      AND dx.CodigoDiagnostico = 'Z12.8'
      AND a.FECHA_ATENCION >= '2023-01-01' AND a.FECHA_ATENCION < '2026-01-01'
) base
GROUP BY IPRESS, TIPO_BENEFICIARIO, SEXO, EDAD, CPMS_O_CIE10, DESCRIPCION_CIE10_O_CPMS, ANIO
ORDER BY ANIO, IPRESS, CPMS_O_CIE10, EDAD;
