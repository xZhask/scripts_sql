-- =============================================================================
-- SIGESAPOL · PRODUCCIÓN DE UN PROFESIONAL (atenciones y procedimientos)
-- Base: sigesapol_octubre (PostgreSQL 18, localhost:5432)
--
-- Caso: médico general (DNI del profesional en el CTE "par"; no se versiona, repo público)
--       POLICLINICO PNP TUMBES (00012088)
--       Registró en SIGESAPOL de junio a octubre 2026; de enero a mayo en SEIS
--       (ver seis/produccion_profesional_2026.sql).
--
-- Para otro profesional o periodo, cambiar solo el CTE "par" de cada consulta.
--
-- Criterios:
--   - Prestaciones activas (id_estado_reg = 1) cuyo profesional es el médico
--     (prestaciones.id_medico → medicos.dni), por fecha de atención.
--   - Se excluye el HOSPITAL NACIONAL PNP LUIS N. SAENZ (00013591, nivel III).
--   - Diagnósticos: receta_diagnosticos activos, sin repetir CIE10 por
--     prestación (P = presuntivo, D = definitivo, R = repetitivo).
--
-- Salidas:
--   1. ATENCIONES: 1 fila por prestación, con diagnósticos concatenados.
--   2. PROCEDIMIENTOS REALIZADOS por el profesional, 1 fila por procedimiento
--      activo de esas prestaciones (prestacion_procedimientos). SIGESAPOL no
--      tiene un rol de "quien realiza", así que se toma:
--        - registrado por el propio profesional (created_us → users.dni), y
--        - que no sea laboratorio (tipo_procedimiento = 2): esos exámenes
--          solo los solicita; los realiza el laboratorio.
--      Se excluye lo que cargó enfermería u otro usuario dentro de su
--      prestación (99205, curaciones, infusiones...). Mismo criterio que SEIS
--      (PROC = realiza; RESP = solicita).
--   3. RESUMEN mensual.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. ATENCIONES
-- -----------------------------------------------------------------------------
WITH par AS (
    SELECT '00000000'::text AS dni,   -- <-- DNI del profesional
           DATE '2026-06-01' AS desde,
           DATE '2026-11-01' AS hasta       -- exclusivo (hasta el 31/10/2026)
),
prest AS (
    SELECT p.*
    FROM prestaciones p
    CROSS JOIN par
    INNER JOIN medicos m        ON m.id = p.id_medico AND m.dni = par.dni
    INNER JOIN establecimientos e ON e.id = p.id_establecimiento
    WHERE p.fecha_atencion >= par.desde
      AND p.fecha_atencion <  par.hasta
      AND p.id_estado_reg = 1
      AND e.codigo <> '00013591'  -- EXCLUIR HOSPITAL NACIONAL PNP LUIS N. SAENZ (nivel III)
),
dx AS (
    SELECT x.id_prestacion,
           string_agg(x.codigo || ' - ' || x.nombre || ' (' || x.tipo || ')', ' | '
                      ORDER BY x.primer_registro) AS diagnosticos
    FROM (
        SELECT rd.id_prestacion, d.codigo, d.nombre,
               CASE MAX(CASE rd.id_tipo_diagnostico WHEN 2 THEN 3 WHEN 3 THEN 2 WHEN 1 THEN 1 END)
                    WHEN 3 THEN 'D' WHEN 2 THEN 'R' WHEN 1 THEN 'P' ELSE '?' END AS tipo,
               MIN(rd.id) AS primer_registro
        FROM prest p
        INNER JOIN receta_diagnosticos rd ON rd.id_prestacion = p.id
        INNER JOIN diagnosticos d         ON d.id = rd.id_diagnostico
        WHERE rd.estado = 1
        GROUP BY rd.id_prestacion, d.codigo, d.nombre
    ) x
    GROUP BY x.id_prestacion
),
ups AS (
    SELECT DISTINCT ON (codigo) codigo, descripcion_upss
    FROM upsses
    ORDER BY codigo, updated_at DESC
)
SELECT
    'SIGESAPOL'                                     AS "SISTEMA",
    p.id                                            AS "ID_ATENCION",
    to_char(p.fecha_atencion, 'YYYYMM')             AS "PERIODO",
    p.fecha_atencion::date                          AS "FECHA_ATENCION",
    p.id_tipo_atencion                              AS "ID_TIPO_ATENCION",
    ta.nombre                                       AS "TIPO_ATENCION",
    'MEDICO DE LA PRESTACION'                       AS "ROL_PROFESIONAL",
    e.codigo                                        AS "CODIGO_IPRESS",
    e.nombre                                        AS "IPRESS",
    p.codigo_upss                                   AS "CODIGO_UPS",
    u.descripcion_upss                              AS "UPS",
    a.nro_doc_ident                                 AS "DNI_PACIENTE",
    a.paterno || ' ' || a.materno || ', ' || a.nombre AS "PACIENTE",
    a.sexo                                          AS "SEXO",
    CASE WHEN a.fecha_nac ~ '^\d{2}/\d{2}/\d{4}$'
         THEN date_part('year', age(p.fecha_atencion::date, to_date(a.fecha_nac, 'DD/MM/YYYY')))::int
    END                                             AS "EDAD",
    dx.diagnosticos                                 AS "DIAGNOSTICOS"
FROM prest p
INNER JOIN establecimientos e ON e.id = p.id_establecimiento
LEFT JOIN tipo_atenciones ta  ON ta.id = p.id_tipo_atencion
LEFT JOIN asegurados a        ON a.id = p.id_asegurado
LEFT JOIN ups u               ON u.codigo = p.codigo_upss
LEFT JOIN dx                  ON dx.id_prestacion = p.id
ORDER BY p.fecha_atencion, p.id;

