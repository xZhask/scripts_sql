-- =============================================================================
-- MORBILIDAD GENERAL 2024 (CONSOLIDADO ANUAL POR PERIODO)
-- Columnas: NIVEL_IPRESS, TIPO_ATENCION, PERIODO, CIE10, DESCRIPCION_CIE10,
--           CANTIDAD_ATENCIONES (Únicas), CANTIDAD_ATENDIDOS (Pacientes Únicos)
-- Base de Datos: SEIS (sgcoresys / db_seis_marzo26)
-- =============================================================================

SELECT 
    CASE
        WHEN a.ID_IPRESS IN ('00011794', '00014718', '00016094', '00011833') THEN 'NIVEL II'
        ELSE 'NIVEL I'
    END AS NIVEL_IPRESS,

    CASE a.ID_TIPO_ATENCION
        WHEN 'AM' THEN 'AMBULATORIA'
        WHEN 'EM' THEN 'EMERGENCIA'
        WHEN 'HO' THEN 'HOSPITALIZACIÓN'
        ELSE a.ID_TIPO_ATENCION
    END AS TIPO_ATENCION,

    a.ID_PERIODO AS PERIODO,

    dx.CodigoDiagnostico AS CIE10,

    MIN(
        CONVERT(
            BINARY(CONVERT(dx.nombre USING latin1))
            USING utf8mb4
        )
    ) AS DESCRIPCION_CIE10,

    COUNT(DISTINCT a.id_atencion) AS CANTIDAD_ATENCIONES,
    COUNT(DISTINCT p.documento) AS CANTIDAD_ATENDIDOS

FROM atencion a

INNER JOIN atencion_diagnostico ad 
    ON a.id_atencion = ad.id_atencion

INNER JOIN ss_ge_diagnostico dx 
    ON dx.idDiagnostico = ad.id_diagnostico

INNER JOIN personamast p 
    ON p.persona = a.paciente_id

WHERE a.ID_PERIODO BETWEEN '202401' AND '202412'
  AND a.FECHA_ATENCION >= '2024-01-01 00:00:00'
  AND a.FECHA_ATENCION <= '2024-12-31 23:59:59'
  AND a.id_tipo_atencion IN ('AM', 'EM', 'HO')
  AND a.ESTADO = 'A'
  AND ad.id_secuencia = 1
  AND ad.id_tipo_diagnostico = '02'
  AND dx.CodigoDiagnostico NOT LIKE 'Z%'

GROUP BY 
    CASE
        WHEN a.ID_IPRESS IN ('00011794', '00014718', '00016094', '00011833') THEN 'NIVEL II'
        ELSE 'NIVEL I'
    END,
    CASE a.ID_TIPO_ATENCION
        WHEN 'AM' THEN 'AMBULATORIA'
        WHEN 'EM' THEN 'EMERGENCIA'
        WHEN 'HO' THEN 'HOSPITALIZACIÓN'
        ELSE a.ID_TIPO_ATENCION
    END,
    a.ID_PERIODO,
    dx.CodigoDiagnostico

ORDER BY 
    a.ID_PERIODO ASC,
    NIVEL_IPRESS ASC,
    TIPO_ATENCION ASC,
    CANTIDAD_ATENCIONES DESC;
