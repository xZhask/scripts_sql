-- =============================================================================
-- SIGESAPOL · POSIBLES DUPLICADOS EN EL REGISTRO DE INTERVENCIONES QUIRÚRGICAS
-- Base: sigesapol_setiembre (PostgreSQL 18, puerto 5433). Funciona igual en
-- producción (DBeaver): cambiar solo las fechas del CTE "param".
--
-- Motivo: el reporte de intervenciones del aplicativo no trae la fecha de la
-- cirugía, así que un paciente repetido no se puede comparar. Esta consulta
-- recupera la fecha y marca los pares sospechosos.
--
-- ID_ATENCION_QX = cqx_atenciones.id = "id_atencion" del reporte del aplicativo.
-- Salida: 1 fila por acto quirúrgico sospechoso, con el documento del paciente
-- para buscarlo. CONTIENE DATOS DE PACIENTES: exportar solo como
-- extraccion_*.csv (no se versiona).
--
-- Alcance: actos activos (cqx_atenciones.id_estado_reg = 1) de solicitudes no
-- anuladas (cqx_intervenciones.id_estado_reg <> 0), registrados en el rango,
-- sin el H.N. Luis N. Sáenz (id 76). Los pares se buscan contra todo el
-- histórico, para no perder el duplicado registrado el mes anterior.
--
-- FECHA_QX: hora de inicio del acto quirúrgico; si no se registró (la mayoría
-- antes de 2026), fecha de la intervención; si tampoco, fecha de registro.
--
-- Reglas:
--   Q1 ERROR   Una misma solicitud de intervención con 2+ actos quirúrgicos.
--   Q2 ERROR   Mismo paciente, solicitudes distintas, actos con horario
--              superpuesto (no puede estar en dos cirugías a la vez).
--   Q3 REVISAR Mismo paciente e IPRESS, solicitudes distintas, FECHA_QX con
--              1 día o menos de diferencia y al menos un CPT en común. Puede
--              ser reintervención: confirmar en el aplicativo.
--   CPT: procedimientos de la prestación del acto (prestacion_procedimientos)
--   y, si no tiene, los de la solicitud (cqx_procedimientos).
-- =============================================================================

