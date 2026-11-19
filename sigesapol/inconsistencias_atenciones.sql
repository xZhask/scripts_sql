-- =============================================================================
-- SIGESAPOL · RECOPILACIÓN DE INCONSISTENCIAS DE REGISTRO EN ATENCIONES
-- Base: sigesapol_setiembre (PostgreSQL 18, puerto 5433). Funciona igual en
-- producción (DBeaver): cambiar solo las fechas del CTE "param".
--
-- Salida: 1 fila por inconsistencia, con el ID de la atención para cotejarla
-- en el aplicativo, con el documento del paciente para buscarlo (sin nombre).
-- CONTIENE DATOS DE PACIENTES: exportar solo como extraccion_*.csv (no se versiona).
--   SEVERIDAD = ERROR   -> el dato no puede ser correcto.
--               REVISAR -> probablemente incorrecto; confirmar en el aplicativo.
--
-- Alcance: prestaciones activas (id_estado_reg = 1) con fecha de atención en
-- el rango, todos los tipos de atención, sin el H.N. Luis N. Sáenz (id 76).
-- Emergencias: por fecha_registro_ingreso, sin anuladas (estado = 0).
--
-- Reglas:
--   PROCEDIMIENTOS (prestacion_procedimientos activos)
--   P1 ERROR   Cantidad negativa.
--   P2 ERROR   Cantidad cero.
--   P6 ERROR   Cantidad mayor a 1 en atención ambulatoria. En consulta
--              ambulatoria cada procedimiento se registra con cantidad 1 (la
--              cantidad es de procedimientos, no de insumos entregados: los
--              preservativos e inyectables también van con 1). Excepciones,
--              donde la cantidad es por pieza, superficie o incidencia:
--                odontología (CPMS que empiezan con D o E)
--                imágenes    (CPMS que empiezan con 7)
--   P7 REVISAR Hospitalización y emergencia: la suma de un mismo procedimiento
--              en la atención es mayor que los días calendario de estancia
--              (ingreso y alta incluidos; sin alta, hasta el fin del periodo).
--              En estos tipos se registran procedimientos durante toda la
--              estancia, por eso se comparan con los días y no con 1.
--              ERROR si es 99231* (atención paciente-día: uno por día).
--   P3 REVISAR Cantidad atípica en lo que P6 y P7 no cubren (urgencia y las
--              excepciones de P6): mayor que el percentil 99 del mismo CPMS
--              en el periodo (CPMS con 30+ registros) o >= 10 (con menos).
--   P4 REVISAR Mismo procedimiento registrado más de una vez en la atención
--              (ambulatorio y urgencia; en HO y EM lo cubre P7).
--   P5 ERROR   Procedimiento exclusivo de un sexo en paciente del otro
--              (procedimientos.genero: 1 masculino, 2 femenino, 3 ambos).
--   DIAGNÓSTICOS (receta_diagnosticos activos)
--   D1 ERROR   Diagnóstico exclusivo de un sexo en paciente del otro.
--   ATENCIÓN
--   A1 ERROR   Fecha de atención más de 1 día posterior a su registro
--              (created_at); suele ser el año mal digitado (ej. 202650).
--              Se busca por created_at dentro del rango.
--   A2 ERROR   Dos o más atenciones activas para la misma cita.
--   A3 REVISAR Posible duplicado: mismo paciente, día, IPRESS, profesional y
--              tipo de atención, con citas distintas o sin cita.
--   A4 ERROR   Signo vital fuera de rango. El 0 NO se marca: en ambulatorio es
--              lo habitual cuando no se tomó (más del 80% de las atenciones).
--              Rangos: temperatura 34-42 °C, peso 0.5-250 kg, talla 30-230 cm,
--              SatO2 50-100 %, FC 30-220, FR 5-60, PAS 60-250, PAD 30-150,
--              y PAD menor que PAS.
--   EMERGENCIAS
--   E1 ERROR   Alta médica anterior al registro del ingreso.
--   E2 REVISAR Atención médica registrada más de 30 min antes que el ingreso.
--   E3 REVISAR Estancia en emergencia mayor a 7 días.
--   La hora del alta está en hora_alta_medica cuando fecha_alta_medica viene
--   a las 00:00; se combinan antes de comparar.
--
-- No son inconsistencias (no se reportan):
--   - prestaciones.periodo guarda la unidad del tiempo de enfermedad (DIAS,
--     HORAS...), no el periodo YYYYMM.
--   - Atenciones solo con diagnóstico presuntivo: válido en ambulatorio.
-- =============================================================================

