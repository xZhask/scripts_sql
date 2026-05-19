# Morbilidad agrupada
SELECT

    YEAR(a.fecha_atencion) AS ANIO,

    p.SEXO,

    dx.CodigoDiagnostico AS CIE10,

MIN(
    CONVERT(
        BINARY(CONVERT(dx.nombre USING latin1))
        USING utf8mb4
    )
) AS DESCRIPCION_DIAGNOSTICO,

    CASE
        WHEN a.PACIENTE_EDAD BETWEEN 0 AND 11 THEN '0-11 (NIÑEZ)'
        WHEN a.PACIENTE_EDAD BETWEEN 12 AND 17 THEN '12-17 (ADOLESCENCIA)'
        WHEN a.PACIENTE_EDAD BETWEEN 18 AND 29 THEN '18-29 (JUVENTUD)'
        WHEN a.PACIENTE_EDAD BETWEEN 30 AND 59 THEN '30-59 (ADULTEZ)'
        WHEN a.PACIENTE_EDAD >= 60 THEN '60+ (ADULTO MAYOR)'
        ELSE 'SIN DATO'
    END AS GRUPO_ETARIO,

    CASE
        WHEN a.ID_IPRESS IN ('00011794', '00014718', '00016094', '00011833')
            THEN 'NIVEL II'
        ELSE 'NIVEL I'
    END AS NIVEL_ATENCION,

    COUNT(DISTINCT p.documento) AS ATENDIDOS

FROM ATENCION a

INNER JOIN atencion_diagnostico ad
    ON a.id_atencion = ad.id_atencion

INNER JOIN ss_ge_diagnostico dx
    ON dx.idDiagnostico = ad.id_diagnostico

INNER JOIN personamast p
    ON p.persona = a.paciente_id

WHERE a.id_tipo_atencion IN ('AM','EM','HO')
AND a.ESTADO = 'A'
AND ad.id_secuencia = 1
AND ad.id_tipo_diagnostico = '02'
AND dx.CodigoDiagnostico NOT LIKE 'Z%'
AND a.fecha_atencion >= '2025-01-01'
AND a.fecha_atencion < '2026-01-01'

GROUP BY

    YEAR(a.fecha_atencion),

    p.SEXO,

    dx.CodigoDiagnostico,

    CASE
        WHEN a.PACIENTE_EDAD BETWEEN 0 AND 11 THEN '0-11 (NIÑEZ)'
        WHEN a.PACIENTE_EDAD BETWEEN 12 AND 17 THEN '12-17 (ADOLESCENCIA)'
        WHEN a.PACIENTE_EDAD BETWEEN 18 AND 29 THEN '18-29 (JUVENTUD)'
        WHEN a.PACIENTE_EDAD BETWEEN 30 AND 59 THEN '30-59 (ADULTEZ)'
        WHEN a.PACIENTE_EDAD >= 60 THEN '60+ (ADULTO MAYOR)'
        ELSE 'SIN DATO'
    END,

    CASE
        WHEN a.ID_IPRESS IN ('00011794', '00014718', '00016094', '00011833')
            THEN 'NIVEL II'
        ELSE 'NIVEL I'
    END;
