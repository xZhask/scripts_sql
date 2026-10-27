-- =============================================================================
-- FUENTE 2 · SIGESAPOL · ATENCIONES CON DIAGNÓSTICOS · ENERO - SETIEMBRE 2026
-- Base: sigesapol_setiembre (PostgreSQL 18, puerto 5432)
--
-- Salida: 1 fila por (atención, diagnóstico). Columnas IDÉNTICAS a
-- 01_seis_atenciones_dx_ene_set_2026.sql para unir ambas fuentes y
-- deduplicar con 03_cruce_seis_sigesapol.py.
--
-- Criterios:
--   - Prestaciones activas (id_estado_reg = 1).
--   - Tipos 1 ambulatorio (AM), 2 emergencia (EM), 7 urgencia (se reporta
--     como EM, igual que SEIS, que registra las urgencias dentro de
--     emergencia) y 3 hospitalización (HO). TIPO_ATENCION_ORIGEN conserva
--     el código original.
--   - Fecha de atención entre 2026-01-01 y 2026-09-30.
--   - Pacientes de 18 años a más, edad a la fecha de la atención
--     (asegurados.fecha_nac se guarda como texto DD/MM/YYYY; 4 prestaciones
--     con fecha inválida quedan fuera).
--   - Solo IPRESS de nivel I y II: se excluye el HOSPITAL NACIONAL PNP LUIS N.
--     SAENZ (codigo 00013591, nivel III).
--   - Solo diagnósticos activos (receta_diagnosticos.estado = 1) y
--     DEFINITIVOS (id_tipo_diagnostico = 2), incluidos los códigos Z.
--
-- Limpieza de diagnósticos (igual que sigesapol/atenciones_diagnosticos_
-- detalle_2026_ene_ago.sql):
--   - Una sola fila por prestación y CIE10 (el mismo CIE10 se repite una vez
--     por receta).
--   - Se descartan diagnósticos registrados ANTES de la fecha de atención
--     (arrastrados de visitas anteriores).
--   - DX_ORDEN = orden de registro; el 1 hace de diagnóstico principal, ya
--     que SIGESAPOL no tiene un campo de secuencia como SEIS.
--   - Una atención sin diagnóstico definitivo sale en una fila con
--     DX_ORDEN = 1 y diagnóstico vacío (cuenta para atenciones/atendidos y
--     para el cruce, no para morbilidad).
--
-- Homologación con SEIS:
--   - TIPO_BENEFICIARIO: TITULAR, CONYUGE (incluye concubina y esposa), HIJO,
--     PADRES, SOBREVIVIENTE (cualquier "... SOBREVIVIENTE"), OTROS. Se toma el
--     parentesco de la cita (dato a la fecha de la atención) y, si viene
--     vacío o inválido, el de la ficha actual del asegurado.
--   - UPS: prestaciones.codigo_upss con su nombre en upsses. ~1.6% de las
--     prestaciones no tiene UPS (casi todas Terapia Física); para esas queda
--     CONSULTORIO.
--
-- Registros dobles: ~178 citas tienen dos prestaciones activas (mismo día,
-- misma UPS). Se conserva una por cita, la última registrada. Las demás
-- atenciones repetidas del mismo paciente, día y UPS tienen citas distintas
-- y se consideran atenciones reales.
-- =============================================================================

