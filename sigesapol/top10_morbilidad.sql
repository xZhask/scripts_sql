--TOP 10 MORBILIDAD POR NIVEL Y TIPO DE ATENCIÓN
SELECT
    dx.codigo AS CIE10,
    dx.nombre AS "DESCRIPCIÓN DIAGNÓSTICO",
	COUNT(DISTINCT (p.id, dx.codigo)) AS CANTIDAD

FROM prestaciones p
INNER JOIN establecimientos e ON p.id_establecimiento = e.id
INNER JOIN receta_diagnosticos rd ON p.id = rd.id_prestacion
INNER JOIN diagnosticos dx ON dx.id = rd.id_diagnostico
LEFT JOIN asegurados a ON a.id = p.id_asegurado

WHERE 
    p.fecha_atencion >= '2026-01-01'
    AND p.fecha_atencion <  '2026-04-01'
    AND p.id_estado_reg = 1
    AND dx.codigo NOT LIKE 'Z%'
    AND rd.id_tipo_diagnostico = 2
    AND p.id_tipo_atencion = 1 -- CAMBIAR DE TIPO DE ATENCIÓN 1: AMBULATORIA, 2: EMERGENCIA, 3: HOSPITALIZACIÓN, 7: URGENCIA
    AND AGE(p.fecha_atencion, a.fecha_nac::date) >= INTERVAL '18 years' -- CONFIGURAR EDAD
    AND (
        CASE 
            WHEN e.id IN (39,26,77,75) THEN 'II'
			WHEN e.id = 76 THEN 'III'
            ELSE 'I'
        END
    ) = 'I' -- CAMBIAR DE NIVEL

GROUP BY dx.codigo, dx.nombre
ORDER BY cantidad DESC
LIMIT 10;