-- -----------------------------------------------------------------------------
-- 2. PROCEDIMIENTOS
-- -----------------------------------------------------------------------------
WITH par AS (
    SELECT '00000000'::text AS dni,   -- <-- DNI del profesional
           DATE '2026-06-01' AS desde,
           DATE '2026-11-01' AS hasta
),
prest AS (
    SELECT p.*
    FROM prestaciones p
    CROSS JOIN par
    INNER JOIN medicos m        ON m.id = p.id_medico AND m.dni = par.dni
    INNER JOIN establecimientos e ON e.id = p.id_establecimiento
    WHERE p.fecha_atencion >= par.desde
      AND p.fecha_atencion <  par.hasta
      AND p.id_estado_reg = 1
      AND e.codigo <> '00013591'  -- EXCLUIR HOSPITAL NACIONAL PNP LUIS N. SAENZ (nivel III)
),
ups AS (
    SELECT DISTINCT ON (codigo) codigo, descripcion_upss
    FROM upsses
    ORDER BY codigo, updated_at DESC
)
SELECT
    'SIGESAPOL'                                     AS "SISTEMA",
    p.id                                            AS "ID_ATENCION",
    to_char(p.fecha_atencion, 'YYYYMM')             AS "PERIODO",
    p.fecha_atencion::date                          AS "FECHA_ATENCION",
    ta.nombre                                       AS "TIPO_ATENCION",
    e.codigo                                        AS "CODIGO_IPRESS",
    e.nombre                                        AS "IPRESS",
    p.codigo_upss                                   AS "CODIGO_UPS",
    u.descripcion_upss                              AS "UPS",
    a.nro_doc_ident                                 AS "DNI_PACIENTE",
    a.paterno || ' ' || a.materno || ', ' || a.nombre AS "PACIENTE",
    CASE pp.tipo_procedimiento WHEN 1 THEN 'PROCEDIMIENTO'
                               WHEN 2 THEN 'LABORATORIO'
                               ELSE pp.tipo_procedimiento::text END AS "TIPO_PROCEDIMIENTO",
    pr.codigo                                       AS "CODIGO_PROCEDIMIENTO",
    pr.descripcion                                  AS "PROCEDIMIENTO",
    pp.cantidad                                     AS "CANTIDAD",
    us.dni                                          AS "DNI_REGISTRADO_POR",
    trim(us.name || ' ' || coalesce(us.paterno, '') || ' ' || coalesce(us.materno, '')) AS "REGISTRADO_POR",
    CASE WHEN us.dni = par.dni THEN 'SI' ELSE 'NO' END AS "REGISTRADO_POR_PROFESIONAL"
FROM prest p
CROSS JOIN par
INNER JOIN prestacion_procedimientos pp ON pp.id_prestacion = p.id AND pp.id_estado_reg = 1
INNER JOIN procedimientos pr  ON pr.id = pp.id_procedimiento
INNER JOIN establecimientos e ON e.id = p.id_establecimiento
LEFT JOIN tipo_atenciones ta  ON ta.id = p.id_tipo_atencion
LEFT JOIN asegurados a        ON a.id = p.id_asegurado
LEFT JOIN users us            ON us.id::text = pp.created_us
LEFT JOIN ups u               ON u.codigo = p.codigo_upss
WHERE us.dni = par.dni                                -- lo registró el profesional
  AND pp.tipo_procedimiento IS DISTINCT FROM 2       -- no laboratorio (solo lo solicita)
ORDER BY p.fecha_atencion, p.id, pp.id;

-- -----------------------------------------------------------------------------
-- 3. RESUMEN MENSUAL
-- -----------------------------------------------------------------------------
WITH par AS (
    SELECT '00000000'::text AS dni,   -- <-- DNI del profesional
           DATE '2026-06-01' AS desde,
           DATE '2026-11-01' AS hasta
),
prest AS (
    SELECT p.*
    FROM prestaciones p
    CROSS JOIN par
    INNER JOIN medicos m        ON m.id = p.id_medico AND m.dni = par.dni
    INNER JOIN establecimientos e ON e.id = p.id_establecimiento
    WHERE p.fecha_atencion >= par.desde
      AND p.fecha_atencion <  par.hasta
      AND p.id_estado_reg = 1
      AND e.codigo <> '00013591'  -- EXCLUIR HOSPITAL NACIONAL PNP LUIS N. SAENZ (nivel III)
),
proc AS (
    -- solo procedimientos realizados (ver salida 2)
    SELECT pp.id_prestacion,
           SUM(pp.cantidad)                           AS n_proc
    FROM prest p
    CROSS JOIN par
    INNER JOIN prestacion_procedimientos pp ON pp.id_prestacion = p.id AND pp.id_estado_reg = 1
    INNER JOIN users us ON us.id::text = pp.created_us AND us.dni = par.dni
    WHERE pp.tipo_procedimiento IS DISTINCT FROM 2
    GROUP BY pp.id_prestacion
)
SELECT
    to_char(p.fecha_atencion, 'YYYYMM')             AS "PERIODO",
    ta.nombre                                       AS "TIPO_ATENCION",
    COUNT(*)                                        AS "ATENCIONES",
    COUNT(DISTINCT p.id_asegurado)                  AS "ATENDIDOS",
    COALESCE(SUM(pc.n_proc), 0)                     AS "PROCEDIMIENTOS_REALIZADOS"
FROM prest p
LEFT JOIN tipo_atenciones ta ON ta.id = p.id_tipo_atencion
LEFT JOIN proc pc            ON pc.id_prestacion = p.id
GROUP BY 1, 2
ORDER BY 1, 2;
