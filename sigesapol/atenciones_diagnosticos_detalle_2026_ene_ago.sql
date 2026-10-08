-- =============================================================================
-- DETALLE DE ATENCIONES CON TODOS SUS DIAGNÓSTICOS · ENERO - AGOSTO 2026
-- Base: SIGESAPOL (PostgreSQL)
--
-- Salida: 1 fila por (atención, diagnóstico). Una atención con 3 diagnósticos
-- sale en 3 filas, con DX_ORDEN 1, 2 y 3.
--
-- Cómo contar sobre el resultado:
--   - ATENCIONES = COUNT(DISTINCT ID_ATENCION), o las filas con DX_ORDEN = 1
--                  (cada atención tiene exactamente una).
--   - ATENDIDOS  = COUNT(DISTINCT NRO_DOCUMENTO).
--
-- Criterios:
--   - Prestaciones activas (id_estado_reg = 1) con fecha de atención entre
--     2026-01-01 y 2026-08-31, de todos los tipos de atención.
--   - Solo IPRESS de nivel I y II: se excluye el HOSPITAL NACIONAL PNP LUIS N.
--     SAENZ (codigo 00013591, nivel III). Nivel II = 00011794 Arequipa,
--     00014718 Geriátrico San José, 00016094 Augusto B. Leguía, 00011833
--     Chiclayo; el resto es nivel I. No se usa establecimientos.nivel porque
--     viene mal cargado en algunos establecimientos.
--   - Diagnósticos activos (receta_diagnosticos.estado = 1) de cualquier tipo
--     (presuntivo, definitivo, repetitivo), incluidos los códigos Z.
--
-- Limpieza de diagnósticos:
--   - El mismo CIE10 puede estar registrado varias veces en una prestación
--     (por ejemplo, una vez por cada receta). Se deja una sola fila por
--     prestación y diagnóstico. Si se registró con tipos distintos, se toma
--     DEFINITIVO, luego REPETITIVO, luego PRESUNTIVO.
--   - Se descartan los diagnósticos registrados ANTES de la fecha de la
--     atención: son diagnósticos de visitas anteriores del paciente que
--     quedaron asociados a la prestación (pocos casos, pero inflan mucho la
--     prestación afectada).
--   - Una atención sin diagnósticos sale igual, en una fila con DX_ORDEN = 1 y
--     las columnas de diagnóstico vacías.
--
-- Campos del paciente:
--   - TIPO_BENEFICIARIO: parentesco registrado en la cita, es decir, el de la
--     fecha de la atención. TIPO_BENEFICIARIO_ACTUAL es el de la ficha del
--     asegurado hoy.
--   - EDAD: años cumplidos a la fecha de la atención (asegurados.fecha_nac se
--     guarda como texto DD/MM/YYYY).
--
-- Médico: el profesional registrado en la prestación (prestaciones.id_medico).
--
-- UPS: ~11 mil atenciones ambulatorias (casi todas de Terapia Física y
-- Rehabilitación) no tienen código UPS en la prestación; para esas usar la
-- columna CONSULTORIO.
--
-- Validado (2026-10-07) contra la copia local sigesapol_agosto (~1.5 min):
--   1,082,385 filas | 773,674 atenciones | 167,839 atendidos | 79 IPRESS.
--   Ambulatorio 730,759 | Emergencia 37,124 | Urgencia 3,506 |
--   Hospitalización 2,284 | Centro quirúrgico 1.
--   Nivel I 505,535 | Nivel II 268,139.
--   Sin filas repetidas por atención + CIE10. Todas las atenciones tienen
--   médico; 45 no tienen diagnóstico.
-- =============================================================================