WITH param AS (
    SELECT TIMESTAMP '2026-09-01' AS ini,
           TIMESTAMP '2026-10-01' AS fin       -- exclusivo
),
pr AS MATERIALIZED (
    SELECT p.*
    FROM prestaciones p, param
    WHERE p.fecha_atencion >= param.ini AND p.fecha_atencion < param.fin
      AND p.id_estado_reg = 1
      AND p.id_establecimiento <> 76
),
-- Estancia de hospitalización (prestaciones.id_ext -> hospitalizaciones.id) y de
-- emergencia (prestaciones.id_ext -> emergencias.id), en días calendario
-- contando el de ingreso y el de alta. Sin alta: hasta el fin del periodo.
estancia AS MATERIALIZED (
    SELECT x.id_prestacion, x.ingreso, x.sin_alta,
           greatest(coalesce(x.alta, (param.fin - INTERVAL '1 day')::date), x.ingreso) AS alta,
           greatest(coalesce(x.alta, (param.fin - INTERVAL '1 day')::date), x.ingreso) - x.ingreso + 1 AS dias
    FROM (
        SELECT pr.id AS id_prestacion,
               coalesce(h.fecha_ingreso, e.fecha_registro_ingreso)::date AS ingreso,
               (CASE WHEN pr.id_tipo_atencion = 3 THEN coalesce(h.fecha_alta_medica, h.fecha_salida)
                     ELSE e.fecha_alta_medica END)::date AS alta,
               (CASE WHEN pr.id_tipo_atencion = 3 THEN coalesce(h.fecha_alta_medica, h.fecha_salida)
                     ELSE e.fecha_alta_medica END) IS NULL AS sin_alta
        FROM pr
        LEFT JOIN hospitalizaciones h ON pr.id_tipo_atencion = 3 AND h.id = pr.id_ext
        LEFT JOIN emergencias e       ON pr.id_tipo_atencion = 2 AND e.id = pr.id_ext
        WHERE pr.id_tipo_atencion IN (2, 3)
    ) x, param
    WHERE x.ingreso IS NOT NULL
),
pp AS MATERIALIZED (
    SELECT pp.id, pp.id_prestacion, pp.id_procedimiento, pp.cantidad,
           pc.codigo AS cpms, pc.descripcion, pc.genero,
           -- P6: ambulatorio, salvo odontología (D/E) e imágenes (7)
           (pr.id_tipo_atencion = 1 AND coalesce(pc.codigo, '') !~ '^[DE7]') AS unitario,
           -- P7: hospitalización y emergencia con estancia conocida
           (es.id_prestacion IS NOT NULL) AS por_estancia
    FROM prestacion_procedimientos pp
    JOIN pr ON pr.id = pp.id_prestacion
    LEFT JOIN procedimientos pc ON pc.id = pp.id_procedimiento
    LEFT JOIN estancia es ON es.id_prestacion = pp.id_prestacion
    WHERE pp.id_estado_reg = 1
),
umbral AS (
    SELECT cpms,
           CASE WHEN count(*) >= 30
                THEN greatest(percentile_disc(0.99) WITHIN GROUP (ORDER BY cantidad), 1)
                ELSE 9 END AS maximo_habitual
    FROM pp
    WHERE cantidad > 0 AND NOT unitario AND NOT por_estancia
    GROUP BY cpms
),
em AS MATERIALIZED (
    SELECT em.id, em.id_establecimiento, em.fecha_registro_ingreso AS ingreso, em.fecha_atencion AS atencion,
           CASE WHEN em.fecha_alta_medica::time = '00:00' AND em.hora_alta_medica IS NOT NULL
                THEN em.fecha_alta_medica::date + em.hora_alta_medica::time
                ELSE em.fecha_alta_medica END AS alta
    FROM emergencias em, param
    WHERE em.fecha_registro_ingreso >= param.ini AND em.fecha_registro_ingreso < param.fin
      AND em.id_establecimiento <> 76
      AND em.estado <> 0
),
hallazgos (severidad, regla, inconsistencia, id_atencion, id_emergencia, id_pp, cpms, procedimiento, cantidad, detalle, id_relacionado) AS (

    -- P1 / P2 / P6 / P3 cantidades
    SELECT CASE WHEN pp.cantidad <= 0 OR pp.unitario THEN 'ERROR' ELSE 'REVISAR' END,
           CASE WHEN pp.cantidad < 0 THEN 'P1' WHEN pp.cantidad = 0 THEN 'P2'
                WHEN pp.unitario THEN 'P6' ELSE 'P3' END,
           CASE WHEN pp.cantidad < 0 THEN 'CANTIDAD NEGATIVA'
                WHEN pp.cantidad = 0 THEN 'CANTIDAD CERO'
                WHEN pp.unitario THEN 'CANTIDAD MAYOR A 1 EN ATENCION AMBULATORIA'
                ELSE 'CANTIDAD ATIPICA' END,
           pp.id_prestacion, NULL::int, pp.id, pp.cpms, pp.descripcion, pp.cantidad,
           CASE WHEN pp.cantidad > 0 AND pp.unitario
                THEN 'Cantidad ' || pp.cantidad || '; en ambulatorio debe ser 1 (salvo odontología e imágenes)'
                WHEN pp.cantidad > 0
                THEN 'Cantidad ' || pp.cantidad || '; lo habitual para este CPMS es hasta ' || u.maximo_habitual END,
           NULL
    FROM pp
    LEFT JOIN umbral u ON u.cpms = pp.cpms
    WHERE pp.cantidad <= 0
       OR (pp.unitario AND pp.cantidad > 1)
       OR (NOT pp.unitario AND NOT pp.por_estancia AND pp.cantidad > u.maximo_habitual)

    UNION ALL
    -- P4 procedimiento repetido (ambulatorio y urgencia; HO y EM van en P7)
    SELECT 'REVISAR', 'P4', 'PROCEDIMIENTO REPETIDO EN LA ATENCION',
           pp.id_prestacion, NULL, min(pp.id), pp.cpms, pp.descripcion, sum(pp.cantidad),
           'Registrado ' || count(*) || ' veces (cantidades: ' || string_agg(pp.cantidad::text, ', ' ORDER BY pp.id) || ')',
           string_agg(pp.id::text, ', ' ORDER BY pp.id)
    FROM pp
    WHERE NOT pp.por_estancia
    GROUP BY pp.id_prestacion, pp.id_procedimiento, pp.cpms, pp.descripcion
    HAVING count(*) > 1

    UNION ALL
    -- P7 hospitalización y emergencia: total del procedimiento vs días de estancia
    SELECT CASE WHEN pp.cpms LIKE '99231%' THEN 'ERROR' ELSE 'REVISAR' END,
           'P7', 'CANTIDAD MAYOR A LOS DIAS DE ESTANCIA',
           pp.id_prestacion, NULL, min(pp.id), pp.cpms, pp.descripcion, sum(pp.cantidad),
           'Total ' || sum(pp.cantidad) || ' en ' || es.dias || ' día(s) de estancia ('
               || to_char(es.ingreso, 'DD/MM/YYYY') || ' al ' || to_char(es.alta, 'DD/MM/YYYY')
               || CASE WHEN es.sin_alta THEN ', sin alta: contado hasta fin del periodo' ELSE '' END
               || '); ' || count(*) || ' registro(s)',
           string_agg(pp.id::text, ', ' ORDER BY pp.id)
    FROM pp
    JOIN estancia es ON es.id_prestacion = pp.id_prestacion
    WHERE pp.cantidad > 0
    GROUP BY pp.id_prestacion, pp.id_procedimiento, pp.cpms, pp.descripcion, es.dias, es.ingreso, es.alta, es.sin_alta
    HAVING sum(pp.cantidad) > es.dias

    UNION ALL
    -- P5 procedimiento y sexo
    SELECT 'ERROR', 'P5', 'PROCEDIMIENTO NO CORRESPONDE AL SEXO',
           pp.id_prestacion, NULL, pp.id, pp.cpms, pp.descripcion, pp.cantidad,
           'Procedimiento ' || CASE pp.genero WHEN 1 THEN 'masculino' ELSE 'femenino' END || ' en paciente sexo ' || a.sexo,
           NULL
    FROM pp
    JOIN pr ON pr.id = pp.id_prestacion
    JOIN asegurados a ON a.id = pr.id_asegurado
    WHERE (pp.genero = 1 AND a.sexo = 'F') OR (pp.genero = 2 AND a.sexo = 'M')

    UNION ALL
    -- D1 diagnóstico y sexo
    SELECT 'ERROR', 'D1', 'DIAGNOSTICO NO CORRESPONDE AL SEXO',
           pr.id, NULL, NULL, d.codigo, d.nombre, NULL,
           'CIE10 ' || CASE d.genero WHEN 1 THEN 'masculino' ELSE 'femenino' END || ' en paciente sexo ' || a.sexo,
           NULL
    FROM pr
    JOIN receta_diagnosticos rd ON rd.id_prestacion = pr.id AND rd.estado = 1
    JOIN diagnosticos d ON d.id = rd.id_diagnostico
    JOIN asegurados a ON a.id = pr.id_asegurado
    WHERE (d.genero = 1 AND a.sexo = 'F') OR (d.genero = 2 AND a.sexo = 'M')

    UNION ALL
    -- A1 fecha de atención posterior a su registro (por created_at, no por fecha_atencion)
    SELECT 'ERROR', 'A1', 'FECHA DE ATENCION POSTERIOR A SU REGISTRO',
           p.id, NULL, NULL, NULL, NULL, NULL,
           'Fecha de atención ' || p.fecha_atencion || '; registrada el ' || date_trunc('second', p.created_at),
           NULL
    FROM prestaciones p, param
    WHERE p.created_at >= param.ini AND p.created_at < param.fin
      AND p.id_estado_reg = 1
      AND p.id_establecimiento <> 76
      AND p.fecha_atencion > p.created_at + interval '1 day'

    UNION ALL
    -- A2 varias atenciones para una cita
    SELECT 'ERROR', 'A2', 'VARIAS ATENCIONES PARA UNA MISMA CITA',
           pr.id, NULL, NULL, NULL, NULL, NULL,
           'Cita ' || pr.id_cita || ' con ' || count(*) OVER (PARTITION BY pr.id_cita) || ' atenciones activas',
           string_agg(pr.id::text, ', ') OVER (PARTITION BY pr.id_cita)
    FROM pr
    WHERE pr.id_cita IN (SELECT id_cita FROM pr WHERE id_cita IS NOT NULL GROUP BY id_cita HAVING count(*) > 1)

    UNION ALL
    -- A3 posible duplicado
    SELECT 'REVISAR', 'A3', 'POSIBLE ATENCION DUPLICADA',
           x.id, NULL, NULL, NULL, NULL, NULL,
           x.n || ' atenciones el mismo día, mismo paciente, IPRESS, profesional y tipo',
           x.ids
    FROM (
        SELECT pr.id,
               count(*) OVER w AS n,
               count(pr.id_cita) OVER w AS con_cita,
               min(pr.id_cita) OVER w AS cita_min,
               max(pr.id_cita) OVER w AS cita_max,
               string_agg(pr.id::text, ', ') OVER w AS ids
        FROM pr
        WINDOW w AS (PARTITION BY pr.id_asegurado, pr.fecha_atencion::date, pr.id_establecimiento, pr.id_medico, pr.id_tipo_atencion)
    ) x
    WHERE x.n > 1
      -- si todas comparten la misma cita ya salen en A2
      AND NOT (x.con_cita = x.n AND x.cita_min = x.cita_max)

    UNION ALL
    -- A4 signos vitales
    SELECT 'ERROR', 'A4', 'SIGNO VITAL FUERA DE RANGO',
           v.id, NULL, NULL, NULL, NULL, NULL, v.detalle, NULL
    FROM (
        SELECT pr.id, unnest(array_remove(ARRAY[
            CASE WHEN pr.temperatura <> 0 AND (pr.temperatura < 34 OR pr.temperatura > 42) THEN 'Temperatura ' || pr.temperatura END,
            CASE WHEN pr.peso_kg <> 0 AND (pr.peso_kg < 0.5 OR pr.peso_kg > 250) THEN 'Peso ' || pr.peso_kg || ' kg' END,
            CASE WHEN pr.talla_cm <> 0 AND (pr.talla_cm < 30 OR pr.talla_cm > 230) THEN 'Talla ' || pr.talla_cm || ' cm' END,
            CASE WHEN pr.sa02_porcentaje <> 0 AND (pr.sa02_porcentaje < 50 OR pr.sa02_porcentaje > 100) THEN 'SatO2 ' || pr.sa02_porcentaje || ' %' END,
            CASE WHEN pr.frecuencia_cardiaca <> 0 AND (pr.frecuencia_cardiaca < 30 OR pr.frecuencia_cardiaca > 220) THEN 'FC ' || pr.frecuencia_cardiaca END,
            CASE WHEN pr.frecuencia_respiratoria <> 0 AND (pr.frecuencia_respiratoria < 5 OR pr.frecuencia_respiratoria > 60) THEN 'FR ' || pr.frecuencia_respiratoria END,
            CASE WHEN pr.presion_arterial_x <> 0 AND (pr.presion_arterial_x < 60 OR pr.presion_arterial_x > 250) THEN 'PA sistólica ' || pr.presion_arterial_x END,
            CASE WHEN pr.presion_arterial_y <> 0 AND (pr.presion_arterial_y < 30 OR pr.presion_arterial_y > 150) THEN 'PA diastólica ' || pr.presion_arterial_y END,
            CASE WHEN pr.presion_arterial_x <> 0 AND pr.presion_arterial_y >= pr.presion_arterial_x THEN 'PA ' || pr.presion_arterial_x || '/' || pr.presion_arterial_y || ' (diastólica >= sistólica)' END
        ], NULL)) AS detalle
        FROM pr
    ) v

    UNION ALL
    -- E1 / E2 / E3 emergencias
    SELECT CASE WHEN e.alta < e.ingreso THEN 'ERROR' ELSE 'REVISAR' END,
           CASE WHEN e.alta < e.ingreso THEN 'E1' WHEN e.atencion < e.ingreso - interval '30 min' THEN 'E2' ELSE 'E3' END,
           CASE WHEN e.alta < e.ingreso THEN 'ALTA ANTERIOR AL INGRESO'
                WHEN e.atencion < e.ingreso - interval '30 min' THEN 'ATENCION ANTERIOR AL REGISTRO DE INGRESO'
                ELSE 'ESTANCIA EN EMERGENCIA MAYOR A 7 DIAS' END,
           p.id, e.id, NULL, NULL, NULL, NULL,
           'Ingreso ' || date_trunc('second', e.ingreso) || '; atención ' || COALESCE(date_trunc('second', e.atencion)::text, '-')
               || '; alta ' || COALESCE(date_trunc('second', e.alta)::text, '-'),
           NULL
    FROM em e
    LEFT JOIN prestaciones p ON p.id_tipo_atencion = 2 AND p.id_ext = e.id AND p.id_estado_reg = 1
    WHERE e.alta < e.ingreso
       OR e.atencion < e.ingreso - interval '30 min'
       OR e.alta > e.ingreso + interval '7 days'
)
SELECT
    h.severidad                                     AS "SEVERIDAD",
    h.regla                                         AS "REGLA",
    h.inconsistencia                                AS "INCONSISTENCIA",
    h.detalle                                       AS "DETALLE",
    h.id_atencion                                   AS "ID_ATENCION",
    a.tipo_doc_ident                                AS "TIPO_DOC_PACIENTE",
    a.nro_doc_ident                                 AS "NRO_DOC_PACIENTE",
    h.id_emergencia                                 AS "ID_EMERGENCIA",
    h.id_pp                                         AS "ID_PRESTACION_PROCEDIMIENTO",
    h.id_relacionado                                AS "IDS_RELACIONADOS",
    p.fecha_atencion::date                          AS "FECHA_ATENCION",
    ta.nombre                                       AS "TIPO_ATENCION",
    e.codigo                                        AS "CODIGO_IPRESS",
    e.nombre                                        AS "IPRESS",
    co.nombre                                       AS "CONSULTORIO",
    h.cpms                                          AS "CODIGO",
    regexp_replace(h.procedimiento, E'[\\r\\n\\t]+', ' ', 'g') AS "DESCRIPCION",
    h.cantidad                                      AS "CANTIDAD",
    TRIM(CONCAT_WS(' ', m.paterno, m.materno, m.nombre)) AS "PROFESIONAL",
    date_trunc('second', p.created_at)              AS "REGISTRADO_EL"
FROM hallazgos h
LEFT JOIN prestaciones p      ON p.id = h.id_atencion
LEFT JOIN emergencias emx     ON emx.id = h.id_emergencia
LEFT JOIN asegurados a         ON a.id = COALESCE(p.id_asegurado, emx.id_asegurado)
LEFT JOIN establecimientos e  ON e.id = COALESCE(p.id_establecimiento, emx.id_establecimiento)
LEFT JOIN tipo_atenciones ta  ON ta.id = COALESCE(p.id_tipo_atencion, CASE WHEN h.id_emergencia IS NOT NULL THEN 2 END)
LEFT JOIN citas c             ON c.id = p.id_cita
LEFT JOIN sub_consultorios sc ON sc.id = COALESCE(p.id_sub_consultorio, c.id_sub_consultorio)
LEFT JOIN consultorios co     ON co.id = sc.id_consultorio
LEFT JOIN medicos m           ON m.id = p.id_medico
ORDER BY h.severidad, h.regla, e.codigo, h.id_atencion, h.id_pp;
