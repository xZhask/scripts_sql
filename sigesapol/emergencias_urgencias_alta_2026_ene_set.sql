-- =============================================================================
-- SIGESAPOL · ATENCIONES DE EMERGENCIA Y URGENCIA, CON Y SIN FECHA DE ALTA
-- Periodo: ENERO - SETIEMBRE 2026 (fecha de atención de la prestación)
-- Base: sigesapol_setiembre (PostgreSQL 18, puerto 5433)
--
-- Salida: 1 fila por prestación (atención). ALTA = 'SI' / 'NO'.
--
-- Criterios:
--   - Prestaciones activas (id_estado_reg = 1), tipo 2 EMERGENCIA y 7 URGENCIA.
--   - Fecha de atención entre 2026-01-01 y 2026-09-30.
--   - Se excluye el HOSPITAL NACIONAL PNP LUIS N. SAENZ (id 76, nivel III).
--   - Se excluyen las emergencias ANULADAS / ELIMINADAS (emergencias.estado = 0)
--     aunque su prestación siga activa. En urgencias, anulada = prestación
--     inactiva, ya fuera por id_estado_reg.
--
-- Dónde está el alta:
--   - EMERGENCIA: emergencias.fecha_alta_medica (prestaciones.id_ext =
--     emergencias.id). Es el único campo de alta que se llena.
--   - URGENCIA: SIGESAPOL no registra alta (sin enlace con emergencias,
--     prestaciones.fecha_alta vacía e id_motivo_alta = 0): todas salen con
--     ALTA = 'NO' y SITUACION_ALTA = 'URGENCIA: SIGESAPOL NO REGISTRA ALTA'.
--
-- emergencias.estado (sin catálogo en la BD; significado inferido de los
-- datos 2026): 1 ADMITIDA, 2 EN TRIAJE, 3 EN ATENCIÓN SIN ALTA, 5 CON ALTA.
--
-- Totales esperados (restauración de setiembre): 46,511 atenciones =
-- 42,113 emergencia (39,333 con alta, 2,780 sin alta) + 4,398 urgencia.
-- ⚠ El H.R. PNP Chiclayo concentra ~2,450 de las emergencias sin alta
--   (dejó de registrar altas desde junio 2026).
-- =============================================================================

SELECT
    p.id                                            AS ID_ATENCION,
    to_char(p.fecha_atencion, 'YYYYMM')             AS PERIODO,
    p.fecha_atencion::date                          AS FECHA_ATENCION,
    CASE p.id_tipo_atencion
        WHEN 2 THEN 'EMERGENCIA'
        WHEN 7 THEN 'URGENCIA'
    END                                             AS TIPO_ATENCION,
    CASE WHEN em.fecha_alta_medica IS NOT NULL THEN 'SI' ELSE 'NO' END
                                                    AS ALTA,
    CASE
        WHEN p.id_tipo_atencion = 7         THEN 'URGENCIA: SIGESAPOL NO REGISTRA ALTA'
        WHEN em.fecha_alta_medica IS NOT NULL THEN 'CON ALTA MEDICA'
        WHEN em.estado = 1                  THEN 'ADMITIDA, SIN ATENCION'
        WHEN em.estado = 2                  THEN 'EN TRIAJE'
        WHEN em.estado = 3                  THEN 'EN ATENCION, SIN ALTA'
        ELSE 'SIN ALTA (ESTADO ' || em.estado || ')'
    END                                             AS SITUACION_ALTA,

    -- Paciente
    a.tipo_doc_ident                                AS TIPO_DOCUMENTO,
    TRIM(a.nro_doc_ident)                           AS DNI,
    TRIM(CONCAT_WS(' ', a.paterno, a.materno, a.nombre)) AS PACIENTE,
    a.sexo                                          AS SEXO,
    c.parentesco                                    AS TIPO_BENEFICIARIO,

    -- IPRESS / servicio
    e.codigo                                        AS CODIGO_IPRESS,
    e.nombre                                        AS IPRESS,
    p.codigo_upss                                   AS CODIGO_UPS,
    u.descripcion_upss                              AS UPS,
    co.nombre                                       AS CONSULTORIO,
    TRIM(CONCAT_WS(' ', m.paterno, m.materno, m.nombre)) AS PROFESIONAL,

    -- Emergencia (vacío en urgencias)
    em.id                                           AS ID_EMERGENCIA,
    em.estado                                       AS ESTADO_EMERGENCIA,
    em.fecha_registro_ingreso                       AS FECHA_INGRESO_EMERGENCIA,
    pr.descripcion                                  AS PRIORIDAD,
    em.fecha_atencion                               AS FECHA_ATENCION_EMERGENCIA,
    em.fecha_alta_medica                            AS FECHA_ALTA_MEDICA

FROM prestaciones p

INNER JOIN establecimientos e
    ON e.id = p.id_establecimiento

LEFT JOIN asegurados a
    ON a.id = p.id_asegurado

LEFT JOIN citas c
    ON c.id = p.id_cita

LEFT JOIN sub_consultorios sc
    ON sc.id = COALESCE(p.id_sub_consultorio, c.id_sub_consultorio)

LEFT JOIN consultorios co
    ON co.id = sc.id_consultorio

LEFT JOIN medicos m
    ON m.id = p.id_medico

LEFT JOIN (
    SELECT DISTINCT ON (codigo)
           codigo,
           descripcion_upss
    FROM upsses
    ORDER BY codigo, updated_at DESC
) u
    ON u.codigo = p.codigo_upss

LEFT JOIN emergencias em
    ON  p.id_tipo_atencion = 2
    AND em.id = p.id_ext

LEFT JOIN prioridades pr
    ON pr.id = em.id_prioridad

WHERE p.fecha_atencion >= '2026-01-01'
  AND p.fecha_atencion <  '2026-10-01'
  AND p.id_estado_reg = 1
  AND p.id_tipo_atencion IN (2, 7)
  AND p.id_establecimiento <> 76            -- EXCLUIR HOSPITAL NACIONAL PNP LUIS N. SAENZ (nivel III)
  AND (p.id_tipo_atencion = 7 OR em.estado <> 0)  -- EXCLUIR EMERGENCIAS ANULADAS / ELIMINADAS

ORDER BY p.fecha_atencion, TIPO_ATENCION, e.codigo, p.id;