WITH prest AS (
    SELECT p.*
    FROM prestaciones p
    INNER JOIN establecimientos e
        ON e.id = p.id_establecimiento
    WHERE p.fecha_atencion >= '2026-01-01'
      AND p.fecha_atencion <  '2026-09-01'
      AND p.id_estado_reg = 1
      AND e.codigo <> '00013591'  -- EXCLUIR HOSPITAL NACIONAL PNP LUIS N. SAENZ (nivel III)
),
dx_prest AS (
    -- 1 fila por prestación y diagnóstico
    SELECT
        rd.id_prestacion,
        rd.id_diagnostico,
        MAX(CASE rd.id_tipo_diagnostico WHEN 2 THEN 3 WHEN 3 THEN 2 WHEN 1 THEN 1 END) AS prioridad_tipo,
        MIN(rd.id) AS primer_registro
    FROM prest p
    INNER JOIN receta_diagnosticos rd
        ON rd.id_prestacion = p.id
    WHERE rd.estado = 1
      AND rd.id_diagnostico IS NOT NULL
      AND (rd.created_at IS NULL OR rd.created_at::date >= p.fecha_atencion::date)
    GROUP BY rd.id_prestacion, rd.id_diagnostico
),
dx_orden AS (
    SELECT
        d.*,
        ROW_NUMBER() OVER (PARTITION BY d.id_prestacion ORDER BY d.primer_registro) AS dx_orden
    FROM dx_prest d
),
ups AS (
    SELECT DISTINCT ON (codigo)
           codigo,
           descripcion_upss
    FROM upsses
    ORDER BY codigo, updated_at DESC
)
SELECT
    p.id                                            AS ID_ATENCION,
    to_char(p.fecha_atencion, 'YYYYMM')             AS PERIODO,
    p.fecha_atencion::date                          AS FECHA_ATENCION,
    p.id_tipo_atencion                              AS ID_TIPO_ATENCION,
    ta.nombre                                       AS TIPO_ATENCION,

    -- IPRESS, UPS y consultorio
    e.codigo                                        AS CODIGO_IPRESS,
    e.nombre                                        AS IPRESS,
    CASE
        WHEN e.codigo IN ('00011794','00014718','00016094','00011833') THEN 'II'
        ELSE 'I'
    END                                             AS NIVEL_IPRESS,
    p.codigo_upss                                   AS CODIGO_UPS,
    u.descripcion_upss                              AS UPS,
    co.nombre                                       AS CONSULTORIO,
    sc.descripcion                                  AS SUB_CONSULTORIO,

    -- Paciente
    a.tipo_doc_ident                                AS TIPO_DOCUMENTO,
    a.nro_doc_ident                                 AS NRO_DOCUMENTO,
    a.paterno || ' ' || a.materno || ', ' || a.nombre AS PACIENTE,
    a.sexo                                          AS SEXO,
    a.fecha_nac                                     AS FECHA_NACIMIENTO,
    CASE
        WHEN a.fecha_nac ~ '^\d{2}/\d{2}/\d{4}$'
        THEN date_part('year', age(p.fecha_atencion::date, to_date(a.fecha_nac, 'DD/MM/YYYY')))::int
    END                                             AS EDAD,
    c.parentesco                                    AS TIPO_BENEFICIARIO,
    tb.descripcion                                  AS TIPO_BENEFICIARIO_ACTUAL,
    si.descripcion                                  AS SITUACION,
    a.grado                                         AS GRADO,

    -- Médico / profesional responsable
    m.dni                                           AS DNI_MEDICO,
    m.paterno || ' ' || m.materno || ', ' || m.nombre AS MEDICO,
    prof.nombre                                     AS PROFESION_MEDICO,
    esp.nombre                                      AS ESPECIALIDAD_MEDICO,
    m.colegiatura                                   AS COLEGIATURA,

    -- Diagnóstico
    COALESCE(d.dx_orden, 1)                         AS DX_ORDEN,
    dx.codigo                                       AS CIE10,
    dx.nombre                                       AS DESCRIPCION_CIE10,
    CASE d.prioridad_tipo
        WHEN 3 THEN 'DEFINITIVO'
        WHEN 2 THEN 'REPETITIVO'
        WHEN 1 THEN 'PRESUNTIVO'
    END                                             AS TIPO_DIAGNOSTICO

FROM prest p

INNER JOIN establecimientos e
    ON e.id = p.id_establecimiento

LEFT JOIN tipo_atenciones ta
    ON ta.id = p.id_tipo_atencion

LEFT JOIN asegurados a
    ON a.id = p.id_asegurado

LEFT JOIN tipo_beneficiarios tb
    ON tb.id = a.id_tipo_beneficiario

LEFT JOIN situaciones si
    ON si.id = a.id_situacion

LEFT JOIN citas c
    ON c.id = p.id_cita

LEFT JOIN sub_consultorios sc
    ON sc.id = COALESCE(p.id_sub_consultorio, c.id_sub_consultorio)

LEFT JOIN consultorios co
    ON co.id = sc.id_consultorio

LEFT JOIN ups u
    ON u.codigo = p.codigo_upss

LEFT JOIN medicos m
    ON m.id = p.id_medico

LEFT JOIN profesiones prof
    ON prof.id = m.id_profesion

LEFT JOIN especializaciones esp
    ON esp.id = m.id_especializacion

LEFT JOIN dx_orden d
    ON d.id_prestacion = p.id

LEFT JOIN diagnosticos dx
    ON dx.id = d.id_diagnostico

ORDER BY p.fecha_atencion, p.id, d.dx_orden;