WITH prest AS (
    SELECT
        p.id,
        p.fecha_atencion,
        p.id_tipo_atencion,
        p.id_cita,
        p.id_asegurado,
        p.id_sub_consultorio,
        p.codigo_upss,
        e.codigo AS codigo_ipress,
        e.nombre AS ipress,
        date_part('year', age(p.fecha_atencion::date, to_date(a.fecha_nac, 'DD/MM/YYYY')))::int AS edad
    FROM prestaciones p
    INNER JOIN establecimientos e
        ON e.id = p.id_establecimiento
    INNER JOIN asegurados a
        ON a.id = p.id_asegurado
    WHERE p.fecha_atencion >= '2026-01-01'
      AND p.fecha_atencion <  '2026-10-01'
      AND p.id_estado_reg = 1
      AND p.id_tipo_atencion IN (1, 2, 3, 7)
      AND e.codigo <> '00013591'  -- EXCLUIR HOSPITAL NACIONAL PNP LUIS N. SAENZ (nivel III)
      AND a.fecha_nac ~ '^\d{2}/\d{2}/\d{4}$'
      AND age(p.fecha_atencion::date, to_date(a.fecha_nac, 'DD/MM/YYYY')) >= interval '18 years'
      -- una prestación por cita: descarta la registrada antes si hay otra
      AND NOT EXISTS (
          SELECT 1
          FROM prestaciones p2
          WHERE p2.id_cita = p.id_cita
            AND p2.id > p.id
            AND p2.id_estado_reg = 1
            AND p2.id_tipo_atencion IN (1, 2, 3, 7)
      )
),
dx_prest AS (
    -- 1 fila por prestación y diagnóstico definitivo
    SELECT
        rd.id_prestacion,
        rd.id_diagnostico,
        MIN(rd.id) AS primer_registro
    FROM prest p
    INNER JOIN receta_diagnosticos rd
        ON rd.id_prestacion = p.id
    WHERE rd.estado = 1
      AND rd.id_tipo_diagnostico = 2  -- DEFINITIVO
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
    'SIGESAPOL'                                     AS FUENTE,
    p.id                                            AS ID_ATENCION,
    to_char(p.fecha_atencion, 'YYYYMM')             AS PERIODO,
    p.fecha_atencion::date                          AS FECHA_ATENCION,
    p.id_tipo_atencion                              AS TIPO_ATENCION_ORIGEN,
    CASE p.id_tipo_atencion
        WHEN 1 THEN 'AM'
        WHEN 2 THEN 'EM'
        WHEN 7 THEN 'EM'
        WHEN 3 THEN 'HO'
    END                                             AS TIPO_ATENCION,

    -- Paciente
    a.tipo_doc_ident                                AS TIPO_DOCUMENTO,
    TRIM(a.nro_doc_ident)                           AS DNI,
    a.sexo                                          AS SEXO,
    p.edad                                          AS EDAD,
    ben.origen                                      AS TIPO_BENEFICIARIO_ORIGEN,
    CASE
        WHEN ben.origen LIKE '%SOBREVIVIENTE'                      THEN 'SOBREVIVIENTE'
        WHEN ben.origen = 'TITULAR'                                THEN 'TITULAR'
        WHEN ben.origen IN ('CONYUGE', 'CONCUBINA(O)', 'ESPOSA')   THEN 'CONYUGE'
        WHEN ben.origen LIKE 'HIJO%'                               THEN 'HIJO'
        WHEN ben.origen = 'PADRES'                                 THEN 'PADRES'
        ELSE 'OTROS'
    END                                             AS TIPO_BENEFICIARIO,

    -- IPRESS
    p.codigo_ipress                                 AS CODIGO_IPRESS,
    p.ipress                                        AS IPRESS,
    CASE
        WHEN p.codigo_ipress IN ('00011794','00014718','00016094','00011833') THEN 'II'
        ELSE 'I'
    END                                             AS NIVEL_IPRESS,

    -- UPS
    p.codigo_upss                                   AS CODIGO_UPS,
    u.descripcion_upss                              AS UPS,
    co.nombre                                       AS CONSULTORIO,

    -- Diagnóstico
    COALESCE(d.dx_orden, 1)                         AS DX_ORDEN,
    dx.codigo                                       AS CIE10,
    dx.nombre                                       AS DIAGNOSTICO

FROM prest p

INNER JOIN asegurados a
    ON a.id = p.id_asegurado

LEFT JOIN citas c
    ON c.id = p.id_cita

LEFT JOIN tipo_beneficiarios tb
    ON tb.id = a.id_tipo_beneficiario

LEFT JOIN sub_consultorios sc
    ON sc.id = COALESCE(p.id_sub_consultorio, c.id_sub_consultorio)

LEFT JOIN consultorios co
    ON co.id = sc.id_consultorio

LEFT JOIN ups u
    ON u.codigo = p.codigo_upss

-- Parentesco de la cita; si está vacío o es basura ('DNI'), el de la ficha
CROSS JOIN LATERAL (
    SELECT COALESCE(
               NULLIF(NULLIF(TRIM(c.parentesco), ''), 'DNI'),
               NULLIF(TRIM(tb.descripcion), '')
           ) AS origen
) ben

LEFT JOIN dx_orden d
    ON d.id_prestacion = p.id

LEFT JOIN diagnosticos dx
    ON dx.id = d.id_diagnostico

ORDER BY p.fecha_atencion, p.id, d.dx_orden;
