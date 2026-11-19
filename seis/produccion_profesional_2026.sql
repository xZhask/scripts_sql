-- =============================================================================
-- SEIS · PRODUCCIÓN DE UN PROFESIONAL (atenciones y procedimientos)
-- Base: bdseis_agosto26 (Laragon MySQL, puerto 3306)
--
-- Caso: médico general (DNI del profesional en @dni; no se versiona, repo público)
--       POLICLINICO POLICIAL "LA CRUZ" TUMBES (00012088)
--       Registró en SEIS de enero a mayo 2026; de junio a octubre en SIGESAPOL
--       (ver sigesapol/produccion_profesional_2026.sql).
--
-- Para otro profesional o periodo, cambiar solo las variables de abajo.
--
-- Criterios:
--   - Atenciones activas (ESTADO = 'A'), por fecha de atención.
--   - El profesional se busca en atencion_responsable.ID_EMPLEADO
--     (= personamast.PERSONA), en cualquier rol:
--       RESP = responsable (AM, RF). En PR el aplicativo lo muestra como
--              "Responsable Solicita el Procedimiento".
--       INGR / ALTA = médico de ingreso / alta en emergencia
--       PROC = "Responsable de Procedimiento / Responsable de la Atención":
--              quien REALIZA el procedimiento (PR). Verificado en el
--              aplicativo con las atenciones 24560684 y 21203334.
--   - Se excluye el HOSPITAL NACIONAL PNP LUIS N. SAENZ (00013591, nivel III).
--   - Se descartan las referencias (RF).
--   - Procedimientos: solo los que REALIZÓ (PROC). Los que solo solicitó
--     (RESP en PR) no cuentan.
--
-- Salidas:
--   1. ATENCIONES: 1 fila por atención (AM, EM, HO) con sus
--      diagnósticos concatenados. No incluye las PR.
--   2. PROCEDIMIENTOS: 1 fila por procedimiento de las atenciones PR donde el
--      profesional es quien lo realizó (PROC), con el solicitante al lado.
--   3. RESUMEN mensual.
--
-- Nota: en ene-may 2026 esta médica no figura como PROC en ninguna PR (todas
--   las PR donde aparece las solicitó y las realizó enfermería/laboratorio),
--   así que la salida 2 sale vacía.
-- =============================================================================

SET @dni    = '00000000';   -- <-- DNI del profesional
SET @desde  = '2026-01-01';
SET @hasta  = '2026-06-01';   -- exclusivo (hasta el 31/05/2026)
SET @per_desde = DATE_FORMAT(@desde, '%Y%m');
SET @per_hasta = DATE_FORMAT(@hasta - INTERVAL 1 DAY, '%Y%m');
SET @emp = (SELECT PERSONA FROM personamast WHERE DOCUMENTO = @dni LIMIT 1);

SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- Atenciones del periodo donde figura el profesional (y en qué rol)
DROP TEMPORARY TABLE IF EXISTS tmp_prof_aten;
CREATE TEMPORARY TABLE tmp_prof_aten AS
SELECT
    a.id_atencion,
    a.ID_TIPO_ATENCION,
    GROUP_CONCAT(DISTINCT r.ID_TIPO_RESPONSABLE ORDER BY r.ID_TIPO_RESPONSABLE) AS roles
FROM atencion_responsable r
INNER JOIN atencion a
    ON a.id_atencion = r.ID_ATENCION
WHERE r.ID_EMPLEADO = @emp
  AND a.ID_PERIODO BETWEEN @per_desde AND @per_hasta
  AND a.FECHA_ATENCION >= @desde
  AND a.FECHA_ATENCION <  @hasta
  AND a.ESTADO = 'A'
  AND a.ID_TIPO_ATENCION <> 'RF'  -- referencias descartadas a pedido del usuario
  -- En PR solo cuenta si ella REALIZÓ el procedimiento (PROC), no si lo solicitó (RESP)
  AND (a.ID_TIPO_ATENCION <> 'PR' OR r.ID_TIPO_RESPONSABLE = 'PROC')
  AND a.ID_IPRESS <> '00013591'  -- EXCLUIR HOSPITAL NACIONAL PNP LUIS N. SAENZ (nivel III)
