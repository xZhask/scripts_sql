-- =============================================================================
-- REPORTE DE ATENCIONES Y ATENDIDOS POR GRUPO DE CÁNCER Y CIE-10
-- Periodo: 2021 - 2025
-- Base de Datos: sgcoresys
-- Categorías de Cáncer Evaluadas:
--   - CÁNCER DE MAMA (C50)
--   - CÁNCER DE COLON (C18)
--   - CÁNCER DE ESTÓMAGO (C16)
--   - CÁNCER DE PULMÓN (C34)
--   - CÁNCER DE CUELLO UTERINO (C53)
--   - MELANOMA (C43)
--   - CÁNCER DE RECTO (C20)
--   - CÁNCER DE HÍGADO (C22)
--   - CÁNCER DE PIEL NO MELANOMA (C44)
--   - CÁNCER DE PRÓSTATA (C61)
--   - LINFOMA (C81, C82, C83, C84, C85, C86)
--   - MIELOMA MÚLTIPLE (C90)
--   - LEUCEMIA (C91, C92, C93, C94, C95)
-- =============================================================================


-- =============================================================================
-- OPCIÓN 1: DATA GENERAL (DETALLE POR ATENCIÓN Y REGISTRO)
-- Incluye la columna 'TIPO_ATENCION' inmediatamente después de 'ID_ATENCION'
-- Ideal para exportar a Excel y construir Tablas Dinámicas usando 
-- "Recuento Distinto" (Distinct Count) de DNI / ID_ATENCION.
-- =============================================================================
SELECT 
    a.id_atencion AS `ID_ATENCION`,
    a.id_tipo_atencion AS `TIPO_ATENCION`,
    p.documento AS `DNI`,
    p.NOMBRECOMPLETO AS `NOMBRE`,
    a.ID_IPRESS AS `ID_IPRESS`,
    i.DESCRIPCIONLOCAL AS `DESCRIPCION_IPRESS`,
    CASE 
        WHEN a.ID_IPRESS IN ('00011794', '00014718', '00016094', '00011833') THEN 'NIVEL II'
        ELSE 'NIVEL I'
    END AS `NIVEL_IPRESS`,
    YEAR(a.FECHA_ATENCION) AS `AÑO`,
    ad.id_tipo_diagnostico AS `TIPO_DIAGNOSTICO`,
    dx.CodigoDiagnostico AS `CIE10`,
    dx.Nombre AS `NOMBRE_DIAGNOSTICO`,
    LEFT(dx.CodigoDiagnostico, 3) AS `CIE10 (LNN)`,
    CASE 
        WHEN LEFT(dx.CodigoDiagnostico, 3) = 'C50' THEN 'CÁNCER DE MAMA'
        WHEN LEFT(dx.CodigoDiagnostico, 3) = 'C18' THEN 'CÁNCER DE COLON'
        WHEN LEFT(dx.CodigoDiagnostico, 3) = 'C16' THEN 'CÁNCER DE ESTÓMAGO'
        WHEN LEFT(dx.CodigoDiagnostico, 3) = 'C34' THEN 'CÁNCER DE PULMÓN'
        WHEN LEFT(dx.CodigoDiagnostico, 3) = 'C53' THEN 'CÁNCER DE CUELLO UTERINO'
        WHEN LEFT(dx.CodigoDiagnostico, 3) = 'C43' THEN 'MELANOMA'
        WHEN LEFT(dx.CodigoDiagnostico, 3) = 'C20' THEN 'CÁNCER DE RECTO'
        WHEN LEFT(dx.CodigoDiagnostico, 3) = 'C22' THEN 'CÁNCER DE HÍGADO'
        WHEN LEFT(dx.CodigoDiagnostico, 3) = 'C44' THEN 'CÁNCER DE PIEL NO MELANOMA'
        WHEN LEFT(dx.CodigoDiagnostico, 3) = 'C61' THEN 'CÁNCER DE PRÓSTATA'
        WHEN LEFT(dx.CodigoDiagnostico, 3) IN ('C81','C82','C83','C84','C85','C86') THEN 'LINFOMA'
        WHEN LEFT(dx.CodigoDiagnostico, 3) = 'C90' THEN 'MIELOMA MÚLTIPLE'
        WHEN LEFT(dx.CodigoDiagnostico, 3) IN ('C91','C92','C93','C94','C95') THEN 'LEUCEMIA'
        ELSE 'OTROS CÁNCERES'
    END AS `TIPO DE CÁNCER`

FROM sgcoresys.atencion a
INNER JOIN sgcoresys.atencion_diagnostico ad 
    ON ad.id_atencion = a.id_atencion
INNER JOIN sgcoresys.ss_ge_diagnostico dx 
    ON dx.idDiagnostico = ad.id_diagnostico
INNER JOIN sgcoresys.personamast p 
    ON p.persona = a.paciente_id
INNER JOIN sgcoresys.ac_sucursal i 
    ON i.SUCURSAL = a.ID_IPRESS

