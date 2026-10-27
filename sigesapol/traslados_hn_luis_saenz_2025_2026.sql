-- SÁBANA DE ATENCIONES CON PROCEDIMIENTOS DE TRASLADO / TRANSPORTE ASISTIDO
-- EXCEPCIÓN: SOLO HOSPITAL NACIONAL PNP LUIS N. SAENZ (id_establecimiento = 76, NIVEL III)
-- CPMS: 99441, 99441.02, 99442, 99442.01, 99443, 99443.01 - PERIODO 2025-2026
-- UNA FILA POR PROCEDIMIENTO REGISTRADO (SIN AGRUPAR, CONSERVA REGISTROS REPETIDOS)
COPY (
SELECT
    pre.id AS "ID ATENCION",
    a.nro_doc_ident AS "DNI PACIENTE",
    pre.fecha_atencion::date AS "FECHA ATENCION",
    p2.codigo::varchar AS CPMS,
    regexp_replace(p2.descripcion::varchar, E'[\\r\\n\\t]+', ' ', 'g') AS "DESCRIPCIÓN CPMS",
    pp.cantidad AS "CANTIDAD",
    ta.nombre AS "TIPO ATENCION",
    e.id AS "ID IPRESS",
    e.nombre AS IPRESS
FROM prestaciones pre
LEFT JOIN asegurados a
    ON a.id = pre.id_asegurado
INNER JOIN establecimientos e
    ON e.id = pre.id_establecimiento
LEFT JOIN tipo_atenciones ta
    ON ta.id = pre.id_tipo_atencion
INNER JOIN prestacion_procedimientos pp
    ON pp.id_prestacion = pre.id
INNER JOIN procedimientos p2
    ON p2.id = pp.id_procedimiento
WHERE pre.fecha_atencion >= '2025-01-01'
  AND pre.fecha_atencion <  '2027-01-01'
  AND e.id = 76
  AND pre.id_estado_reg = 1
  AND p2.codigo IN ('99441', '99441.02', '99442', '99442.01', '99443', '99443.01')
ORDER BY pre.fecha_atencion, pre.id, p2.codigo
) TO 'C:/temp/traslados_hn_luis_saenz_2025_2026.csv' WITH (FORMAT CSV, HEADER);