GROUP BY a.id_atencion, a.ID_TIPO_ATENCION;
ALTER TABLE tmp_prof_aten ADD PRIMARY KEY (id_atencion);

-- Copia: MySQL no permite abrir una tabla temporal dos veces en la misma consulta
DROP TEMPORARY TABLE IF EXISTS tmp_prof_aten2;
CREATE TEMPORARY TABLE tmp_prof_aten2 LIKE tmp_prof_aten;
INSERT INTO tmp_prof_aten2 SELECT * FROM tmp_prof_aten;

-- -----------------------------------------------------------------------------
-- 1. ATENCIONES (no PR)
-- -----------------------------------------------------------------------------
SELECT
    'SEIS'                                          AS SISTEMA,
    a.id_atencion                                   AS ID_ATENCION,
    a.ID_PERIODO                                    AS PERIODO,
    DATE(a.FECHA_ATENCION)                          AS FECHA_ATENCION,
    a.ID_TIPO_ATENCION                              AS ID_TIPO_ATENCION,
    CASE a.ID_TIPO_ATENCION
        WHEN 'AM' THEN 'AMBULATORIA'
        WHEN 'EM' THEN 'EMERGENCIA'
        WHEN 'HO' THEN 'HOSPITALIZACIÓN'
        WHEN 'RF' THEN 'REFERENCIA'
        ELSE a.ID_TIPO_ATENCION
    END                                             AS TIPO_ATENCION,
    t.roles                                         AS ROL_PROFESIONAL,
    a.ID_IPRESS                                     AS CODIGO_IPRESS,
    TRIM(s.DESCRIPCIONLOCAL)                        AS IPRESS,
    a.ID_UPS                                        AS CODIGO_UPS,
    u.NOMBRE                                        AS UPS,
    p.documento                                     AS DNI_PACIENTE,
    p.NOMBRECOMPLETO                                AS PACIENTE,
    p.SEXO                                          AS SEXO,
    a.PACIENTE_EDAD                                 AS EDAD,
    d.DIAGNOSTICOS                                  AS DIAGNOSTICOS
FROM tmp_prof_aten t
INNER JOIN atencion a      ON a.id_atencion = t.id_atencion
INNER JOIN personamast p   ON p.PERSONA = a.PACIENTE_ID
LEFT JOIN ac_sucursal s    ON s.SUCURSAL = a.ID_IPRESS
LEFT JOIN ups u            ON u.CODIGOUPS = a.ID_UPS
LEFT JOIN (
    SELECT ad.ID_ATENCION,
           GROUP_CONCAT(DISTINCT CONCAT(dx.CodigoDiagnostico, ' - ', dx.Nombre,
                        ' (', CASE ad.ID_TIPO_DIAGNOSTICO WHEN '01' THEN 'P'
                                   WHEN '02' THEN 'D' WHEN '03' THEN 'R' ELSE '?' END, ')')
                        ORDER BY ad.ID_SECUENCIA SEPARATOR ' | ') AS DIAGNOSTICOS
    FROM tmp_prof_aten2 t2
    INNER JOIN atencion_diagnostico ad
        ON  ad.ID_ATENCION = t2.id_atencion
        AND ad.ID_TIPO_DETALLE = 'DIA'
    INNER JOIN ss_ge_diagnostico dx
        ON dx.IdDiagnostico = ad.ID_DIAGNOSTICO   -- descarta filas DIA vacías
    WHERE t2.ID_TIPO_ATENCION <> 'PR'
    GROUP BY ad.ID_ATENCION
) d ON d.ID_ATENCION = a.id_atencion
WHERE t.ID_TIPO_ATENCION <> 'PR'
ORDER BY a.FECHA_ATENCION, a.id_atencion;