WHERE a.id_tipo_atencion IN ('AM', 'EM', 'HO')
  AND a.ESTADO = 'A'
  AND (
      YEAR(a.FECHA_ATENCION) BETWEEN 2021 AND 2025
      OR a.ID_PERIODO BETWEEN '202101' AND '202512'
  )
  AND LEFT(dx.CodigoDiagnostico, 3) IN (
      'C50', 'C18', 'C16', 'C34', 'C53', 'C43', 
      'C20', 'C22', 'C44', 'C61', 
      'C81', 'C82', 'C83', 'C84', 'C85', 'C86',
      'C90', 
      'C91', 'C92', 'C93', 'C94', 'C95'
  )

ORDER BY 
    `AÑO` ASC,
    `NIVEL_IPRESS`,
    a.id_tipo_atencion,
    `TIPO_DIAGNOSTICO`,
    `CIE10 (LNN)`,
    a.id_atencion;


-- =============================================================================
-- OPCIÓN 2: RESUMEN EJECUTIVO CONSOLIDADO POR GRUPO DE CÁNCER Y CIE10 BASE
-- Realiza el DISTINCT directo en la BD para evitar duplicidades de atendidos.
-- =============================================================================
SELECT 
    YEAR(a.FECHA_ATENCION) AS `AÑO`,
    CASE 
        WHEN a.ID_IPRESS IN ('00011794', '00014718', '00016094', '00011833') THEN 'NIVEL II'
        ELSE 'NIVEL I'
    END AS `NIVEL IPRESS`,
    a.id_tipo_atencion AS `TIPO_ATENCION`,
    ad.id_tipo_diagnostico AS `TIPO_DIAGNOSTICO`,
    LEFT(dx.CodigoDiagnostico, 3) AS `CIE10 (LNN)`,
    CASE 
        WHEN LEFT(dx.CodigoDiagnostico, 3) = 'C50' THEN 'CÁNCER DE MAMA'
        WHEN LEFT(dx.CodigoDiagnostico, 3) = 'C18' THEN 'CÁNCER DE COLON'
        WHEN LEFT(dx.CodigoDiagnostico, 3) = 'C16' THEN 'CÁNCER DE ESTÓMAGO'
        WHEN LEFT(dx.CodigoDiagnostico, 3) = 'C34' THEN 'CÁNCER DE PULMÓN'
        WHEN LEFT(dx.CodigoDiagnostico, 3) = 'C53' THEN 'CÁNCER DE CUELLO UTERINO'
        WHEN LEFT(dx.CodigoDiagnostico, 3) = 'C43' THEN 'MELANOMA'
        WHEN LEFT(dx.CodigoDiagnostico, 3) = 'C20' THEN 'CÁNCER DE RECTO'
        WHEN LEFT(dx.CodigoDiagnostico, 3) = 'C22' THEN 'CÁNCER DE HÍGADO'
        WHEN LEFT(dx.CodigoDiagnostico, 3) = 'C44' THEN 'CÁNCER DE PIEL NO MELANOMA'
        WHEN LEFT(dx.CodigoDiagnostico, 3) = 'C61' THEN 'CÁNCER DE PRÓSTATA'
        WHEN LEFT(dx.CodigoDiagnostico, 3) IN ('C81','C82','C83','C84','C85','C86') THEN 'LINFOMA'
        WHEN LEFT(dx.CodigoDiagnostico, 3) = 'C90' THEN 'MIELOMA MÚLTIPLE'
        WHEN LEFT(dx.CodigoDiagnostico, 3) IN ('C91','C92','C93','C94','C95') THEN 'LEUCEMIA'
        ELSE 'OTROS CÁNCERES'
    END AS `TIPO DE CÁNCER`,
    COUNT(DISTINCT a.id_atencion) AS `CANTIDAD ATENCIONES`,
    COUNT(DISTINCT p.documento) AS `CANTIDAD ATENDIDOS`

FROM sgcoresys.atencion a
INNER JOIN sgcoresys.atencion_diagnostico ad 
    ON ad.id_atencion = a.id_atencion
INNER JOIN sgcoresys.ss_ge_diagnostico dx 
    ON dx.idDiagnostico = ad.id_diagnostico
INNER JOIN sgcoresys.personamast p 
    ON p.persona = a.paciente_id

WHERE a.id_tipo_atencion IN ('AM', 'EM', 'HO')
  AND a.ESTADO = 'A'
  AND (
      YEAR(a.FECHA_ATENCION) BETWEEN 2021 AND 2025
      OR a.ID_PERIODO BETWEEN '202101' AND '202512'
  )
  AND LEFT(dx.CodigoDiagnostico, 3) IN (
      'C50', 'C18', 'C16', 'C34', 'C53', 'C43', 
      'C20', 'C22', 'C44', 'C61', 
      'C81', 'C82', 'C83', 'C84', 'C85', 'C86',
      'C90', 
      'C91', 'C92', 'C93', 'C94', 'C95'
  )

GROUP BY 
    `AÑO`,
    `NIVEL IPRESS`,
    a.id_tipo_atencion,
    `TIPO_DIAGNOSTICO`,
    LEFT(dx.CodigoDiagnostico, 3),
    `TIPO DE CÁNCER`

ORDER BY 
    `AÑO` ASC,
    `NIVEL IPRESS`,
    a.id_tipo_atencion,
    `TIPO_DIAGNOSTICO`,
    `CIE10 (LNN)`;
