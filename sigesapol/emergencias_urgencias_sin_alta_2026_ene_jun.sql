-- =============================================================================
-- SIGESAPOL · ATENCIONES DE EMERGENCIA Y URGENCIA SIN FECHA DE ALTA
-- Periodo: ENERO - JUNIO 2026 (fecha de atención de la prestación)
-- Base: sigesapol_setiembre (PostgreSQL 18, puerto 5433)
--
-- Salida: 1 fila por prestación (atención) sin alta registrada.
--
-- Criterios:
--   - Prestaciones activas (id_estado_reg = 1), tipo 2 EMERGENCIA y 7 URGENCIA.
--   - Fecha de atención entre 2026-01-01 y 2026-06-30.
--   - Se excluye el HOSPITAL NACIONAL PNP LUIS N. SAENZ (id 76, nivel III).
--
-- Dónde está el alta:
--   - EMERGENCIA: emergencias.fecha_alta_medica (prestaciones.id_ext =
--     emergencias.id). Es el único campo de alta que se llena:
--     fecha_egreso, fecha_egreso_medico, fecha_egreso_administrativa y
--     fecha_registro_egreso están vacíos en todo el periodo.
--   - URGENCIA: SIGESAPOL no registra alta. No se enlazan con emergencias
--     (id_ext vacío) y prestaciones.fecha_alta / fecha_alta_servicio están
--     vacíos e id_motivo_alta = 0 en todas. Por eso TODAS las urgencias
--     salen aquí; se marcan aparte en SITUACION_ALTA para poder filtrarlas.
--
-- emergencias.estado (sin catálogo en la BD; significado inferido de los
-- datos ene-jun 2026):
--   0 ANULADA / ELIMINADA (motivo_anulacion u observacion_elimina_paciente)
--   1 ADMITIDA, SIN ATENCIÓN      2 EN TRIAJE
--   3 EN ATENCIÓN, SIN ALTA       5 CON ALTA MÉDICA
--
-- ⚠ La foto es la de la restauración (setiembre): una emergencia con alta
--   registrada después del 30/06 ya no sale como pendiente.
-- =============================================================================

SELECT
    p.id                                            AS ID_ATENCION,
    p.fecha_atencion::date                          AS FECHA_ATENCION,
    CASE p.id_tipo_atencion
        WHEN 2 THEN 'EMERGENCIA'
        WHEN 7 THEN 'URGENCIA'
    END                                             AS TIPO_ATENCION,
    CASE
        WHEN p.id_tipo_atencion = 7 THEN 'URGENCIA: SIGESAPOL NO REGISTRA ALTA'
        WHEN em.estado = 0          THEN 'EMERGENCIA ANULADA / ELIMINADA'
        WHEN em.estado = 1          THEN 'ADMITIDA, SIN ATENCION'
        WHEN em.estado = 2          THEN 'EN TRIAJE'
        WHEN em.estado = 3          THEN 'EN ATENCION, SIN ALTA'
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
    em.fecha_alta_medica                            AS FECHA_ALTA_MEDICA,
    em.fecha_anulacion                              AS FECHA_ANULACION,
    regexp_replace(COALESCE(em.motivo_anulacion, em.observacion_elimina_paciente), E'[\\r\\n\\t]+', ' ', 'g')
                                                    AS MOTIVO_ANULACION_ELIMINACION

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
  AND p.fecha_atencion <  '2026-07-01'
  AND p.id_estado_reg = 1
  AND p.id_tipo_atencion IN (2, 7)
  AND p.id_establecimiento <> 76  -- EXCLUIR HOSPITAL NACIONAL PNP LUIS N. SAENZ (nivel III)
  AND (p.id_tipo_atencion = 7 OR em.fecha_alta_medica IS NULL)

ORDER BY TIPO_ATENCION, e.codigo, p.fecha_atencion, p.id;
