-- DATA GENERAL DE ATENCIONES INCLUYE INFORMACIÓN DE EMERGENCIAS
-- UNA FILA POR PROCEDIMIENTO REALIZADO EN LA ATENCIÓN
--
-- CAMPOS DE LABORATORIO (solo procedimientos con tipo_procedimiento = 2; NULL en el resto):
--   lab_toma_confirmada : 'SI' si prestacion_procedimientos.confirmar_toma está registrado
--                         (criterio de "realizado"). 'NO' puede significar no realizado o que
--                         la IPRESS no usa la confirmación de toma (Callao, Tumbes, postas...).
--   lab_resultado       : evidencia en laboratorio_archivos_resultados (PDF activo):
--                         'RESULTADO PROPIO'      -> el procedimiento tiene PDF
--                         'RESULTADO EN LA ORDEN' -> sin PDF propio, pero otro examen de la misma
--                                                    orden sí (el PDF se sube por área: BIOQ, HEMO...)
--                         'SIN RESULTADO'         -> ningún examen de la orden tiene PDF
--   Se calculan con agregados (no van en el GROUP BY) para no alterar las filas de la sábana.
COPY (
WITH em AS (
    SELECT
        id,
        id_asegurado,
        fecha_registro_ingreso,
        id_establecimiento,
        id_prioridad,
        fecha_atencion,
        estado,
        id_tipo_egres_med,
        id_condi_egres_med,
        ubica_prioridad,
        cama_estado,
        fecha_inicio_estado,
        regexp_replace(obs_traslado::varchar, E'[\\r\\n\\t]+', ' ', 'g') AS obs_traslado,
        fecha_alta_medica,
        regexp_replace(observacion_elimina_paciente::varchar, E'[\\r\\n\\t]+', ' ', 'g') AS obs_elimina_paciente,
        cpms_alta
    FROM emergencias
    WHERE fecha_registro_ingreso >= '2026-03-01'
      AND fecha_registro_ingreso <  '2026-04-01'
      AND id_establecimiento <> 76
),
-- MATERIALIZED: se calculan una sola vez (sin esto el plan recorre los resultados por
-- cada atención y la query pasa de segundos a más de 20 minutos)
lab_res_pp AS MATERIALIZED (
    -- procedimientos de laboratorio con PDF de resultado activo
    SELECT DISTINCT ar.id_prestacion_procedimiento AS id_pp
    FROM laboratorio_archivos_resultados ar
    WHERE ar.estado
),
lab_res_ord AS MATERIALIZED (
    -- órdenes de laboratorio con al menos un PDF de resultado activo
    SELECT DISTINCT ppr.id_lab_rad
    FROM lab_res_pp r
    INNER JOIN prestacion_procedimientos ppr
        ON ppr.id = r.id_pp
    WHERE ppr.id_lab_rad > 0
)
SELECT
    pre.id AS "ID ATENCION",
    pre.fecha_atencion,
    pre.id_tipo_atencion AS "TIPO ATENCION",
    a.nro_doc_ident AS DNI,
    a.id_tipo_beneficiario,
    c.parentesco AS "TIPO BENEFICIARIO",
    e.codigo AS "CODIGO IPRESS",
    e.nombre AS IPRESS,
    p2.seccion,
    pre.id_ext,
    p2.codigo::varchar AS CPMS,
    regexp_replace(p2.descripcion::varchar, E'[\\r\\n\\t]+', ' ', 'g') AS "DESCRIPCIÓN PROCEDIMIENTO",
    pp.cantidad AS "CANTIDAD PROCEDIMIENTOS",
    m.dni AS dni_profesional,
    m.paterno AS paterno_profesional,
    m.materno AS materno_profesional,
    regexp_replace(m.nombre, E'[\\r\\n\\t]+', ' ', 'g') AS nombre_profesional,

    CASE
        WHEN prof.nombre = 'MEDICO GENERAL' THEN 'MÉDICO'
        WHEN prof.nombre = 'MEDICO ESPECIALISTA' THEN 'MÉDICO'
        WHEN prof.nombre = 'QUIMICO FARMACEUTICO' THEN 'QUÍMICO'
        WHEN prof.nombre = 'ODONTOLOGIA' THEN 'ODONTÓLOGO'
        WHEN prof.nombre = 'OBSTETRICIA' THEN 'OBSTETRA'
        WHEN prof.nombre = 'ENFERMERIA' THEN 'ENFERMERÍA'
        WHEN prof.nombre = 'PSICOLOGIA' THEN 'PSICÓLOGOS'
        WHEN prof.nombre = 'TECNOLOGÍA MEDICA' THEN 'TECNÓLOGOS MÉDICOS'
        WHEN prof.nombre = 'NUTRICIONISTA' THEN 'NUTRICIONISTA'
        WHEN prof.nombre = 'MEDICO CIRUJANO' THEN 'MÉDICO'
        WHEN prof.nombre = 'MEDICO' THEN 'MÉDICO'
        WHEN prof.nombre = 'OFTALMOLOGIA' THEN 'MÉDICO'
        WHEN prof.nombre = 'GINECOLOGIA' THEN 'MÉDICO'
        WHEN prof.nombre = 'BIOLOGO' THEN 'BIÓLOGO'
        ELSE 'OTRO PROFESIONAL DE LA SALUD'
    END AS sp_nombre_profesion_responsable,

    CASE
        WHEN prof.nombre = 'MEDICO GENERAL' THEN '01'
        WHEN prof.nombre = 'MEDICO ESPECIALISTA' THEN '01'
        WHEN prof.nombre = 'QUIMICO FARMACEUTICO' THEN '02'
        WHEN prof.nombre = 'ODONTOLOGIA' THEN '03'
        WHEN prof.nombre = 'OBSTETRICIA' THEN '05'
        WHEN prof.nombre = 'ENFERMERIA' THEN '06'
        WHEN prof.nombre = 'PSICOLOGIA' THEN '07'
        WHEN prof.nombre = 'TECNOLOGÍA MEDICA' THEN '09'
        WHEN prof.nombre = 'NUTRICIONISTA' THEN '10'
        WHEN prof.nombre = 'MEDICO CIRUJANO' THEN '01'
        WHEN prof.nombre = 'MEDICO' THEN '01'
        WHEN prof.nombre = 'OFTALMOLOGIA' THEN '01'
        WHEN prof.nombre = 'GINECOLOGIA' THEN '01'
        WHEN prof.nombre = 'BIOLOGO' THEN '04'
        ELSE '00'
    END AS sp_codigo_profesion_responsable,

    c2.nombre AS "CONSULTORIO",
    pre.codigo_upss,
    u.descripcion_upss,

    -- CAMPOS DE EMERGENCIA
    em.id AS id_emergencia,
    em.id_asegurado AS id_asegurado_emergencia,
    em.fecha_registro_ingreso,
    em.id_establecimiento AS id_establecimiento_emergencia,
    em.id_prioridad,
    em.fecha_atencion AS fecha_atencion_emergencia,
    em.estado AS estado_emergencia,
    em.id_tipo_egres_med,
    em.id_condi_egres_med,
    em.ubica_prioridad,
    em.cama_estado,
    em.fecha_inicio_estado,
    em.obs_traslado,
    em.fecha_alta_medica,
    em.obs_elimina_paciente,
    em.cpms_alta,

    -- CAMPOS DE LABORATORIO
    CASE WHEN bool_or(pp.tipo_procedimiento = 2) THEN
        CASE WHEN bool_or(pp.tipo_procedimiento = 2 AND COALESCE(pp.confirmar_toma, '') <> '')
             THEN 'SI' ELSE 'NO' END
    END AS lab_toma_confirmada,

    CASE MIN(CASE WHEN pp.tipo_procedimiento = 2 THEN
                  CASE WHEN lr_pp.id_pp IS NOT NULL THEN 1
                       WHEN lr_ord.id_lab_rad IS NOT NULL THEN 2
                       ELSE 3 END
             END)
        WHEN 1 THEN 'RESULTADO PROPIO'
        WHEN 2 THEN 'RESULTADO EN LA ORDEN'
        WHEN 3 THEN 'SIN RESULTADO'
    END AS lab_resultado

FROM prestaciones pre
LEFT JOIN asegurados a
    ON a.id = pre.id_asegurado
INNER JOIN establecimientos e
    ON e.id = pre.id_establecimiento
LEFT JOIN citas c
    ON c.id = pre.id_cita
LEFT JOIN sub_consultorios subc
    ON subc.id = c.id_sub_consultorio
LEFT JOIN consultorios c2
    ON c2.id = subc.id_consultorio
INNER JOIN medicos m
    ON m.id = pre.id_medico
INNER JOIN profesiones prof
    ON prof.id = m.id_profesion
LEFT JOIN prestacion_procedimientos pp
    ON pp.id_prestacion = pre.id
LEFT JOIN procedimientos p2
    ON p2.id = pp.id_procedimiento
LEFT JOIN (
    SELECT DISTINCT ON (codigo)
           codigo,
           descripcion_upss
    FROM upsses
    ORDER BY codigo, updated_at DESC
) u
    ON u.codigo = pre.codigo_upss
LEFT JOIN em
    ON pre.id_tipo_atencion = 2
   AND pre.id_ext = em.id
-- lab_res_pp / lab_res_ord no tienen duplicados: no multiplican filas
LEFT JOIN lab_res_pp lr_pp
    ON lr_pp.id_pp = pp.id
LEFT JOIN lab_res_ord lr_ord
    ON pp.tipo_procedimiento = 2
   AND lr_ord.id_lab_rad = pp.id_lab_rad

WHERE pre.fecha_atencion >= '2026-03-01'
  AND pre.fecha_atencion <  '2026-04-01'
  AND e.id <> 76  -- EXCLUIR NIVEL III (Hospital Nacional PNP Luis N. Saenz). No usar e.nivel:
                  -- viene mal cargado para algunos establecimientos (ej. Clínica Angamos
                  -- figura nivel=2 por temas de tarifario, siendo en realidad Nivel I).
  AND pre.id_estado_reg = 1

GROUP BY
    pre.id,
    pre.fecha_atencion,
    pre.id_tipo_atencion,
    a.nro_doc_ident,
    a.id_tipo_beneficiario,
    c.parentesco,
    e.codigo,
    e.nombre,
    p2.seccion,
    pre.id_ext,
    p2.codigo,
    p2.descripcion,
    pp.cantidad,
    m.dni,
    m.paterno,
    m.materno,
    m.nombre,
    prof.nombre,
    c2.nombre,
    pre.codigo_upss,
    u.descripcion_upss,
    em.id,
    em.id_asegurado,
    em.fecha_registro_ingreso,
    em.id_establecimiento,
    em.id_prioridad,
    em.fecha_atencion,
    em.estado,
    em.id_tipo_egres_med,
    em.id_condi_egres_med,
    em.ubica_prioridad,
    em.cama_estado,
    em.fecha_inicio_estado,
    em.obs_traslado,
    em.fecha_alta_medica,
    em.obs_elimina_paciente,
    em.cpms_alta
) TO 'C:/temp/atenciones_feb26.csv' WITH (FORMAT CSV, HEADER);