WITH param AS (
    SELECT TIMESTAMP '2026-09-01' AS ini,
           TIMESTAMP '2026-10-01' AS fin       -- exclusivo
),
acto AS MATERIALIZED (
    SELECT a.id, a.id_cqx_intervencion, a.id_prestacion, a.id_hospitalizacion,
           i.id_asegurado, i.id_establecimiento, a.created_at,
           a.hora_inicio_acto_qx AS ini_acto, a.hora_fin_acto_qx AS fin_acto, a.horas_efectivas,
           COALESCE(a.hora_inicio_acto_qx, i.fecha_intervencion, a.created_at) AS fecha_qx,
           COALESCE(
               (SELECT array_agg(DISTINCT pc.codigo) FROM prestacion_procedimientos pp
                  JOIN procedimientos pc ON pc.id = pp.id_procedimiento
                 WHERE pp.id_prestacion = a.id_prestacion AND pp.id_estado_reg = 1),
               (SELECT array_agg(DISTINCT pc.codigo) FROM cqx_procedimientos cp
                  JOIN procedimientos pc ON pc.id = cp.id_procedimiento
                 WHERE cp.id_cqx_intervenciones = i.id AND cp.id_estado_reg = 1)
           ) AS cpts
    FROM cqx_atenciones a
    JOIN cqx_intervenciones i ON i.id = a.id_cqx_intervencion
    WHERE a.id_estado_reg = 1
      AND i.id_estado_reg <> 0
      AND i.id_establecimiento <> 76
),
pares (regla, id1, id2, detalle) AS (
    -- Q1 misma solicitud con varios actos
    SELECT 'Q1', a1.id, a2.id, 'Misma solicitud ' || a1.id_cqx_intervencion || ' con más de un acto quirúrgico'
    FROM acto a1
    JOIN acto a2 ON a2.id_cqx_intervencion = a1.id_cqx_intervencion AND a2.id > a1.id

    UNION ALL
    -- Q2 horario superpuesto
    SELECT 'Q2', a1.id, a2.id, 'Actos superpuestos: ' || to_char(a1.ini_acto, 'DD/MM HH24:MI') || '-' || to_char(a1.fin_acto, 'HH24:MI')
               || ' y ' || to_char(a2.ini_acto, 'DD/MM HH24:MI') || '-' || to_char(a2.fin_acto, 'HH24:MI')
    FROM acto a1
    JOIN acto a2 ON a2.id_asegurado = a1.id_asegurado AND a2.id > a1.id
                AND a2.id_cqx_intervencion <> a1.id_cqx_intervencion
                AND a1.ini_acto < a2.fin_acto AND a2.ini_acto < a1.fin_acto

    UNION ALL
    -- Q3 misma fecha (±1 día) y CPT en común
    SELECT 'Q3', a1.id, a2.id, 'Fechas ' || to_char(a1.fecha_qx, 'DD/MM/YYYY') || ' y ' || to_char(a2.fecha_qx, 'DD/MM/YYYY')
               || '; CPT en común: ' || array_to_string(ARRAY(SELECT unnest(a1.cpts) INTERSECT SELECT unnest(a2.cpts) ORDER BY 1), ', ')
    FROM acto a1
    JOIN acto a2 ON a2.id_asegurado = a1.id_asegurado AND a2.id > a1.id
                AND a2.id_establecimiento = a1.id_establecimiento
                AND a2.id_cqx_intervencion <> a1.id_cqx_intervencion
                AND abs(a2.fecha_qx::date - a1.fecha_qx::date) <= 1
                AND a1.cpts && a2.cpts
    WHERE NOT (a1.ini_acto < a2.fin_acto AND a2.ini_acto < a1.fin_acto)   -- ya es Q2
       OR a1.ini_acto IS NULL OR a2.ini_acto IS NULL
),
-- Una regla por par (la más grave) y solo pares con algún acto en el rango
par AS (
    SELECT DISTINCT ON (p.id1, p.id2) p.*
    FROM pares p, param, acto a1, acto a2
    WHERE a1.id = p.id1 AND a2.id = p.id2
      AND (a1.created_at >= param.ini AND a1.created_at < param.fin
        OR a2.created_at >= param.ini AND a2.created_at < param.fin)
    ORDER BY p.id1, p.id2, p.regla
),
fila AS (
    SELECT regla, id1 AS id, id2 AS id_otro, detalle FROM par
    UNION ALL
    SELECT regla, id2, id1, detalle FROM par
)
SELECT
    CASE WHEN f.regla = 'Q3' THEN 'REVISAR' ELSE 'ERROR' END AS "SEVERIDAD",
    f.regla                                         AS "REGLA",
    CASE f.regla WHEN 'Q1' THEN 'SOLICITUD CON MAS DE UN ACTO QUIRURGICO'
                 WHEN 'Q2' THEN 'ACTOS QUIRURGICOS SUPERPUESTOS'
                 ELSE 'POSIBLE INTERVENCION DUPLICADA' END AS "INCONSISTENCIA",
    f.detalle                                       AS "DETALLE",
    a.id                                            AS "ID_ATENCION_QX",
    f.id_otro                                       AS "ID_ATENCION_QX_RELACIONADA",
    a.id_cqx_intervencion                           AS "ID_INTERVENCION",
    a.id_prestacion                                 AS "ID_PRESTACION",
    a.id_hospitalizacion                            AS "ID_HOSPITALIZACION",
    s.tipo_doc_ident                                AS "TIPO_DOC_PACIENTE",
    s.nro_doc_ident                                 AS "NRO_DOC_PACIENTE",
    e.codigo                                        AS "CODIGO_IPRESS",
    e.nombre                                        AS "IPRESS",
    to_char(a.fecha_qx, 'YYYY-MM-DD')               AS "FECHA_QX",
    to_char(a.ini_acto, 'YYYY-MM-DD HH24:MI')       AS "INICIO_ACTO",
    to_char(a.fin_acto, 'YYYY-MM-DD HH24:MI')       AS "FIN_ACTO",
    a.horas_efectivas                               AS "HORAS_EFECTIVAS",
    array_to_string(a.cpts, ', ')                   AS "CPT",
    date_trunc('second', a.created_at)              AS "REGISTRADO_EL"
FROM fila f
JOIN acto a                  ON a.id = f.id
LEFT JOIN asegurados s       ON s.id = a.id_asegurado
LEFT JOIN establecimientos e ON e.id = a.id_establecimiento
ORDER BY "SEVERIDAD", f.regla, s.nro_doc_ident, a.fecha_qx, a.id;