-- -----------------------------------------------------------------------------
-- 2. PROCEDIMIENTOS (atenciones PR)
-- -----------------------------------------------------------------------------
SELECT
    'SEIS'                                          AS SISTEMA,
    a.id_atencion                                   AS ID_ATENCION,
    a.ID_PERIODO                                    AS PERIODO,
    DATE(a.FECHA_ATENCION)                          AS FECHA_ATENCION,
    CASE WHEN FIND_IN_SET('PROC', t.roles) THEN 'EJECUTOR'
         ELSE 'SOLICITANTE' END                     AS ROL_PROFESIONAL,
    a.ID_IPRESS                                     AS CODIGO_IPRESS,
    TRIM(s.DESCRIPCIONLOCAL)                        AS IPRESS,
    a.ID_UPS                                        AS CODIGO_UPS,
    u.NOMBRE                                        AS UPS,
    p.documento                                     AS DNI_PACIENTE,
    p.NOMBRECOMPLETO                                AS PACIENTE,
    ad.ID_TIPO_DETALLE                              AS TIPO_DETALLE,
    ad.ID_CPT                                       AS CODIGO_PROCEDIMIENTO,
    pm.NOMBRE                                       AS PROCEDIMIENTO,
    sol.NOMBRECOMPLETO                              AS SOLICITANTE,
    eje.NOMBRECOMPLETO                              AS EJECUTOR
FROM tmp_prof_aten t
INNER JOIN atencion a      ON a.id_atencion = t.id_atencion
INNER JOIN atencion_diagnostico ad
    ON  ad.ID_ATENCION = a.id_atencion
    AND ad.ID_TIPO_DETALLE IN ('PRO', 'QUI')
    AND ad.ID_CPT IS NOT NULL
INNER JOIN personamast p   ON p.PERSONA = a.PACIENTE_ID
LEFT JOIN ss_ge_procedimientomedico pm ON pm.CODIGOPROCEDIMIENTO = ad.ID_CPT
LEFT JOIN ac_sucursal s    ON s.SUCURSAL = a.ID_IPRESS
LEFT JOIN ups u            ON u.CODIGOUPS = a.ID_UPS
LEFT JOIN atencion_responsable rs
    ON rs.ID_ATENCION = a.id_atencion AND rs.ID_TIPO_RESPONSABLE = 'RESP'
LEFT JOIN personamast sol  ON sol.PERSONA = rs.ID_EMPLEADO
LEFT JOIN atencion_responsable rp
    ON rp.ID_ATENCION = a.id_atencion AND rp.ID_TIPO_RESPONSABLE = 'PROC'
LEFT JOIN personamast eje  ON eje.PERSONA = rp.ID_EMPLEADO
WHERE t.ID_TIPO_ATENCION = 'PR'
ORDER BY a.FECHA_ATENCION, a.id_atencion, ad.ID_SECUENCIA;

-- -----------------------------------------------------------------------------
-- 3. RESUMEN MENSUAL
-- -----------------------------------------------------------------------------
SELECT
    a.ID_PERIODO                                    AS PERIODO,
    t.ID_TIPO_ATENCION                              AS ID_TIPO_ATENCION,
    COUNT(DISTINCT t.id_atencion)                   AS ATENCIONES,
    COUNT(DISTINCT a.PACIENTE_ID)                   AS ATENDIDOS,
    SUM(pr.n_proc)                                  AS PROCEDIMIENTOS
FROM tmp_prof_aten t
INNER JOIN atencion a ON a.id_atencion = t.id_atencion
LEFT JOIN (
    SELECT ad.ID_ATENCION, COUNT(*) AS n_proc
    FROM atencion_diagnostico ad
    WHERE ad.ID_TIPO_DETALLE IN ('PRO', 'QUI') AND ad.ID_CPT IS NOT NULL
      AND ad.ID_ATENCION IN (SELECT id_atencion FROM tmp_prof_aten2 WHERE ID_TIPO_ATENCION = 'PR')
    GROUP BY ad.ID_ATENCION
) pr ON pr.ID_ATENCION = t.id_atencion
GROUP BY a.ID_PERIODO, t.ID_TIPO_ATENCION
ORDER BY a.ID_PERIODO, t.ID_TIPO_ATENCION;
