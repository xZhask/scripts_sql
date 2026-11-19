-- =============================================================================
-- FUENTE 2 · SIGESAPOL · EGRESOS HOSPITALARIOS · OCTUBRE 2026
-- Base: restauración SIGESAPOL que tenga octubre completo (sigesapol_setiembre
--       solo trae ~50 altas de octubre). Confirmar el nombre con
--       SELECT datname FROM pg_database;
--
-- Salida: 1 fila por hospitalización con alta médica. Columnas IDÉNTICAS a
-- 01_seis_egresos_oct_2026.sql. Exportar con:
--   psql -h localhost -U postgres -d <base> -f 02_sigesapol_egresos_oct_2026.sql \
--        --csv -o datos/extraccion_sigesapol_egresos_oct_2026.csv
--
-- Criterio:
--   - Tabla hospitalizaciones: 1 fila = 1 estancia (nro_hospitalizacion no se
--     repite por IPRESS).
--   - Fecha de egreso = fecha_alta_medica (fecha_salida viene vacía en ~25%
--     de las estancias con alta).
--   - estado IN (6, 7): los dos estados con alta registrada (~97% de las altas
--     2026). Quedan fuera los estados 0, 1 y 4 con fecha de alta (~30 filas en
--     todo 2026) hasta confirmar su significado contra el reporte de la app.
--   - Solo IPRESS de nivel I y II: se excluye el HOSPITAL NACIONAL PNP LUIS N.
--     SAENZ (e.codigo 00013591, nivel III).
--   - MOTIVO_ALTA = id_tipo_egreso / id_condicion_alta (códigos crudos; no hay
--     catálogo en la base). En SEIS es HOSPITALIZACION_ALTA_ID_MOTIVO: los
--     códigos NO son homologables entre sistemas.
--
-- ⚠ Ventana 24-sep a 07-nov a propósito (ver nota en 01_seis_...): el cruce
--   empareja con margen y luego se queda con las altas de octubre.
-- =============================================================================

SELECT
    'SIGESAPOL'                                             AS fuente,
    h.id                                                    AS id_atencion,
    e.codigo                                                AS codigo_ipress,
    TRIM(e.nombre)                                          AS ipress,
    TRIM(h.dni_beneficiario)                                AS dni,
    TRIM(CONCAT_WS(' ', h.paterno_beneficiario, h.materno_beneficiario))
        || ', ' || TRIM(h.nombre_beneficiario)              AS paciente,
    h.sexo                                                  AS sexo,
    h.edad                                                  AS edad,
    to_char(h.fecha_ingreso,     'YYYY-MM-DD HH24:MI')      AS fecha_ingreso,
    to_char(h.fecha_alta_medica, 'YYYY-MM-DD HH24:MI')      AS fecha_alta,
    h.dias_estancia                                         AS dias_estancia,
    h.id_consultorio_hosp                                   AS codigo_servicio,
    NULLIF(TRIM(h.nombre_consultorio), '')                  AS servicio,
    CONCAT_WS('/', h.id_tipo_egreso, h.id_condicion_alta)   AS motivo_alta,
    to_char(h.fecha_ingreso, 'YYYYMM')                      AS periodo_origen
FROM hospitalizaciones h
INNER JOIN establecimientos e ON e.id = h.id_establecimiento
WHERE h.estado IN (6, 7)
  AND e.codigo <> '00013591'                    -- regla: sin Hosp. Luis N. Sáenz (nivel III)
  AND h.fecha_alta_medica >= '2026-09-24'
  AND h.fecha_alta_medica <  '2026-11-08'
ORDER BY e.codigo, h.fecha_alta_medica, h.id;
